local event = require("event")
local netCore = require("netCore")
local serialization = require("serialization")

function RouterSend(eventId,ip, data)
    local config = netCore.GetNetworkConfig()
    local targetIp, interface = netCore.GetRoute(ip)
    local selfMac = config.interfaces[interface]
    local address = netCore.GetARPMapping(targetIp)
    if address == nil then
        netCore.ARPRequest(targetIp,interface)
        address = netCore.GetARPMapping(targetIp)
    end

    local packet = serialization.unserialize(data)
    packet.sourceMAC = selfMac
    packet.targetMAC = address

    packet = serialization.serialize(packet)
    interface = netCore.GetInterface(interface)
    interface.send(address,80,packet)
end

function RouterRecieve(eventId,to,from,port,distance,data)
    local config = netCore.GetNetworkConfig()
    local packet = serialization.unserialize(data)
    local interface = netCore.GetInterfaceAlias(to)
    if packet.targetMAC == "ALL" and packet.data.protocol == "ARP" and packet.targetIP == config.IP[interface] then
        netCore.ARPResponse(packet)
    elseif packet.targetMAC ~= "ALL" and packet.data.protocol ~= "ARP" then
        event.push("net_recieve", packet.targetIP, serialization.serialize(packet))
    end
end

local networkconfig = netCore.GetNetworkConfig()
for interface in pairs(networkconfig.interfaces) do
    local nic = netCore.GetInterface(interface)
    nic.open(80)
end
event.listen("modem_message",RouterRecieve)
event.listen("net_recieve",RouterSend)