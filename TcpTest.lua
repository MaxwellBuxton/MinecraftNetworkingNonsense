local MaxNet = require("MaxNetLib")
local shell = require("shell")

local args,ops = shell.parse(...)
local connection = MaxNet.new(80)

if args[1] == nil then
    print("---use---")
    print(" client / server")
    print(" port, IP")
end

if args[1] ==  "server" then
    local status = connection:open(false)
    local data
    if status == "OK" then
        while status ~= "CLOSING" do
            data, status = connection:recieve()
            if status == "OK" then
                print("Recieved: "..data[1].message)
                connection:send({message = "pong"})
            end
        end
        connection:close()
        print("Test complete")
    else
        print(status)
        return
    end
elseif args[1] == "client" then
    local status = connection:open(true,args[2],args[3])
    local data = nil
    if status == "OK" then
        connection:send({message = "ping"})
        while data == nil and status == "OK" do
            data,status = connection:recieve()
        end
        if status == "OK" and data ~= nil then
            print(data[1].message)
            connection:close()
            print("Test complete")
        else
            print(status)
        end
    else
        print(status)
    end
end