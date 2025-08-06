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
    TCBList[connection].SENDBUFFER = {FIN = false}
    if active == false then
        TCBList[connection].STATE ="LISTEN"
        event.push("tcp_log_return",connection,"opened listen connection on: "..connection)
        return
    else
        TCBList[connection].ISS = math.random(300)
        local synSegment = TcpLib.createSegment(connection,false,false,true,false,{})
        TcpLib.send(connection,synSegment)
        TCBList[connection].SND.UNA = TCBList[connection].ISS
        TCBList[connection].SND.NXT = TCBList[connection].ISS + 1
        TCBList[connection].STATE ="SYNSENT"
        event.push("tcp_log_return",connection,"sent SYN segment on: "..connection)
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

function tcpEventHandler.tcp_send(connectionId,...)
    local sendData = table.pack(...)
    for  i = 1, sendData.n do
        table.insert(TCBList[connectionId].SENDBUFFER,sendData[i])
    end
    TcpLib.sendData(connectionId)
end

function tcpEventHandler.tcp_recieve(connectionId)
    if TCBList[connectionId] == nil then
        event.push("tcp_recieve_return",connectionId,nil,nil,"CLOSED")
        return
    end
    TCBList[connectionId].RECIEVE.REQUEST = true
    TcpLib.proccessIncoming(connectionId)
end

function tcpEventHandler.tcp_close(connectionId)
    if TCBList[connectionId] == nil then
        event.push("tcp_close_return",connectionId,"CLOSED")
        return
    end
    TCBList[connectionId].SENDBUFFER.FIN = true
    TcpLib.sendData(connectionId)
    if TCBList[connectionId].STATE ~= "CLOSEWAIT" and TCBList[connectionId].STATE ~= "LASTACK" then
        TCBList[connectionId].STATE = "FINWAIT1"
    end
end

function tcpEventHandler.tcp_abort(connectionId)
    TcpLib.resetConnection(connectionId)
end

function tcpEventHandler.tcp_timewait_timeout(connection)
    TCBList[connection] = nil
    event.push("tcp_close_return",connection,"CLOSED")
end

return tcpEventHandler