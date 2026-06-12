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

local function proccessDatagram(localHeader,data,target,interface)
    
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
        destinationAddress = dst
    }
    newHeader.totalLength = newHeader.ihl*4 + string.len(data)

    
end

function InternetProtocol.receive()
    
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