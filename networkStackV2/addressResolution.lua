local bitArray = require("BitIO")

local AddressResoulution = {}
local cache = {}

local broadcastAddr = "ffffffff-ffff-ffff-ffff-ffffffffffff"
local header = {
    hardeware = {16,"number"},
    protocol = {16,"number"},
    hardlen = {8,"number"},
    protolen = {8,"number"},
    operation = {16,"number"},
    sourceMac = {128,"string"},
    sourceIp = {32,"number"},
    targetMac = {128,"string"},
    targetIp = {32,"number"}
}

local function serializeMac(address)
    return string.gsub(address,"%w%w",function (n)
        return string.char(tonumber(n,16))
    end)
end

local function deserializeMac(address)
    local separatedBytes = string.gsub(address,"(....)(..)(..)(..)","%1-%2-%3-%4-")
    return string.gsub(separatedBytes,"%w",function (n)
        return string.format("%02x",n)
    end)
end

function AddressResoulution.getCache(ip)
    if cache[ip] then
        return true, cache[ip]
    end
    return false, nil
end

function AddressResoulution.resolveAddress(ip,packet,interface,doRequest)
    local doReq = doRequest or true
    local cached, targetAddr = AddressResoulution.getCache(ip)
    if not cached then
        if doReq then
            local requestFrame = bitArray.create("",header)
            local frameData = {operation = 1,sourceMac = serializeMac(interface.mac), sourceIp = interface.ip,targetIp = ip}
            requestFrame:SerializeTemplate(frameData)

            return false,table.pack(broadcastAddr,0x0806,requestFrame:byteString())
        else
            return false, nil
        end
    else
        return true, table.pack(targetAddr,0x0800,packet)
    end
end

function AddressResoulution.receive(packet,interface)
    local packetArray = bitArray.create(packet,header)
    local inPacket = packetArray:DeSerializeTemplate()
    local merge = false
    if cache[inPacket.sourceIp] then
        merge = true
        cache[inPacket.sourceIp] = deserializeMac(inPacket.sourceMac)
    end
    if interface.ip == inPacket.targetIp then
        if not merge then
            cache[inPacket.sourceIp] = deserializeMac(inPacket.sourceMac)
        end
        if  inPacket.operation == 1 then
            inPacket.targetIp = inPacket.sourceIp
            inPacket.targetMac = inPacket.sourceMac
            inPacket.sourceIp = interface.ip
            inPacket.sourceMac = serializeMac(interface.mac)
            inPacket.operation = 2
            packetArray:SerializeTemplate(inPacket)
            interface:RawSend(table.pack(deserializeMac(inPacket.targetMac),0x0806,packetArray:byteString()))
        end
    end
end

return AddressResoulution