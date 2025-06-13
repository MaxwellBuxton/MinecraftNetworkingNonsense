local component = require("component")
local s = require("serialization")
local term = require("term")

local NetConfig = {IP = nil, interfaces = nil}
local interfaces = {}
for adress,comp in pairs(component.list("modem")) do
    table.insert(interfaces,adress)
    print(adress)
end
NetConfig.interfaces = interfaces
print(NetConfig.interfaces[1])
print(NetConfig.interfaces[2])
local IPS = {LEFT = "", RIGHT = ""}
print("enter IP Left")
local ipAdress = term.read()
ipAdress = string.gsub(ipAdress,"\n","")
IPS.LEFT = ipAdress
print("enter IP RIGHT")
local ipAdress = term.read()
ipAdress = string.gsub(ipAdress,"\n","")
IPS.RIGHT = ipAdress
NetConfig.IP = IPS
NetConfig = s.serialize(NetConfig)
print(NetConfig)

file = io.open("NetworkConfig","w")
file:write(NetConfig)
file:close()
print("saved")

local arpCache = {}
arpCache = s.serialize(arpCache)
file = io.open("ARPCache","w")
file:write(arpCache)
file:close()
print("saved")

local routingTable = {}
routingTable = s.serialize(routingTable)
file = io.open("RoutingTable","w")
file:write(routingTable)
file:close()
print("saved")