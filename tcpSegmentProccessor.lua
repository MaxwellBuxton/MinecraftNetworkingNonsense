local TcpLib = require("TcpLib")
local s = require("serialization")
local event = require("event")

local tcpSegmentProccessor = {}

function tcpSegmentProccessor.LISTEN(connection)
    if TCBList[connection].Segment.flags.SYN == true then
        TCBList[connection].RCV.NXT = TCBList[connection].SEG.SEQ + 1
        TCBList[connection].IRS = TCBList[connection].SEG.SEQ

        TCBList[connection].ISS = math.random(300)
        TCBList[connection].SND.UNA = TCBList[connection].ISS
        TCBList[connection].SND.NXT = TCBList[connection].ISS + 1
        TCBList[connection].STATE = "SYNRECEIVED"

        if TCBList[connection].REMOTESOCKET.IP == "0.0.0.0" and TCBList[connection].REMOTESOCKET.PORT == "0" then
            TCBList[connection].REMOTESOCKET.IP = TCBList[connection].Segment.sourceIP
            TCBList[connection].REMOTESOCKET.PORT = TCBList[connection].Segment.sourcePort
            local newConnection = TcpLib.getConnectionId(TCBList[connection].LOCALSOCKET.PORT,TCBList[connection].REMOTESOCKET)
            TCBList[newConnection] = TCBList[connection]
            TCBList[connection] = nil
            event.push("tcp_listen_return",connection,newConnection)
            connection = newConnection
        end
        local synSegment = TcpLib.createSegment(connection,true,false,true,false,{})
        TcpLib.send(connection,synSegment)
        event.push("tcp_log_return",connection,"Recieved SYN request, sending SYN/ACK on"..connection)
    end
end

function tcpSegmentProccessor.SYNSENT(connection)
    if TCBList[connection].SND.UNA < TCBList[connection].SEG.ACK and TCBList[connection].SEG.ACK == TCBList[connection].SND.NXT then
        if TCBList[connection].Segment.flags.SYN == true then
            TCBList[connection].RCV.NXT = TCBList[connection].SEG.SEQ + 1
            TcpLib.updateUna(connection)
            if TCBList[connection].SND.UNA > TCBList[connection].ISS then
                TCBList[connection].STATE = "ESTABLISHED"
                local ackSegment = TcpLib.createSegment(connection,true,false,false,false,{})
                TcpLib.sendAck(connection,ackSegment)
                event.push("tcp_open_return",connection,"OK")
                event.push("tcp_log_return",connection,"SYN Acknowladged entering ESTABLISHED on"..connection)
            end
        end
    end
end

function tcpSegmentProccessor.SYNRECEIVED(connection)
    if TcpLib.checkSeq(connection) then
        if TCBList[connection].Segment.flags.ACK == false then
            return
        end
        if TCBList[connection].SND.UNA < TCBList[connection].SEG.ACK and TCBList[connection].SEG.ACK <= TCBList[connection].SND.NXT then
            TcpLib.updateUna(connection)
            TCBList[connection].STATE = "ESTABLISHED"
            event.push("tcp_open_return",connection,"OK")
            event.push("tcp_log_return",connection,"SYN Acknowladged entering ESTABLISHED on"..connection)
        else
            TcpLib.resetConnection(connection)
            return
        end

        TcpLib.proccessSegmentText(connection)

        if TCBList[connection].Segment.flags.FIN then
            event.push("tcp_close_return",connection,"CLOSING")
            TCBList[connection].RCV.NXT = TCBList[connection].RCV.NXT + 1
            local finAck = TcpLib.createSegment(connection,true,false,false,false,{})
            TcpLib.sendAck(connection,finAck)
            TCBList[connection].STATE = "CLOSEWAIT"
        end
    end
end

function tcpSegmentProccessor.ESTABLISHED(connection)
    if TcpLib.checkSeq(connection) then
        if TcpLib.checkRst(connection) then
            return
        end

        if TCBList[connection].Segment.flags.SYN then
            TcpLib.resetConnection(connection)
            return
        end

        if TcpLib.checkAck(connection) then
            return
        end

        TcpLib.proccessSegmentText(connection)

        if TCBList[connection].Segment.flags.FIN then
            --event.push("tcp_close_return",connection,"connection closing")
            TCBList[connection].RCV.NXT = TCBList[connection].RCV.NXT + 1
            local finAck = TcpLib.createSegment(connection,true,false,false,false,{})
            TcpLib.sendAck(connection,finAck)
            TCBList[connection].STATE = "CLOSEWAIT"
            if TCBList[connection].RECIEVE.REQUEST == true and #TCBList[connection].RECIEVE.INCOMING == 0 then
                TCBList[connection].RECIEVE.REQUEST = false
                event.push("tcp_recieve_return",connection,nil,nil,"CLOSING")
            end
        end
    end
end

