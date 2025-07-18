local event = require("event")
local netCore = require("netCore")
local serialization = require("serialization")

function NetSend(eventId,ip, data)
    local serializedData = serialization.unserialize(data)
    local config = netCore.GetNetworkConfig()
    local targetIp, interface = netCore.GetRoute(ip)
    local address = netCore.GetARPMapping(targetIp)
    local selfMac = config.interfaces[interface]
    if address == nil then
        netCore.ARPRequest(targetIp,interface)
        address = netCore.GetARPMapping(targetIp)
    end
    local packet = {
        sourceMAC = selfMac,
        targetMAC = address,
        sourceIP = config.IP[interface],
        targetIP = ip,
    }
    for i,v in pairs(serializedData) do
        packet[i] = v
    end
    packet = serialization.serialize(packet)
    interface = netCore.GetInterface(interface)
    interface.send(address,80,packet)
end

function NetRecieve(eventId,to,from,port,distance,data)
    local config = netCore.GetNetworkConfig()
    local packet = serialization.unserialize(data)
    local interface = netCore.GetInterfaceAlias(to)
    if packet.targetMAC == "ALL" and packet.data.protocol == "ARP" and packet.targetIP == config.IP[interface] then
        netCore.ARPResponse(packet)
    elseif packet.targetMAC ~= "ALL" and packet.data.protocol ~= "ARP"  then
        event.push("net_recieve",serialization.serialize(packet))
    end
end

local networkconfig = netCore.GetNetworkConfig()
for interface in pairs(networkconfig.interfaces) do
    local nic = netCore.GetInterface(interface)
    nic.open(80)
end
event.listen("modem_message",NetRecieve)
event.listen("net_send",NetSend)