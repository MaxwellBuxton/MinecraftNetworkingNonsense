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

function TcpLib.returnOpen(connectionId,message)
    event.push("tcp_open_return",TCBList[connectionId].LOCALSOCKET.PORT,connectionId,TCBList[connectionId].STATE,message)
end

function TcpLib.updateUna(connectionId)
    TCBList[connectionId].SND.UNA = TCBList[connectionId].SEG.ACK
    if TCBList[connectionId].RETRANSMISSION:isEmpty() == true then
        return
    end
    local retransmitSegment = TCBList[connectionId].RETRANSMISSION:check()
    local reSeq = retransmitSegment.SEQ
    while reSeq < TCBList[connectionId].SND.UNA do
        retransmitSegment = TCBList[connectionId].RETRANSMISSION:pull()
        local timeOut = TCBList[connectionId].RETRANSMISSION.timeOutId
        TCBList[connectionId].RETRANSMISSION.timeOutId = nil
        TCBList[connectionId].RETRANSMISSION.count = 0
        event.cancel(timeOut)
        if TCBList[connectionId].RETRANSMISSION:isEmpty() == false then
            retransmitSegment = TCBList[connectionId].RETRANSMISSION:check()
            reSeq = retransmitSegment.SEQ
        else
            reSeq = TCBList[connectionId].SND.UNA
        end
    end
    if TCBList[connectionId].RETRANSMISSION.timeOutId == nil and TCBList[connectionId].RETRANSMISSION:isEmpty() == false then
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
        },
        data = data
    }
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

function TcpLib.sendAck(connectionId,segment)
    local targetIp = TCBList[connectionId].REMOTESOCKET.IP
    event.push("net_send",targetIp,s.serialize(segment))
end

function TcpLib.checkSeq(connectionId)
    if TCBList[connectionId].SEG.SEQ == TCBList[connectionId].RCV.NXT then
        return true
    else
        local ackSegment TcpLib.createSegment(connectionId,true,false,false,false,{})
        TcpLib.sendAck(connectionId,ackSegment)
        return false
    end
end

return TcpLib