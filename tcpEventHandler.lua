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
        TCBList[connection].SND.UNA = TCBList[connection]
        TCBList[connection].SND.NXT = TCBList[connection].ISS + 1
        TCBList[connection].STATE ="SYN-SENT"
    end
end

function tcpEventHandler.net_recieve(segmentString)
    local segment = s.unserialize(segmentString)
    
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