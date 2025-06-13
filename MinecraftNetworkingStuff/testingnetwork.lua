local serialization = require("serialization")
local component = require("component")
local event = require("event")
local nic = component.modem

function GetNetworkConfig()
    print("loading config...")
    local networkConfigString = io.open("NetworkConfig")
    local networkConfig = serialization.unserialize(networkConfigString:read("*a"))
    if networkConfig ~= nil then
        print("config loaded")
    else
        print("ERROR: config not found")
    end
    networkConfigString:close()
    return networkConfig
end

function GetARPCache()
    print("loading ARP cache...")
    local arpCacheString = io.open("ARPCache")
    local arpCache = serialization.unserialize(arpCacheString:read("*a"))
    if arpCache ~= nil then
        print("ARP cache loaded")
    else
        print("ERROR: ARP cache not found")
    end
    arpCacheString:close()
    return arpCache
end

function GetARPMapping(ip)
    print("loading mapping for "..ip.."")
    local cache = GetARPCache()
    if cache[ip] ~= nil then
        print("loaded mapping: "..ip.." = "..cache[ip].."")
    else
        print("WARNING: mapping "..ip.." not found")
    end
    return cache[ip]
end

function SetARPCache(cache)
    print("saving to ARP cache...")
    os.remove("ARPCache")
    local arpCacheFile = io.open("ARPCache","w")
    arpCacheFile:write(serialization.serialize(cache))
    arpCacheFile:close()
    print("cache saved")
end

-- ARP functions asume that source port has been opened
function ARPRequest(targetIp, targetport, sourceport)
    local config = GetNetworkConfig()
    print("generating packet...")
    local packet = {
        sourcePort = sourceport, 
        targetPort = targetport, 
        sourceMAC = config.MAC, 
        targetMAC = "ALL", 
        sourceIP = config.IP, 
        targetIP = targetIp, 
        data = {protocol = "ARP", action = "GET"}
    }
    packet = serialization.serialize(packet)
    print("packet created")
    print("sending ARP request on "..targetport.."")
    local broad = nic.broadcast(targetport,packet)
    if broad == true then
        print("request sent")
    else
        print("ERROR: request failed")
    end
    local action = ""
    local protocol = ""
    print("awaiting response...")
    while action ~= "POST" and protocol ~= "ARP" do
        _, _, from, port, _, message = event.pull("modem_message")
        print("response recieved: "..message.."")
        message = serialization.unserialize(message)
        action = message.data.action
        protocol = message.data.protocol
    end
    local cache = GetARPCache()
    cache[message.sourceIP] = message.sourceMAC
    SetARPCache(cache)
end

function ARPResponse(recievedPacket, sourceport)
    local config = GetNetworkConfig()
    local cache = GetARPCache()
    cache[recievedPacket.sourceIP] = recievedPacket.sourceMAC
    SetARPCache(cache)
    print("generating ARP response packet...")
    packet = {
        sourcePort = sourceport,
        targetPort = recievedPacket.sourcePort,
        sourceMAC = config.MAC,
        targetMAC = GetARPMapping(recievedPacket.sourceIP),
        sourceIP = config.IP,
        targetIP = recievedPacket.sourceIP,
        data = {protocol = "ARP", action = "POST"}
    }
    packet = serialization.serialize(packet)
    print("packet created")
    print("sending response to "..recievedPacket.sourceIP.." on "..sourceport.."")
    local sent = nic.send(GetARPMapping(recievedPacket.sourceIP),sourceport,packet)
    if sent == true then
        print("response sent")
    else
        print("ERROR: response failed")
    end
end

function NetSend(ip, targetPort, sourcePort, data)
    print("sending packet to: "..ip.." on "..targetPort.."")
    if IsLocalNetwork(ip) then
        local config = GetNetworkConfig()
        local targetMac = GetARPMapping(ip)
        if targetMac == nil then
            ARPRequest(ip, targetPort, sourcePort)
            targetMac = GetARPMapping(ip)

            if targetMac == nil then
                return "ERROR: 404 could not find target host"
            end
        end
        print("generating packet...")
        local packet = {
            sourcePort = sourcePort,
            targetPort = targetPort,
            sourceMAC = config.MAC,
            targetMAC = targetMac,
            sourceIP = config.IP,
            targetIP = ip,
            data = data
        }
        local packetString = serialization.serialize(packet)
        print("packet created")
        print("sending...")
        if nic.send(targetMac,targetPort,packetString) then
            return "SUCCESS: packet sent"
        else
            return "ERROR: unable to complete action"
        end
    else
        local config = GetNetworkConfig()
        local gateway = config.DefaultGateway
        local targetMac = GetARPMapping(gateway)
        if targetMac == nil then
            ARPRequest(gateway, 80, sourcePort)
            targetMac = GetARPMapping(gateway)

            if targetMac == nil then
                return "ERROR: 404 could not find target host"
            end
        end
        print("generating packet...")
        local packet = {
            sourcePort = sourcePort,
            targetPort = targetPort,
            sourceMAC = config.MAC,
            targetMAC = targetMac,
            sourceIP = config.IP,
            targetIP = ip,
            data = data
        }
        local packetString = serialization.serialize(packet)
        print("packet created")
        print("sending to gateway...")
        if nic.send(targetMac,80,packetString) then
            return "SUCCESS: packet sent"
        else
            return "ERROR: unable to complete action"
        end
    end
end

function NetRecieve()
    local config = GetNetworkConfig()
    print("awaiting message...")
    local _, _, from, port, _, message = event.pull("modem_message")
    print("message recieved "..message.."")
    packet = serialization.unserialize(message)
    if packet.targetIP == config.IP then
        if packet.data.protocol == "ARP" and packet.data.action == "GET" then
            ARPResponse(packet,packet.sourcePort)
            return nil
        else
            return packet
        end
    end
end

function IsLocalNetwork(ip)
    local config = GetNetworkConfig()
    local netMask = SerializeIp(config.NetMask)
    local targetIp = SerializeIp(ip)
    local selfIp = SerializeIp(config.IP)
    print("matching "..serialization.serialize(selfIp).." to "..serialization.serialize(targetIp).." with "..serialization.serialize(netMask).."")
    
    for i,byte in pairs(netMask) do
        if byte == "255" and selfIp[i] ~= targetIp[i] then
            print("address not local...")
            return false
        end
    end
    print("address local...")
    return true
end

function SerializeIp(ip)
    local serializedIp = {}
    for n in string.gmatch(ip,"%d*") do
        table.insert(serializedIp, n)
    end
    return serializedIp
end