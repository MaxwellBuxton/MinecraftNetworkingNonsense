local BitArray = {buffIndex = 1, buff = {}, template = {}}

function BitArray.create(data,template)
    local dat = data or ""
    local newArry = setmetatable({},{__index = BitArray})
    for char in dat:gmatch(".") do
        table.insert(newArry.buff,char)
    end
    newArry.template = template
    return newArry
end

function BitArray:write(length, buffer)
    local tBufferOffset
    local tBitOffset
    local sBuff = buffer
    local endIndex = self.buffIndex + length
    while self.buffIndex < endIndex do
        tBufferOffset = math.floor((self.buffIndex - 1) / 8) + 1
        tBitOffset = (self.buffIndex - 1) % 8
        local wLen = math.min(8-tBitOffset, endIndex - self.buffIndex)

        local byteSegment = (sBuff & (2^wLen-1)) << tBitOffset
        sBuff = sBuff >> wLen

        local tByte
        if self.buff[tBufferOffset] then
            tByte = string.byte(self.buff[tBufferOffset])
        else
            tByte = 0
        end
        self.buff[tBufferOffset] = string.char(tByte | byteSegment)
        self.buffIndex = self.buffIndex + wLen
    end
end

function BitArray:read(length)
    local tBufferOffset
    local tBitOffset
    local sBuff = 0
    local endIndex = self.buffIndex + length
    while self.buffIndex < endIndex do
        tBufferOffset = math.floor((self.buffIndex - 1) / 8) + 1
        tBitOffset = (self.buffIndex - 1) % 8
        local rLen = math.min(8-tBitOffset, endIndex - self.buffIndex)

        local byteSegment = (string.byte(self.buff[tBufferOffset]) >> tBitOffset) & (2^rLen-1)

        sBuff = sBuff | (byteSegment << (length - (endIndex - self.buffIndex)))
        self.buffIndex = self.buffIndex + rLen
    end
    return sBuff
end

function BitArray:SerializeTemplate(data)
    for i,entry in ipairs(self.template) do
        if entry[2] == "string" then
            local bytes = string.byte(data[i],1,-1)
            for x = 1, math.ceil(entry[1] / 8) do
                self:write(math.min(entry[1]-8*(x-1),8),bytes[x])
            end
        else
            self:write(entry[1],data[i] or 0)
        end
    end
end

function BitArray:DeSerializeTemplate()
    local newTable = {}
    for i,entry in ipairs(self.template) do
        if entry[2] == "string" then
            newTable[i] = ""
            for x = 1, math.ceil(entry[1] / 8) do
                newTable[i] = newTable[i]..self:read(math.min(entry[1]-8*(x-1),8))
            end
        else
            newTable[i] = self:read(entry[1])
        end
    end
    return newTable
end

--operations: cur -> current index | set, newIndex:int -> sets index | offset, offset:Int -> offsets current index | len -> length of array in bits
function BitArray:seek(op,...)
    local handler = {}
    handler.cur = function ()
        return self.buffIndex
    end
    handler.set = function (newIndex)
        self.buffIndex = newIndex
    end
    handler.offset = function (offset)
        self.buffIndex = self.buffIndex + offset
    end
    handler.len = function ()
        return (#self.buff)*8
    end

    return handler[op](table.unpack(...))
end

function BitArray:byteString()
    return table.concat(self.buff)
end

function BitArray:HexString()
    return self.parseHex(self:byteString())
end

function BitArray.parseHex(data)
 return data:gsub(".",function (c)
    return string.format("%02x",string.byte(c))
 end)
end

return BitArray