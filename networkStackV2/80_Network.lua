local internet = require("InternetLayerService")
local event = require("event")

--load ARP extension
local ARP = doFile("addressResolution")

--initialize interface components and inject into internet module
local interfaceDriver = loadFile("interfaceDriver")
interfaceDriver.init(ARP)

--begin networking initialization
function initNetwork()
    
end

event.listen("init",initNetwork)