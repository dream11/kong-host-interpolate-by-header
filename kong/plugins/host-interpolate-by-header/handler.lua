local HostInterpolateByHeaderHandler = {}

HostInterpolateByHeaderHandler.VERSION = "1.0.0"
HostInterpolateByHeaderHandler.PRIORITY = tonumber(os.getenv("PRIORITY_HOST_INTERPOLATE_BY_HEADER")) or 810
kong.log.info("Plugin priority set to " .. HostInterpolateByHeaderHandler.PRIORITY ..
(os.getenv("PRIORITY_HOST_INTERPOLATE_BY_HEADER") and " from env" or " by default"))


local function interpolate_header(host, _header, header_val, conf)
  local value = header_val
  if conf.operation == "modulo" and tonumber(value) then
    value = tonumber(value) % conf.modulo_by
  end

  _header = _header:gsub("%-","%%%-")
  host = host:gsub("<" .. _header .. ">", tostring(value))
  return host
end

local function interpolate_env_variable(host, env, env_val)
  env = env:gsub("%-","%%%-")
  host = host:gsub("<" .. env .. ">", tostring(env_val))
  return host
end


function HostInterpolateByHeaderHandler:access(conf)
  local host = conf.host
  if #conf.headers > 0 then
    for _, _header in ipairs(conf.headers) do
      local header_val = kong.request.get_header(_header:lower())
      if header_val == nil then
        if conf.fallback_host and conf.fallback_host ~= "" then
          kong.log.info(_header .. ": header not present. Falling back to " .. conf.fallback_host)
          host = conf.fallback_host
          break
        else
          kong.log.err("Failing to resolve hostname as '" .. _header .. "' header not present")
          -- request unprocessable
          return kong.response.exit(422, {error = "header not present: " .. _header})
        end
      else
        host = interpolate_header(host, _header, header_val, conf)
      end
    end
  end

  if #conf.environment_variables > 0 then
    for _, env in ipairs(conf.environment_variables) do
      local env_val = os.getenv(env)
      if env_val == nil then
        if conf.fallback_host and conf.fallback_host ~= "" then
          kong.log.info(env .. ": environment variable not present. Falling back to " .. conf.fallback_host)
          host = conf.fallback_host
          break
        else
          kong.log.err("Failing to resolve hostname as '" .. env .. "' environment variable not present")
          -- request unprocessable
          return kong.response.exit(422, {error = "environment variable not present: " .. env})
        end
      else
        host = interpolate_env_variable(host, env, env_val)
      end
    end
  end

  kong.log.debug("Final value of hostname is: " .. host)
  kong.service.set_target(host, tonumber(conf.port))
  kong.ctx.shared.upstream_host = host
end

return HostInterpolateByHeaderHandler
