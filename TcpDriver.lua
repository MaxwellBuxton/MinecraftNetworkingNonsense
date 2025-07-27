local event = require("event")
local s = require("serialization")
local netCore = require("netCore")
local TcpLib = require("TcpLib")
local tcpEventHandler = require("tcpEventHandler")

TCBList = {}

Queue = {first= 0, last = -1}
function Queue.new ()
    local o = {}
    setmetatable(o,Queue)
    Queue.__index = Queue
    return o
end

function Queue:insert(value)
    local last = self.last + 1
    self.last = last
    self[last] = value
end

function Queue:pull()
    local first = self.first
    local value = self[first]
    self[first] = nil
    self.first = first + 1
    return value
end

function Queue:isEmpty()
    if self.first > self.last then
        return true
    else
        return false
    end
end

function Queue:check()
    return self[self.first]
end

EventQueue = Queue.new()
EventQueue.State = "idle"

function TcpEvent(eventId, ...)
    local queuedEvent = {id = eventId, arguments = table.pack(...)}
    EventQueue:insert(queuedEvent)
    if EventQueue.State == "idle" then
        EventQueue.State = "active"
        event.push("tcp_procces")
    end
end

function TcpProccessor()
    while EventQueue:isEmpty() == false do
        local nextEvent = EventQueue:pull()
        tcpEventHandler[nextEvent.id](table.unpack(nextEvent.arguments))
    end
    EventQueue.State = "idle"
end

event.listen("net_recieve",TcpEvent)
event.listen("tcp_open",TcpEvent)
event.listen("tcp_status",TcpEvent)
event.listen("tcp_retransmit",TcpEvent)
event.listen("tcp_procces",TcpProccessor)