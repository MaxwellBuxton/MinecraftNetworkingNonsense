local TcpLib = require("TcpLib")
local s = require("serialization")
local event = require("event")
local segProcces = require("tcpSegmentProccessor")

local tcpEventHandler = {}

function tcpEventHandler.tcp_open(localPort,remoteSocketString,active)
    local remoteSocket = s.unserialize(remoteSocketString)
    local connection = TcpLib.getConnectionId(localPort,remoteSocket)
    TCBList[connection] = {}
    TCBList[connection].RCV = {}
    TCBList[connection].SND = {}
    TCBList[connection].SEG = {}
    TCBList[connection].LOCALSOCKET = TcpLib.getLocalSocket(localPort)
    TCBList[connection].REMOTESOCKET = remoteSocket
    TCBList[connection].RETRANSMISSION = Queue.new()
    TCBList[connection].RETRANSMISSION.count = 0
    TCBList[connection].RECIEVE = {INCOMING = {}, REQUEST = false, PUSH = false}
    TCBList[connection].SENDBUFFER = {}
    if active == false then
        TCBList[connection].STATE ="LISTEN"
        TcpLib.returnOpen(connection,"opened listen connection on: "..connection)
        return
    else
        TCBList[connection].ISS = math.random(300)
        local synSegment = TcpLib.createSegment(connection,false,false,true,false,{})
        TcpLib.send(connection,synSegment)
        TCBList[connection].SND.UNA = TCBList[connection].ISS
        TCBList[connection].SND.NXT = TCBList[connection].ISS + 1
        TCBList[connection].STATE ="SYNSENT"
        TcpLib.returnOpen(connection,"sent SYN segment on: "..connection)
    end
end

function tcpEventHandler.net_recieve(segmentString)
    local segment = s.unserialize(segmentString)
    local connection = TcpLib.getSegmentConnection(segment)
    if TCBList[connection] == nil then
        connection = TcpLib.getDefaultConnection(segment.targetPort)
    end
    TCBList[connection].SEG.SEQ = segment.SEQ
    TCBList[connection].SEG.ACK = segment.ACK
    local segmentLength = 0
    local dataString = s.serialize(segment.data)
    if dataString ~= "{}" or dataString ~= nil then
        segmentLength = segmentLength + #dataString
    end
    if segment.flags.SYN == true then
        segmentLength = segmentLength + 1
    end
    if segment.flags.FIN == true then
        segmentLength = segmentLength + 1
    end
    TCBList[connection].Segment = segment
    TCBList[connection].SEG.LEN = segmentLength
    local state = TCBList[connection].STATE
    
    segProcces[TCBList[connection].STATE](connection)
end

function tcpEventHandler.tcp_status(connectionId)
    event.push("tcp_status_return",TCBList[connectionId].STATE,TCBList[connectionId])
end

function tcpEventHandler.tcp_retransmit(connectionId)
    if TCBList[connectionId].RETRANSMISSION ~= nil then
        if TCBList[connectionId].RETRANSMISSION:isEmpty() == false then
            if TCBList[connectionId].RETRANSMISSION.count > 4 then
                return
            end
            local targetIp = TCBList[connectionId].REMOTESOCKET.IP
            local segment = TCBList[connectionId].RETRANSMISSION:check()
            event.push("net_send",targetIp,s.serialize(segment))
            TCBList[connectionId].RETRANSMISSION.timeOutId = event.timer(10,function() event.push("tcp_retransmit",connectionId) end)
            TCBList[connectionId].RETRANSMISSION.count = TCBList[connectionId].RETRANSMISSION.count + 1
        end
    end
end

return tcpEventHandler