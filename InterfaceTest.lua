local shell = require("shell")
local serialization = require("serialization")
local netCore = require("netCore")

local args,ops = shell.parse(...)
if args[1] == nil then
    print("use: interfaceTest test/switch [LEFT/RIGHT]")
end
if args[1] == "test" then    
    local interfaceName = args[2]
    local interface = netCore.GetInterface(interfaceName)
    local config = netCore.GetNetworkConfig()
    print("broadcasting on"..config.IP[interfaceName])
    interface.broadcast(80,"test")
elseif args[1] == "switch" then
    local networkConfigString = io.open("NetworkConfig")
    local networkConfig = serialization.unserialize(networkConfigString:read("*a"))
    networkConfigString:close()

    local interfaceLeft = networkConfig.interfaces["LEFT"]
    local interfaceRight = networkConfig.interfaces["RIGHT"]
    networkConfig.interfaces["LEFT"] = interfaceRight
    networkConfig.interfaces["RIGHT"] = interfaceLeft

    os.remove("NetworkConfig")
    networkConfigString = io.open("NetworkConfig","w")
    networkConfigString:write(serialization.serialize(networkConfig))
    networkConfigString:close()
    print("interfaces switched")
end