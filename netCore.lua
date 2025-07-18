local serialization = require("serialization")
local component = require("component")
local event = require("event")

local netCore = {}

function netCore.GetNetworkConfig()
    local networkConfigString = io.open("NetworkConfig")
    local networkConfig = serialization.unserialize(networkConfigString:read("*a"))
    networkConfigString:close()
    return networkConfig
end

function netCore.GetARPCache()
    local arpCacheString = io.open("ARPCache")
    local arpCache = serialization.unserialize(arpCacheString:read("*a"))
    arpCacheString:close()
    return arpCache
end

function netCore.GetARPMapping(ip)
    local cache = netCore.GetARPCache()
    return cache[ip]
end

function netCore.SetARPCache(cache)
    os.remove("ARPCache")
    local arpCacheFile = io.open("ARPCache","w")
    arpCacheFile:write(serialization.serialize(cache))
    arpCacheFile:close()
end

function netCore.GetInterface(interKey)
    local config = netCore.GetNetworkConfig()
    return component.proxy(config.interfaces[interKey])
end

function netCore.GetRoutingTable()
    local routingString = io.open("RoutingTable")
    local routingTable = serialization.unserialize(routingString:read("*a"))
    routingString:close()
    return routingTable
end

function netCore.SerializeIp(ip)
    local serializedIp = {}
    for n in string.gmatch(ip,"%d*") do
        table.insert(serializedIp, n)
    end
    return serializedIp
end

function netCore.GetInterfaceAlias(adress)
    local config = netCore.GetNetworkConfig()
    for i,v in pairs(config.interfaces) do
        if v == adress then
            return i
        end
    end
    return nil
end

function netCore.NetMaskMatch(selfip,targetip ,Mask)
    local targetIpTable = netCore.SerializeIp(targetip)
    local selfIpTable = netCore.SerializeIp(selfip)
    local maskTable = netCore.SerializeIp(Mask)
    for i,byte in pairs(maskTable) do
        if byte == "255" and selfIpTable[i] ~= targetIpTable[i] then
            return false
        end
    end
    return true
end

function netCore.RouteSearch(table,IP)
    local mask = ""
    local dest = ""
    for ite,route in pairs(table) do
        mask = route.Mask
        dest = route.Dest
        local match = netCore.NetMaskMatch(dest,IP,mask)
        if match == true then
            return route.Type, route.Target
        end
    end
    return nil, nil
end

function netCore.GetRoute(IP)
    local table = netCore.GetRoutingTable()
    local Type
    local target
    local searchIp = IP
    while Type~= "DC" do
        Type, target = netCore.RouteSearch(table,searchIp)
        if Type == "STATIC" then
            searchIp = target
        end
        if Type == nil and target == nil then
            return nil, nil
        end
    end
    return searchIp, target
end

function netCore.ARPRequest (IP,Interface)
    local config = netCore.GetNetworkConfig()
    local packet = {
        sourcePort = 80,
        targetPort = 80,
        sourceMAC = config.interfaces[Interface],
        targetMAC = "ALL",
        sourceIP = config.IP[Interface],
        targetIP = IP,
        data = {protocol = "ARP", action = "GET"}
    }
    packet = serialization.serialize(packet)
    local nic = netCore.GetInterface(Interface)
    nic.broadcast(80,packet)
    local action = ""
    local protocol = ""
    local message2
    while action ~= "POST" and protocol ~= "ARP" do
        local _, _, from, port, _, message = event.pull("modem_message")
        message2 = serialization.unserialize(message)
        action = message2.data.action
        protocol = message2.data.protocol
    end
    local cache = netCore.GetARPCache()
    cache[message2.sourceIP] = message2.sourceMAC
    netCore.SetARPCache(cache)
end

function netCore.ARPResponse(recievedPacket)
    local config = netCore.GetNetworkConfig()
    local cache = netCore.GetARPCache()
    cache[recievedPacket.sourceIP] = recievedPacket.sourceMAC
    netCore.SetARPCache(cache)
    local _,interface = netCore.GetRoute(recievedPacket.sourceIP)
    local packet = {
        sourcePort = 80,
        targetPort = 80,
        sourceMAC = config.interfaces[interface],
        targetMAC = netCore.GetARPMapping(recievedPacket.sourceIP),
        sourceIP = config.IP[interface],
        targetIP = recievedPacket.sourceIP,
        data = {protocol = "ARP", action = "POST"}
    }
    packet = serialization.serialize(packet)
    local address = netCore.GetARPMapping(recievedPacket.sourceIP)
    local interface = netCore.GetInterface(interface)
    interface.send(address,80,packet)
end

return netCore