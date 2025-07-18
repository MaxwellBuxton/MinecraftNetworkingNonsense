local fs = require("filesystem")
local netlog = {}

function netlog.log(data)
    local file = io.open("/networkLog")
    local log = file:read("*a")
    file:close()
    log = log..data
    file = io.open("/networkLog","w")
    file:write(log)
    file:close()
end

return netlog