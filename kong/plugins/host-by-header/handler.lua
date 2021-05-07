local kong = kong
local tostring = tostring
local tonumber = tonumber

local HostByHeaderHandler = {}

HostByHeaderHandler.PRIORITY = 810
HostByHeaderHandler.VERSION = "1.0.0"

local function prepare_host(host, _header, conf)
  local header = kong.request.get_header(_header:lower())
  if header == nil or #header == 0 then
    kong.log.info("No such header received in request: " .. _header)
    -- do not throw err return host as it is
  else
    local value = header
    if conf.operation == "modulo" and tonumber(value) then
      value = tonumber(value) % conf.modulo_by
    end

    host = host:gsub("<" .. _header .. ">", tostring(value))
  end

  return host
end

function HostByHeaderHandler:access(conf)

  local host = conf.host
  if #conf.headers > 0 then
    for _,_header in ipairs(conf.headers) do
      host = prepare_host(host, _header, conf)
    end
  end

  kong.log.debug("Final value of hostname is: " .. host)
  kong.service.set_target(host, tonumber(80))
  kong.ctx.shared.upstream_host = host
end

return HostByHeaderHandler
