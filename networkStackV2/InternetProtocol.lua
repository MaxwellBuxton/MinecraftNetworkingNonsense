local bitArray = require("BitIO")

local InternetProtocol = {}
local interfaces = {}
local routes = {}

local header = {
    version = {4,"number"},
    ihl = {4,"number"},
    typeOfService = {8,"number"},
    totalLength = {16,"number"},
    identification = {16,"number"},
    reserved = {1,"number"},
    dontFragment = {1,"number"},
    moreFragment = {1,"number"},
    fragmentOffset = {13,"number"},
    timeToLive = {8,"number"},
    protocol = {8,"number"},
    headerChecksum = {16,"number"},
    sourceAddress = {32,"number"},
    destinationAddress = {32,"number"}
}

local function fragment(localHeader,data,maxLen,fragments)
    if localHeader.totalLength <= maxLen then
        local newFrame = bitArray.create("",header)
        newFrame:SerializeTemplate(localHeader)
        table.insert(fragments, newFrame:byteString() + data)
        return
    end
    if localHeader.dontFragment == 1 then
        return
    end
    local newHeader = {}
    for i,v in pairs(localHeader) do
        newHeader[i] = v
    end
    local NFB = (maxLen - localHeader.ihl * 4)/8

    newHeader.moreFragment = 1
    newHeader.totalLength = (newHeader.ihl*4) + (NFB*8)
    local newFrame = bitArray.create("",header)
    newFrame:SerializeTemplate(newHeader)
    table.insert(fragments,newFrame:byteString() + string.sub(data,1,NFB))

    newHeader = {}
    for i,v in pairs(localHeader) do
        newHeader[i] = v
    end
    newHeader.totalLength = localHeader.totalLength - NFB*8
    newHeader.fragmentOffset = (localHeader.fragmentOffset or 0) + NFB
    fragment(newHeader,string.sub(data,NFB),maxLen,fragments)
end

function InternetProtocol.getInterface(id)
    for i,v in ipairs(interfaces) do
        if v.mac == id then
            return v
        end
    end
end

function InternetProtocol.addInterface(interface)
    table.insert(interfaces,interface)
end

function InternetProtocol.send(dst,prot,data,id,df,options)
    local localInterface, targetGateway =  InternetProtocol.getRoute(dst)
    if not localInterface then
        return false, "route not found"
    end
    local interface = InternetProtocol.getInterface(localInterface)
    if targetGateway == 0 then
        targetGateway = dst
    end

    local newHeader = {
        ihl = 5,
        version = 4,
        dontFragment = df or 0,
        protocol = prot,
        timeToLive = 0xFF,
        sourceAddress = interface.ip,
        destinationAddress = dst,
        identification = id
    }
    newHeader.totalLength = newHeader.ihl*4 + string.len(data)

    local fragments = {}
    fragment(newHeader,data,interface.mtu,fragments)
    if fragments.len() == 0 then
        return false, "no fragments could be produced"
    end
    for i,v in ipairs(fragments) do
        interface:Send(targetGateway,v)
    end
    return true
end

function InternetProtocol.receive(data)
    local recArray = bitArray.create(string.sub(data,1,20),header)
    local recHeader = recArray:DeSerializeTemplate()

end

function InternetProtocol.addRoute()
    
end

function InternetProtocol.removeRoute()
    
end

-- Route example: {netDest = 0x7f000001, netMask = 0xffffffff, gateway = 0, interface = 0x7f000001, metric = 25}
function InternetProtocol.getRoute(targetIp)
    local localInterface, targetGateway
    local metric = 0
    for i,v in ipairs(routes) do
        if ((v.netDest & v.netMask) == (targetIp & v.netMask) and metric < v.metric) then
            localInterface = v.interface
            targetGateway = v.gateway
            metric = v.metric
        end
    end
    return localInterface, targetGateway
end

return InternetProtocol