local event = require("event")
local shell = require("shell")
local serialization = require("serialization")

local args,ops = shell.parse(...)

if args[1] == nil then
    print("use: networkTest send/listen [IP]")
else
    if args[1] == "send" then
        event.push("net_send",args[2],serialization.serialize({data = "ping"}))
        print("sent")
    elseif args[1] == "listen" then
        local eventId,packet = event.pull("net_recieve")
        packet = serialization.unserialize(packet)
        print(packet.data)
    end
end