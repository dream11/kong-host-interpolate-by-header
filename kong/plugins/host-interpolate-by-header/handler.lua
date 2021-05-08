local HostByHeaderHandler = {}

HostByHeaderHandler.PRIORITY = 810
HostByHeaderHandler.VERSION = "1.0.0"

local function prepare_host(host, _header, header_val, conf)
  local value = header_val
  if conf.operation == "modulo" and tonumber(value) and tonumber(value) ~= 0 then
    value = tonumber(value) % conf.modulo_by
  end

  host = host:gsub("<" .. _header .. ">", tostring(value))

  return host
end

function HostByHeaderHandler:access(conf)

  local host = conf.host
  if #conf.headers > 0 then
    for _, _header in ipairs(conf.headers) do
      local header_val = kong.request.get_header(_header:lower())
      if header_val == nil then
        if conf.fallback_host ~= nil then
          kong.log.info(_header .. ": header not present. Falling back to " .. conf.fallback_host)
          host = conf.fallback_host
          break
        else
          kong.log.err("Failing with '" .. _header .. "' header not present")
          -- request unprocessable
          return kong.response.exit(422, _header .. ": header not present")
        end
      else
        host = prepare_host(host, _header, header_val, conf)
      end
    end
  end

  kong.log.debug("Final value of hostname is: " .. host)
  kong.service.set_target(host, tonumber(80))
  kong.ctx.shared.upstream_host = host
end

return HostByHeaderHandler
