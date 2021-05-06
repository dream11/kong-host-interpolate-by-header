local kong = kong
local tostring = tostring
local tonumber = tonumber

local HostByHeaderHandler = {}

HostByHeaderHandler.PRIORITY = 810
HostByHeaderHandler.VERSION = "1.0.0"

local function prepare_host(host, placeholder)
    host = host:gsub("<PLACE_HOLDER>", placeholder)
    return host
end

function HostByHeaderHandler:access(conf)
    local header = kong.request.get_header(conf.header_name)
    if header == nil or #header == 0 then
        kong.log.err("No such header received in request: " .. conf.header_name)
        return
    end

    local value = header

    if conf.operation == "multiply" and tonumber(value) then
        value = tonumber(value) * conf.arithmetic_operand
    elseif conf.operation == "add" and tonumber(value) then
        value = tonumber(value) + conf.arithmetic_operand
    elseif conf.operation == "modulo" and tonumber(value) then
        value = tonumber(value) % conf.arithmetic_operand
    end


    local placeholder = tostring(value)
    local host = prepare_host(conf.host, placeholder)
    kong.log.debug("Final value of hostname is: " .. host)
    kong.service.set_target(host, tonumber(80))
    kong.ctx.shared.upstream_host = host
end

return HostByHeaderHandler