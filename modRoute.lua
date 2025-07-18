local shell = require("shell")
local netCore = require("netCore")
local term = require("term")
local serialization = require("serialization")

function AddRoute(args)
    if args[1] == nil then
        print("error: invalid argument")
        return
    end
    print("enter target:")
    local target = term.read()
    target = string.gsub(target,"\n","")
    print("is direct connect y/n")
    local rType = ""
    if string.gsub(term.read(),"\n","") == "y" then
        rType = "DC"
    else
        rType = "STATIC"
    end
    print("enter mask percision:")
    local percision = string.gsub(term.read(),"\n","")
    percision = percision + 0
    local mask = ""
    for i=1, 4 do
        if percision > 0 then
            mask = mask.."255"
            percision = percision - 1
        else
            mask = mask.."0"
        end
        if i ~= 4 then
            mask = mask.."."
        end
    end
    local route = {Dest = args[1],Target = target,Type = rType,Mask = mask}
    local RoutingTable = netCore.GetRoutingTable()
    table.insert(RoutingTable,route)
    SetRoutingTable(RoutingTable)
    print("Route "..serialization.serialize(route).." added")

end

function RemoveRoute(args)
    if args[1] == nil then
        print("error: invalid argument")
        return
    end
    local RoutingTable = netCore.GetRoutingTable()
    local newRoutingTable = {}
    for route in pairs(RoutingTable) do
        if route.Dest ~= args[1] then
            table.insert(newRoutingTable,route)
        end
    end
    SetRoutingTable(newRoutingTable)
    print("Route removed")
end

function ListRoute(args)
    local RoutingTable = netCore.GetRoutingTable()
    local routeList = {}
    if args[1] ~= nil then
        for i,route in pairs(RoutingTable) do
            if route.Dest == args[1] then
                local readableRoute = "Dest: "..route.Dest.."Target: "..route.Target.."Type: "..route.Type.."Mask: "..route.Mask
                table.insert(routeList,readableRoute)
            end
        end
    else
        for i,route in pairs(RoutingTable) do
            local readableRoute = "Dest: "..route.Dest.." Target: "..route.Target.." Type: "..route.Type.." Mask: "..route.Mask
            table.insert(routeList,readableRoute)
        end
    end
    for i,routeString in pairs(routeList) do
        print(routeString)
    end
end

function SetRoutingTable(routeTable)
    os.remove("RoutingTable")
    local routeTableString = io.open("RoutingTable","w")
    routeTableString:write(serialization.serialize(routeTable))
    routeTableString:close()
end

local args,ops = shell.parse(...)
if args == {} and ops == {} then
    print("commands \n -r destination ## removes route\n -a destination adds route\n -l [destination] list all or specified routes")
else
    if ops["r"] then
        RemoveRoute(args)
    elseif ops["a"] then
        AddRoute(args)
    elseif ops["l"] then
        ListRoute(args)
    else
        print("error: invalid operator")
    end
end