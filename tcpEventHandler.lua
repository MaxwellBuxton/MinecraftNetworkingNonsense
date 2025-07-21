local TcpLib = require("TcpLib")
local s = require("serialization")

local tcpEventHandler = {}

function tcpEventHandler.tcp_open(localPort,remoteSocket,active)
    local connection = TcpLib.getConnectionId(localPort,remoteSocket)
    TCBList[connection].LOCALSOCKET = TcpLib.getLocalSocket(localPort)
    TCBList[connection].REMOTESOCKET = remoteSocket
    TCBList[connection].RETRANSMISSION = Queue.new()
    if active == false then
        TCBList[connection].STATE ="LISTEN"
        return
    else
        TCBList[connection].ISS = math.random(300)
        local synSegment = TcpLib.createSegment(connection,false,false,true,false,{})
        TcpLib.send(connection,synSegment)
        TCBList[connection].SND.UNA = TCBList[connection].ISS
        TCBList[connection].SND.NXT = TCBList[connection].ISS + 1
        TCBList[connection].STATE ="SYN-SENT"
    end
end

function tcpEventHandler.net_recieve(segmentString)
    local segment = s.unserialize(segmentString)
    local connection = TcpLib.getSegmentConnection(segment)
    if TcpLib[connection] == nil then
        connection = TCBList.getDefaultConnection(segment.targetPort)
    end
    TCBList[connection].SEG.SEQ = segment.SEQ
    TCBList[connection].SEG.ACK = segment.ACK
    local segmentLength = 0
    if segment.data ~= nil then
        segmentLength = segmentLength + s.serialize(segment.data).length()
    end
    if segment.flags.SYN == true then
        segmentLength = segmentLength + 1
    end
    if segment.flags.FIN == true then
        segmentLength = segmentLength + 1
    end
    TCBList[connection].Segment = segment
    TCBList[connection].SEG.LEN = s.serialize(segment.data).length() + segment.flags.SYN + segment.flags.FIN
    local state = TCBList[connection].STATE
    if state == "LISTEN" then
        if TCBList[connection].Segment.flags.SYN == true then
            TCBList[connection].RCV.NXT = TCBList[connection].SEG.SEQ + 1
            TCBList[connection].IRS = TCBList[connection].SEG.SEQ

            TCBList[connection].ISS = math.random(300)
            local synSegment = TcpLib.createSegment(connection,true,false,true,false,{})
            TcpLib.send(connection,synSegment)
            TCBList[connection].SND.UNA = TCBList[connection].ISS
            TCBList[connection].SND.NXT = TCBList[connection].ISS + 1
            TCBList[connection].STATE = "SYN-RECIEVED"

            if TCBList[connection].REMOTESOCKET == {IP = "0.0.0.0",PORT = 0} then
                TCBList[connection].REMOTESOCKET.IP = TCBList[connection].Segment.SourceIp
                TCBList[connection].REMOTESOCKET.PORT = TCBList[connection].Segment.sourcePort
                local newConnection = TcpLib.getConnectionId(TCBList[connection].LOCALSOCKET.PORT,TCBList[connection].REMOTESOCKET)
                TCBList[newConnection] = TCBList[connection]
                TCBList[connection] = nil
            end
        end
    elseif state == "SYN-SENT" then
        if TCBList[connection].SND.UNA < TCBList[connection].SEG.NXT and TCBList[connection].SEG.NXT == TCBList[connection].SND.ACK then
            if TCBList[connection].Segment.flags.SYN == true then
                TCBList[connection].RCV.NXT = TCBList[connection].SEG.SEQ + 1
                TCBList[connection].SND.UNA = TCBList[connection].SEG.ACK
                TcpLib.updateUna(connection)
                if TCBList[connection].SND.UNA > TCBList[connection].ISS then
                    TCBList[connection].STATE = "ESTABLISHED"
                    local ackSegment = TcpLib.createSegment(connection,true,false,false,false,{})
                    TcpLib.sendAck(connection,ackSegment)
                end
            end
        end
    elseif state == "SYN-RECEIVED" then
        if TcpLib.checkSeq(connection) then
            if TCBList[connection].Segment.flags.ACK == false then
                return
            end
            if TCBList[connection].SND.UNA < TCBList[connection].SEG.ACK and TCBList[connection].SEG.ACK <= TCBList[connection].SND.NXT then
                TCBList[connection].STATE = "ESTABLISHED"
            end
        end
    end
end

function tcpEventHandler.tcp_status(connectionId)
    event.push("tcp_status_return",TCBList[connectionId].STATE,TCBList[connectionId])
end

function tcpEventHandler.tcp_retransmission(connectionId)
    if TCBList[connectionId].RETRANSMISSION ~= nil then
        if TCBList[connectionId].RETRANSMISSION:isEmpty() == false then
            local targetIp = TCBList[connectionId].REMOTESOCKET.IP
            local segment = TCBList.RETRANSMISSION:check()
            event.push("net_send",targetIp,s.serialize(segment))
            TCBList[connectionId].RETRANSMISSION.timeOutId = event.timer(10,function() event.push("tcp_retransmit",connectionId) end)
        end
    end
end

return tcpEventHandler