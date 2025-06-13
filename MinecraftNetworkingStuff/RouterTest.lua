component = require("component")
event = require("event")
serialization = require("serialization")

local config = GetNetworkConfig()
for value in pairs(config.interfaces) do
    local modem = GetInterface(value)
    modem.open(80)
end
while true do
    local packet
    while packet == nil do
        print("recieving")
        packet = RouterRecieve()
    end
    if packet ~= nil then
        if packet.targetMAC ~= "ALL" then
            RouterSend(packet.targetIP, packet.sourceIP, packet.data)
        end
    end
end