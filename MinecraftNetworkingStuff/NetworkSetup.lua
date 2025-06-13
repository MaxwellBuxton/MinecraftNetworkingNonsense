local component = require("component")
local s = require("serialization")
local term = require("term")

local NetConfig = {IP = nil, MAC = nil, DefaultGateway = nil, NetMask = "255.255.255.0"}
local MacAdress = nil
for value in pairs(component.list("modem")) do
    MacAdress = value
end
print("enter IP")
local ipAdress = term.read()
ipAdress = string.gsub(ipAdress,"\n","")
print("enter default gateway")
local gateway = term.read()
gateway = string.gsub(gateway,"\n","")
NetConfig.IP = ipAdress
NetConfig.DefaultGateway = gateway
NetConfig.MAC = MacAdress
NetConfig = s.serialize(NetConfig)
print(NetConfig)

file = io.open("NetworkConfig","w")
file:write(NetConfig)
file:close()
print("saved")