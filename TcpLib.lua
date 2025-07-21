local netCore = require("netCore")
local event = require("event")
local s = require("serialization")

local TcpLib = {}

function TcpLib.getConnectionId(localPort,remoteSocket)
    local config = netCore.GetNetworkConfig()
    return config.IP.MAIN..localPort..remoteSocket.IP..remoteSocket.PORT
end

function TcpLib.getSegmentConnection(segment)
    return segment.targetIP..segment.targetPort..segment.sourceIP..segment.sourcePort
end

function TcpLib.getLocalSocket(port)
    local config = netCore.GetNetworkConfig()
    return {IP = config.IP.MAIN, PORT = port}
end

function TcpLib.getDefaultConnection(port)
    local localSocket = TcpLib.getLocalSocket(port)
    return localSocket.IP..port.."0.0.0.0"..0
end

function TcpLib.updateUna(connectionId)
    TCBList[connectionId].SND.UNA = TCBList[connectionId].SEG.ACK
    local retransmitSegment = TCBList[connectionId].RETRANSMISSION:check()
    while retransmitSegment.SEQ < TCBList[connectionId].SND.UNA do
        retransmitSegment = TCBList[connectionId].RETRANSMISSION:pull()
        local timeOut = TCBList[connectionId].RETRANSMISSION.timeOutId
        TCBList[connectionId].RETRANSMISSION.timeOutId = nil
        event.cancel(timeOut)
        retransmitSegment = TCBList[connectionId].RETRANSMISSION:check()
    end
    if TCBList[connectionId].RETRANSMISSION.timeOutId == nil then
        TCBList[connectionId].RETRANSMISSION.timeOutId = event.timer(10,function() event.push("tcp_retransmit",connectionId) end)
    end
end

function TcpLib.createSegment(connectionId,ack,rst,syn,fin,data)
    local seqNum
    if syn == true then
        seqNum = TCBList[connectionId].ISS
    else
        seqNum = TCBList[connectionId].SND.NXT
    end
    local segment = {
        sourcePort = TCBList[connectionId].LOCALSOCKET.PORT,
        targetPort = TCBList[connectionId].REMOTESOCKET.PORT,
        SEQ = seqNum,
        ACK = TCBList[connectionId].RCV.NXT,
        flags = {
            ACK = ack,
            RST = rst,
            SYN = syn,
            FIN = fin
        }
    }
    for i,v in pairs(data) do
        segment[i] = v
    end
    return segment
end

function TcpLib.queueRetransmission(connectionId,segment)
    if TCBList[connectionId].RETRANSMISSION:isEmpty() then
        TCBList[connectionId].RETRANSMISSION.timeOutId = event.timer(10,function() event.push("tcp_retransmit",connectionId) end)
    end
    TCBList[connectionId].RETRANSMISSION:insert(segment)
end

function TcpLib.send(connectionId,segment)
    local targetIp = TCBList[connectionId].REMOTESOCKET.IP
    event.push("net_send",targetIp,s.serialize(segment))
    TcpLib.queueRetransmission(connectionId,segment)
end

return TcpLib