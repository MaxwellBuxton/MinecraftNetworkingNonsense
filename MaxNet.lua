local shell = require("shell")
local event = require("event")
local TcpLib = require("TcpLib")
local s = require("serialization")

local args,ops = shell.parse(...)

function MaxNetSend(port,remoteIp,remotePort,active)
    local remoteSocket = {IP=remoteIp,PORT=remotePort}
    local state = "CLOSED"
    local connectionId = TcpLib.getConnectionId(port,remoteSocket)
    event.push("tcp_open",port,s.serialize(remoteSocket),active)

    if active == false then
        while state == "LISTEN" or state == "CLOSED" do
            local eventId,recievedPort,connection,returnState,message = event.pullMultiple("tcp_open_return","interrupted")
            if eventId == "interrupted" then
                return
            end
            if recievedPort == port then
                print(message)
                connectionId = connection
                state = returnState
            end
        end
    end

    while state ~= "ESTABLISHED" do
        local eventId,_,connection,returnState,message = event.pullMultiple("tcp_open_return","interrupted")
        if eventId == "interrupted" then
            return
        end
        if connection == connectionId then
            print(message)
            state = returnState
        end
    end
    print("connection")
end

if args[1] == "send" then
    local activeSet = true
    if ops["l"] == true then
        activeSet = false
    end
    MaxNetSend(args[2],args[3],args[4],activeSet)
else
    print("-----commands-----")
    print("send: args| port, remoteIp, remotePort | ops | -l : listen |")
end