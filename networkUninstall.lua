local fs = require("filesystem")

function RemoveFile(path)
    if fs.exists(path) then
        fs.remove(path)
        print("removed: "..path)
    end
end

RemoveFile("/ARPCache")
RemoveFile("/RoutingTable")
RemoveFile("/NetworkConfig")
RemoveFile("/netCore")
RemoveFile("/routerDriver.lua")
RemoveFile("/interfaceTest.lua")
RemoveFile("/modRoute.lua")
RemoveFile("/netdriver.lua")
RemoveFile("/networkTest.lua")
RemoveFile("/flushArp.lua")
print("Network stack unistalled")