function tcpSegmentProccessor.FINWAIT1(connection)
    if TcpLib.checkSeq(connection) then
        if TcpLib.checkRst(connection) then
            return
        end

        if TCBList[connection].Segment.flags.SYN then
            TcpLib.resetConnection(connection)
            return
        end

        if TcpLib.checkAck(connection) then
            return
        end
        if TCBList[connection].SENDBUFFER.FIN == false and TCBList[connection].SND.UNA == TCBList[connection].SND.NXT then
            TCBList[connection].STATE = "FINWAIT2"
        end

        TcpLib.proccessSegmentText(connection)

        if TCBList[connection].SENDBUFFER.FIN == false and TCBList[connection].SND.UNA == TCBList[connection].SND.NXT then
            if TCBList[connection].Segment.flags.FIN then
                TCBList[connection].RCV.NXT = TCBList[connection].RCV.NXT + 1
                local finAck = TcpLib.createSegment(connection,true,false,false,false,{})
                TcpLib.sendAck(connection,finAck)
                TCBList[connection].STATE = "TIMEWAIT"
                event.timer(5,function() event.push("tcp_timewait_timeout",connection) end)
            end
        elseif TCBList[connection].Segment.flags.FIN then
            TCBList[connection].RCV.NXT = TCBList[connection].RCV.NXT + 1
            local finAck = TcpLib.createSegment(connection,true,false,false,false,{})
            TcpLib.sendAck(connection,finAck)
            TCBList[connection].STATE = "CLOSING"
        end
    end
end

function tcpSegmentProccessor.FINWAIT2(connection)
    if TcpLib.checkSeq(connection) then
        if TcpLib.checkRst(connection) then
            return
        end

        if TCBList[connection].Segment.flags.SYN then
            TcpLib.resetConnection(connection)
            return
        end

        if TcpLib.checkAck(connection) then
            return
        end

        TcpLib.proccessSegmentText(connection)

        if TCBList[connection].Segment.flags.FIN then
            TCBList[connection].RCV.NXT = TCBList[connection].RCV.NXT + 1
            local finAck = TcpLib.createSegment(connection,true,false,false,false,{})
            TcpLib.sendAck(connection,finAck)
            TCBList[connection].STATE = "TIMEWAIT"
            event.timer(5,function() event.push("tcp_timewait_timeout",connection) end)
        end
    end
end

function tcpSegmentProccessor.CLOSEWAIT(connection)
    if TcpLib.checkSeq(connection) then
        if TcpLib.checkRst(connection) then
            return
        end

        if TCBList[connection].Segment.flags.SYN then
            TcpLib.resetConnection(connection)
            return
        end

        if TcpLib.checkAck(connection) then
            return
        end

        if TCBList[connection].Segment.flags.FIN then
            TCBList[connection].RCV.NXT = TCBList[connection].RCV.NXT + 1
            local finAck = TcpLib.createSegment(connection,true,false,false,false,{})
            TcpLib.sendAck(connection,finAck)
        end
    end
end

function tcpSegmentProccessor.CLOSING(connection)
    if TcpLib.checkSeq(connection) then
        if TCBList[connection].Segment.flags.RST then
            TCBList[connection] = nil
            event.push("tcp_close_return",connection,"CLOSED")
            return
        end

        if TCBList[connection].Segment.flags.SYN then
            TcpLib.resetConnection(connection)
            return
        end

        if TcpLib.checkAck(connection) then
            return
        end
        if TCBList[connection].SND.UNA == TCBList[connection].SND.NXT then
            TCBList[connection].STATE = "TIMEWAIT"
            event.timer(5,function() event.push("tcp_timewait_timeout",connection) end)
        end

        if TCBList[connection].Segment.flags.FIN then
            TCBList[connection].RCV.NXT = TCBList[connection].RCV.NXT + 1
            local finAck = TcpLib.createSegment(connection,true,false,false,false,{})
            TcpLib.sendAck(connection,finAck)
        end
    end
end

function tcpSegmentProccessor.LASTACK(connection)
    if TcpLib.checkSeq(connection) then
        if TCBList[connection].Segment.flags.RST then
            TCBList[connection] = nil
            event.push("tcp_close_return",connection,"CLOSED")
            return
        end

        if TCBList[connection].Segment.flags.SYN then
            TcpLib.resetConnection(connection)
            return
        end

        TcpLib.updateUna(connection)
        if TCBList[connection].SND.UNA == TCBList[connection].SND.NXT then
            TCBList[connection] = nil
            event.push("tcp_close_return",connection,"CLOSED")
            return
        end

        if TCBList[connection].Segment.flags.FIN then
            TCBList[connection].RCV.NXT = TCBList[connection].RCV.NXT + 1
            local finAck = TcpLib.createSegment(connection,true,false,false,false,{})
            TcpLib.sendAck(connection,finAck)
        end
    end
end

function tcpSegmentProccessor.TIMEWAIT(connection)
    if TcpLib.checkSeq(component) then
        if TCBList[connection].Segment.flags.RST then
            TCBList[connection] = nil
            event.push("tcp_close_return",connection,"CLOSED")
            return
        end

        if TCBList[connection].Segment.flags.SYN then
            TcpLib.resetConnection(connection)
            return
        end

        if TCBList[connection].Segment.flags.FIN then
            TCBList[connection].RCV.NXT = TCBList[connection].RCV.NXT + 1
            local finAck = TcpLib.createSegment(connection,true,false,false,false,{})
            TcpLib.sendAck(connection,finAck)
        end
    end
end

return tcpSegmentProccessor