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
            TcpLib.returnOpen(newConnection,"swapping connection: "..connection.."to :"..newConnection)
            connection = newConnection
        end
        local synSegment = TcpLib.createSegment(connection,true,false,true,false,{})
        TcpLib.send(connection,synSegment)
        TcpLib.returnOpen(connection,"Recieved SYN request, sending SYN/ACK on"..connection)
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
                TcpLib.returnOpen(connection,"SYN Acknowladged entering ESTABLISHED on"..connection)
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
            TcpLib.returnOpen(connection,"SYN Acknowladged entering ESTABLISHED on"..connection)
        end
    end
end

function tcpSegmentProccessor.ESTABLISHED(connection)
    if TcpLib.checkSeq(connection) then
        if TcpLib.checkRst then
            return
        end
        if TCBList[connection].Segment.flags.SYN then
            TcpLib.resetConnection(connection)
            return
        end
        if TCBList[connection].Segment.flags.ACK == false then
            return
        end
        if TCBList[connection].SND.UNA < TCBList[connection].SEG.ACK and TCBList[connection].SEG.ACK <= TCBList[connection].SND.NXT then
            TcpLib.updateUna(connection)
        elseif TCBList[connection].SEG.ACK > TCBList[connection].SND.NXT then
            local ackSegment = TcpLib.createSegment(connection,true,false,false,false,{})
            TcpLib.sendAck(connection,ackSegment)
            return
        end
        local proccessText = s.serialize(TCBList[connection].Segment.data)
        if proccessText ~= "{}" or proccessText ~= "" or proccessText ~= nil then
            table.insert(TCBList[connection].RECIEVE.INCOMING, proccessText)
            if TCBList[connection].Segment.flags.PSH == true then
                TCBList[connection].RECIEVE.PUSH = true
            end
            TcpLib.proccessIncoming(connection)
            TCBList[connection].RCV.NXT = TCBList[connection].RCV.NXT + TCBList[connection].SEG.LEN
            if TcpLib.sendData(connection) == false then
                local ackSegment = TcpLib.createSegment(connection,true,false,false,false,{})
                TcpLib.sendAck(connection,ackSegment)
            end
        else
            TcpLib.sendData(connection)
        end
        if TCBList[connection].Segment.flags.FIN then
            TCBList[connection].STATE = "FINWAIT"
        end
    end
end

function tcpSegmentProccessor.FINWAIT1()
    
end

function tcpSegmentProccessor.FINWAIT2()
    
end

function tcpSegmentProccessor.CLOSEWAIT()
    
end

function tcpSegmentProccessor.CLOSING()
    
end

function tcpSegmentProccessor.LASTACK()
    
end

function tcpSegmentProccessor.TIMEWAIT()
    
end

return tcpSegmentProccessor