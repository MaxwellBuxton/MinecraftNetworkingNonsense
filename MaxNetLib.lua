local shell = require("shell")
local event = require("event")
local TcpLib = require("TcpLib")
local s = require("serialization")

local MaxNetLib = {}

function MaxNetLib.new(port)
    local newMaxNet = {}
    newMaxNet.port = port or "80"
    newMaxNet.remoteSocket = {PORT = "0",IP = "0.0.0.0"}
    newMaxNet.connectionId = ""
    newMaxNet.log = false
    newMaxNet.state = "CLOSED"
    setmetatable(newMaxNet,{__index = MaxNetLib})
    return newMaxNet
end

function MaxNetLib:open(active,port,ip)
    if port ~= nil and ip ~= nil then
        self.remoteSocket = {PORT = port, IP = ip}
    end
    self.connectionId =  TcpLib.getConnectionId(self.port,self.remoteSocket)
    event.push("tcp_open",self.port,s.serialize(self.remoteSocket),active)
    if active == false then
        self.state = "LISTEN"
        while self.state == "LISTEN" do
            local eventId,eventConnection,message = event.pullMultiple("tcp_listen_return","tcp_log_return")
            if eventId == "tcp_listen_return" and eventConnection == self.connectionId then
                self.connectionId = message
                self.state = "OPENING"
                print("Connection Request: "..self.connectionId)
            end
            if eventId == "tcp_log_return" and eventConnection == self.connectionId then
                print("Log: "..message)
            end
        end
    else
        self.state = "OPENING"
    end
    while self.state == "OPENING" do
        local eventId,eventConnection,message = event.pullMultiple("tcp_open_return","tcp_log_return","ConnectionReset")
        if self.connectionId == eventConnection then
            if eventId == "tcp_open_return" then
                print("Connection: "..message)
                if message == "OK" then
                    self.state = "CONNECTED"
                    return "OK"
                else
                    self.state = "CLOSED"
                    return "ERROR"
                end
            end
            if eventId == "tcp_log_return" then
                print("Log: "..message)
            end
            if eventId == "ConnectionReset" then
                print("ERROR: Connection reset")
                self.state = "CLOSED"
                return "ERROR"
            end
        end
    end
end

function MaxNetLib:send(data)
    if self.state == "CONNECTED" then
        event.push("tcp_send",self.connectionId,s.serialize(data))
        print("Data queued for sending")
    end
end

function MaxNetLib:recieve()
    local data = nil
    local recieveStatus = nil
    event.push("tcp_recieve",self.connectionId)
    while data == nil and recieveStatus ~= "CLOSING" and recieveStatus ~= "CLOSED" do
        local eventId,eventConnection,message,push,status = event.pullMultiple("tcp_recieve_return","tcp_log_return")
        if eventId == "tcp_log_return" and eventConnection == self.connectionId then
            print("Log: "..message)
        end
        if eventId == "tcp_recieve_return" and eventConnection == self.connectionId then
            data = message
            recieveStatus = status
        end
    end
    if data ~= nil then
        for i,v in pairs(data) do
            data[i] = s.unserialize(v)
        end
    end
    return data, recieveStatus
end

function MaxNetLib:close()
    event.push("tcp_close",self.connectionId)
    local eventId,eventConnection,message = event.pull("tcp_close_return")
    print("Close status: "..message)
    self.state = "CLOSED"
end

function MaxNetLib:status()
    
end

function MaxNetLib:abort()
    
end

return MaxNetLib