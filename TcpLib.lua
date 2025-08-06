local netCore = require("netCore")
local event = require("event")
local s = require("serialization")

local TcpLib = {}

--returns a connection id based on local port and remoteSocket
function TcpLib.getConnectionId(localPort,remoteSocket)
    local config = netCore.GetNetworkConfig()
    return config.IP.MAIN..localPort..remoteSocket.IP..remoteSocket.PORT
end

--gets the intended connection id of a segment
function TcpLib.getSegmentConnection(segment)
    return segment.targetIP..segment.targetPort..segment.sourceIP..segment.sourcePort
end

--gets local socket table
function TcpLib.getLocalSocket(port)
    local config = netCore.GetNetworkConfig()
    return {IP = config.IP.MAIN, PORT = port}
end

--creates unspecified connection id for local socket
function TcpLib.getDefaultConnection(port)
    local localSocket = TcpLib.getLocalSocket(port)
    return localSocket.IP..port.."0.0.0.0"..0
end

--updates SND.UNA to latest ACK and removes any queued transmissions that have been acknowledged
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

--creates a tcp segment
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
            FIN = fin,
            PSH = false
        },
        data = data
    }
    return segment
end

--queues a segment for retransmission and starts a timer is there is none
function TcpLib.queueRetransmission(connectionId,segment)
    if TCBList[connectionId].RETRANSMISSION:isEmpty() then
        TCBList[connectionId].RETRANSMISSION.timeOutId = event.timer(10,function() event.push("tcp_retransmit",connectionId) end)
    end
    TCBList[connectionId].RETRANSMISSION:insert(segment)
end

--sends a segment and queues for retransmission
function TcpLib.send(connectionId,segment)
    local targetIp = TCBList[connectionId].REMOTESOCKET.IP
    event.push("net_send",targetIp,s.serialize(segment))
    TcpLib.queueRetransmission(connectionId,segment)
end

--sends a segment without adding it to retransmission queue
function TcpLib.sendAck(connectionId,segment)
    local targetIp = TCBList[connectionId].REMOTESOCKET.IP
    event.push("net_send",targetIp,s.serialize(segment))
end

--tests validity of seq and sends ack if invalid
function TcpLib.checkSeq(connectionId)
    if TCBList[connectionId].SEG.SEQ == TCBList[connectionId].RCV.NXT then
        return true
    else
        local ackSegment TcpLib.createSegment(connectionId,true,false,false,false,{})
        TcpLib.sendAck(connectionId,ackSegment)
        return false
    end
end

--tests reset flag if true and valid deletes connection TCB and sends ConnectionReset event with the connectionId
function TcpLib.checkRst(connectionId)
    if TCBList[connectionId].Segment.flags.RST and TCBList[connectionId].SEG.SEQ == TCBList[connectionId].RCV.NXT then
        TCBList[connectionId] = nil
        event.push("ConnectionReset",connectionId)
        return true
    end
    return false
end

--sends a reset segment and ConnectionReset event then deletes connection TCB
function TcpLib.resetConnection(connectionId)
    local rstSegment = TcpLib.createSegment(connectionId,false,true,false,false,{})
    TcpLib.sendAck(connectionId,rstSegment)
    TCBList[connectionId] = nil
    event.push("ConnectionReset",connectionId)
end

--if there is an active recieve request and data in the buffer send an tcp_recieve_return event with connectionId, push true/false, and the filled buffer
function TcpLib.proccessIncoming(connectionId)
    if TCBList[connectionId].RECIEVE.REQUEST == true and #TCBList[connectionId].RECIEVE.INCOMING > 0 then
        local RecievedData = TCBList[connectionId].RECIEVE.INCOMING
        local push = TCBList[connectionId].RECIEVE.PUSH
        event.push("tcp_recieve_return",connectionId,RecievedData,push,"OK")
        TCBList[connectionId].RECIEVE.INCOMING = {}
        TCBList[connectionId].RECIEVE.PUSH = false
        TCBList[connectionId].RECIEVE.REQUEST = false
    else
        if TCBList[connectionId].RECIEVE.REQUEST == true and TCBList[connectionId].STATE == "CLOSEWAIT" and #TCBList[connectionId].RECIEVE.INCOMING == 0 then
            TCBList[connectionId].RECIEVE.REQUEST = false
            event.push("tcp_recieve_return",connectionId,nil,nil,"CLOSING")
        end
    end
end

--if all sent data has been acknowledged then sends first segment from queued send data and updates SND.NXT returns true if sent false if not
function TcpLib.sendData(connectionId)
    if TCBList[connectionId].SND.UNA == TCBList[connectionId].SND.NXT then
        if #TCBList[connectionId].SENDBUFFER > 0 then
            local sendData = table.remove(TCBList[connectionId].SENDBUFFER,1)
            local dataLength = #sendData
            sendData = s.unserialize(sendData)
            local sendSegment = TcpLib.createSegment(connectionId,true,false,false,false,sendData)
            TcpLib.send(connectionId,sendSegment)
            TCBList[connectionId].SND.NXT = TCBList[connectionId].SND.NXT + dataLength
            return true
        elseif TCBList[connectionId].SENDBUFFER.FIN == true then
            local finSegment = TcpLib.createSegment(connectionId,true,false,false,true,{})
            TCBList[connectionId].SND.NXT = TCBList[connectionId].SND.NXT + 1
            TcpLib.send(connectionId,finSegment)
            TCBList[connectionId].SENDBUFFER.FIN = false
            if TCBList[connectionId].STATE == "CLOSEWAIT" then
                TCBList[connectionId].STATE = "LASTACK"
            end
        end
    end
    return false
end

function TcpLib.proccessSegmentText(connectionId)
    local proccessText = s.serialize(TCBList[connectionId].Segment.data)
    if proccessText ~= "{}" or proccessText ~= "" or proccessText ~= nil then
        table.insert(TCBList[connectionId].RECIEVE.INCOMING, proccessText)
        if TCBList[connectionId].Segment.flags.PSH == true then
            TCBList[connectionId].RECIEVE.PUSH = true
        end
        TcpLib.proccessIncoming(connectionId)
        TCBList[connectionId].RCV.NXT = TCBList[connectionId].RCV.NXT + TCBList[connectionId].SEG.LEN
        if TcpLib.sendData(connectionId) == false then
            local ackSegment = TcpLib.createSegment(connectionId,true,false,false,false,{})
            TcpLib.sendAck(connectionId,ackSegment)
        end
    else
        TcpLib.sendData(connectionId)
    end
end

function TcpLib.checkAck(connectionId)
    if TCBList[connectionId].Segment.flags.ACK == false then
        return true
    end
    if TCBList[connectionId].SND.UNA < TCBList[connectionId].SEG.ACK and TCBList[connectionId].SEG.ACK <= TCBList[connectionId].SND.NXT then
        TcpLib.updateUna(connectionId)
    elseif TCBList[connectionId].SEG.ACK > TCBList[connectionId].SND.NXT then
        local ackSegment = TcpLib.createSegment(connectionId,true,false,false,false,{})
        TcpLib.sendAck(connectionId,ackSegment)
        return true
    end
    return false
end

return TcpLib