function GetNetworkConfig()
    local networkConfigString = io.open("NetworkConfig")
    local networkConfig = serialization.unserialize(networkConfigString:read("*a"))
    networkConfigString:close()
    return networkConfig
end

function GetARPCache()
    local arpCacheString = io.open("ARPCache")
    local arpCache = serialization.unserialize(arpCacheString:read("*a"))
    arpCacheString:close()
    return arpCache
end

function GetARPMapping(ip)
    local cache = GetARPCache()
    print("loaded mapping for "..ip.."")
    return cache[ip]
end

function SetARPCache(cache)
    os.remove("ARPCache")
    local arpCacheFile = io.open("ARPCache","w")
    arpCacheFile:write(serialization.serialize(cache))
    arpCacheFile:close()
end

function GetRoutingTable()
    local routingString = io.open("RoutingTable")
    local routingTable = serialization.unserialize(routingString:read("*a"))
    routingString:close()
    return routingTable
end

function GetInterface(interKey)
    local config = GetNetworkConfig()
    print ("getting proxy for interface: "..interKey.."")
    return component.proxy(config.interfaces[interKey])
end

function SerializeIp(ip)
    local serializedIp = {}
    for n in string.gmatch(ip,"%d*") do
        table.insert(serializedIp, n)
    end
    return serializedIp
end

function NetMaskMatch(selfip,targetip ,Mask)
    local targetIpTable = SerializeIp(targetip)
    local selfIpTable = SerializeIp(selfip)
    local maskTable = SerializeIp(Mask)
    print("matching "..selfip.."to "..targetip.."with "..Mask.."")
    for i,byte in pairs(maskTable) do
        if byte == "255" and selfIpTable[i] ~= targetIpTable[i] then
            return false
        end
    end
    return true
end

function GetRoute(IP)
    local table = GetRoutingTable()
    print("getting route to"..IP.."")
    local Type
    local target
    local searchIp = IP
    while Type~= "DC" do
        Type, target = RouteSearch(table,searchIp)
        print("found "..Type.."route to "..target.."")
        if Type == "STATIC" then
            searchIp = target
        end
        if Type == nil and target == nil then
            print("failed to find route")
            return nil, nil
        end
    end
    return searchIp, target
end

function RouteSearch(table,IP)
    local mask = ""
    local dest = ""
    for ite,route in pairs(table) do
        mask = route.Mask
        dest = route.Dest
        local match = NetMaskMatch(dest,IP,mask)
        if match == true then
            return route.Type, route.Target
        end
    end
    return nil, nil
end

function ARPRequest (IP,Interface)
    local config = GetNetworkConfig()
    print("sending ARP request to"..IP.."on "..Interface.."interface")
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
    local nic = GetInterface(Interface)
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
    print("recived ARP response")
    local cache = GetARPCache()
    cache[message2.sourceIP] = message2.sourceMAC
    SetARPCache(cache)
end

function ARPResponse(recievedPacket)
    print("Responding to ARP thingie")
    local config = GetNetworkConfig()
    local cache = GetARPCache()
    cache[recievedPacket.sourceIP] = recievedPacket.sourceMAC
    SetARPCache(cache)
    local _,interface = GetRoute(recievedPacket.sourceIP)
    local packet = {
        sourcePort = 80,
        targetPort = 80,
        sourceMAC = config.interfaces[interface],
        targetMAC = GetARPMapping(recievedPacket.sourceIP),
        sourceIP = config.IP[interface],
        targetIP = recievedPacket.sourceIP,
        data = {protocol = "ARP", action = "POST"}
    }
    packet = serialization.serialize(packet)
    local address = GetARPMapping(recievedPacket.sourceIP)
    local interface = GetInterface(interface)
    print("sending ARp Resposne at "..address.."")
    interface.send(address,80,packet)
end

function RouterSend(IP, sourceIp, data)
    print("sending...")
    local config = GetNetworkConfig()
    local targetIp, interface = GetRoute(IP)
    local selfMac = interface
    print("sending on"..interface.."to "..targetIp.."")
    local address = GetARPMapping(targetIp)
    if address == nil then
        print("WARNNING: address not found for"..targetIp.."")
        ARPRequest(targetIp,interface)
        address = GetARPMapping(targetIp)
    end
    local packet = {
        sourcePort = 80,
        targetPort = 80,
        sourceMAC = selfMac,
        targetMAC = address,
        sourceIP = sourceIp,
        targetIP = IP,
        data = data
    }
    packet = serialization.serialize(packet)
    interface = GetInterface(interface)
    interface.send(address,80,packet)
    print("sent")
end

function RouterRecieve()
    local config = GetNetworkConfig()
    local _, _, from, port, _, message = event.pull("modem_message")
    print("recieved")
    local packet = serialization.unserialize(message)
    local _,interface = GetRoute(packet.sourceIP)
    if packet.targetMAC == "ALL" and packet.data.protocol == "ARP" and packet.targetIP == config.IP[interface] then
        print("is ARP request")
        ARPResponse(packet)
        return nil
    else
        return packet
    end
end