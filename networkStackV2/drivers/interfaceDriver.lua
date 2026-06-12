local comp = require("component")
local event = require("event")

local Interface = {}
local broadcastAddr = "ffffffff-ffff-ffff-ffff-ffffffffffff"

--create loopback interface and register listeners to init component interfaces
local function Init(ARP,Ip)
    function Interface:Send(address,data)
        local cached, args = ARP.resolveAddress(address,data,self)
        if not cached then
            table.insert(self.sendQueue[Ip],data)
        end
        return  self:RawSend(args)
    end

    function Interface:RawSend(args)
        local addr,protoId,data = table.unpack(args)
        if addr == broadcastAddr then
            return self.proxy.broadcast(1,protoId,data)
        end
        return self.proxy.send(addr,1,protoId,data)
    end
    
    function Interface:Receive(_,to,from,port,_,proto,data)
        if Interface.mac == to then
            if proto == 0x0806 then
                ARP.receive(data,self)
                for i,y in pairs(self.sendQueue) do
                    local cached, addr = ARP.getCache(i)
                    if cached then
                        for x,v in ipairs(y) do
                            self.RawSend(table.pack(addr,0x0800,v))
                        end
                    end
                end
            end
            if proto == 0x0800 then
                
            end
        end
    end

    local function CreateInterface(addr)
        local newInter = setmetatable(
        {
            mac = addr,
            ip = nil,
            netMask = nil,
            defaultGateway = nil,
            mtu = 500,
            sendQueue = {}
        },
        {
            __index = Interface
        })
        newInter.handle = comp.proxy(addr)
        Ip.addInterface(newInter)
    end
    event.listen("Component_added",function(addr,name)if name == "modem" then CreateInterface(addr) end end)
end

-- example MAC address 01ddd2cf-1e8e-46eb-954e-42cf77d37eff