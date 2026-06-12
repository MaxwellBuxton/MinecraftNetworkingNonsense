local event = require("event")

--load DataLink Modules
local ARP = doFile("addressResolution")
local interfaceDriver = loadFile("interfaceDriver")
local IP = doFile("InternetProtocol")

interfaceDriver.init(ARP,IP)

--begin networking initialization
function initNetwork()
    
end

event.listen("init",initNetwork)