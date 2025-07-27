local component = require("component")
local serialization = require("serialization")
local term = require("term")
local routerMode = false

function InstallFile(sourePath,targetPath)
    local installFile
    local installFilecopy

    installFile = io.open(sourePath)
    installFilecopy = installFile:read("*a")
    installFile:close()
    installFile = io.open(targetPath,"w")
    installFile:write(installFilecopy)
    installFile:close()
    print(sourePath.." -> "..targetPath)
end

print("enable router install mode? (y/n)")
local mode = term.read()
if string.gsub(mode,"\n","") == "y" then
    routerMode = true
end

local NetConfig = {IP = nil, interfaces = nil}
local interfaces = {}
local IPS = {}
local ipAdress = ""
local routingTable = {}

if routerMode == true then
    local modems ={}
    for address, comp in pairs(component.list("modem")) do
        table.insert(modems,address)
    end
    interfaces.RIGHT = modems[1]
    interfaces.LEFT = modems[2]
    NetConfig.interfaces = interfaces
    print("enter IP Left")
    ipAdress = term.read()
    ipAdress = string.gsub(ipAdress,"\n","")
    IPS.LEFT = ipAdress
    print("enter IP RIGHT")
    ipAdress = term.read()
    ipAdress = string.gsub(ipAdress,"\n","")
    IPS.RIGHT = ipAdress
    NetConfig.IP = IPS
    NetConfig = serialization.serialize(NetConfig)
    print(NetConfig)
else
    for address, comp in pairs(component.list("modem")) do
        interfaces["MAIN"] = address
    end
    NetConfig.interfaces = interfaces
    print("enter IP")
    ipAdress = term.read()
    ipAdress = string.gsub(ipAdress,"\n","")
    IPS.MAIN = ipAdress
    print("enter local network")
    local localNet = term.read()
    localNet = string.gsub(localNet,"\n","")
    NetConfig.IP = IPS
    NetConfig = serialization.serialize(NetConfig)
    print(NetConfig)
    print("enter default gateway")
    local gateway = term.read()
    gateway = string.gsub(gateway,"\n","")
    local route = {Dest = localNet, Mask = "255.255.255.0", Type = "DC", Target = "MAIN"}
    table.insert(routingTable,1,route)
    route = {Dest = "0.0.0.0", Mask = "0.0.0.0", Type = "STATIC", Target = gateway}
    table.insert(routingTable,2,route)
end

local file
local filecopy

file = io.open("/NetworkConfig","w")
file:write(NetConfig)
file:close()
print("NetworkConfig -> /NetworkConfig")

local arpCache = {}
arpCache = serialization.serialize(arpCache)
file = io.open("/ARPCache","w")
file:write(arpCache)
file:close()
print("ARPCache -> /ARPCache")

routingTable = serialization.serialize(routingTable)
file = io.open("/RoutingTable","w")
file:write(routingTable)
file:close()
print("RoutingTable -> /RoutingTable")

InstallFile("netCore.lua","/lib/netCore.lua")
InstallFile("flushArp.lua","/flushArp.lua")

if routerMode == true then
    InstallFile("routerDriver.lua","/routerDriver.lua")

    InstallFile("interfaceTest.lua","/interfaceTest.lua")

    InstallFile("modRoute.lua","/modRoute.lua")

    print("install complete")
    print("to complete setup add routes via modRoute")
    print("test interface orientaion with interfaceTest")

else
    InstallFile("netdriver.lua","/netdriver.lua")
    
    InstallFile("networkTest.lua","/networkTest.lua")

    InstallFile("TcpLib.lua","/lib/TcpLib.lua")

    InstallFile("tcpEventHandler.lua","/lib/tcpEventHandler.lua")

    InstallFile("TcpDriver.lua","/TcpDriver.lua")

    print("install complete")
    print("use networkTest for testing connections")
end