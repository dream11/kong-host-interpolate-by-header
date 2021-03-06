local cjson = require "cjson"
local helpers = require "spec.helpers"

local SERVER_PORT = 15555
local SERVER_IP = "127.0.0.1"

for _, strategy in helpers.each_strategy() do
  describe(
    "Testing host-interpolate-by-header plugin working on[#" .. strategy .. "]",
    function()
      local proxy_client, admin_client, host_interpolate_by_header
      local bp
      local db

      local function update_config(plugin, host, fallback_host, operation, modulo_by, header_list, port)
        -- Update plugin config via admin_client
        admin_client = helpers.admin_client(60000)
        local url = "/plugins/" .. host_interpolate_by_header["id"]
        local res = admin_client:patch(
          url,
          {
            headers = {
              ["Content-Type"] = "application/json"
            },
            body = {
              name = plugin,
              config = {
                host = host,
                fallback_host = fallback_host,
                port = port,
                headers = header_list,
                operation = operation,
                modulo_by = modulo_by,
              },
              enabled = true,
              consumer = nil
            }
          }
        )
        assert(res.status == 200 )
      end

      setup(
        function()
          bp, db = helpers.get_db_utils(strategy, {"routes", "services", "plugins"}, {"host-interpolate-by-header"})

          assert(
            bp.routes:insert(
              {
                paths = {"/gethost"},
                strip_path = false,
                preserve_host = true,
                protocols = {"http"},
                service = bp.services:insert(
                  {
                    protocol = "http",
                    host = "test.com",
                    port = SERVER_PORT,
                    name = "team"
                  }
                )
              }
            )
          )

          host_interpolate_by_header = bp.plugins:insert {
            name = "host-interpolate-by-header",
            config = {
              host = "service_<PLACE_HOLDER1>_<PLACE_HOLDER2>.com",
              headers = {"PLACE_HOLDER1", "PLACE_HOLDER2"},
              fallback_host = "service_fallback.com",
              operation = "none",
              modulo_by = 1,
            }
          }

          local fixtures = {
            dns_mock = helpers.dns_mock.new()
          }
          fixtures.dns_mock:SRV {
            name = "service_abc_xyz.com",
            target = SERVER_IP,
            port = SERVER_PORT
          }
          fixtures.dns_mock:SRV {
            name = "service_fallback.com",
            target = SERVER_IP,
            port = SERVER_PORT
          }
          fixtures.dns_mock:SRV {
            name = "service_shard_1.com",
            target = SERVER_IP,
            port = SERVER_PORT
          }

          assert(
            helpers.start_kong(
              {
                database = strategy,
                plugins = "host-interpolate-by-header",
                nginx_conf = "/kong/spec/fixtures/custom_nginx.template"
              },
              nil,
              nil,
              fixtures
            )
          )
          proxy_client = helpers.proxy_client()
          admin_client = helpers.admin_client(60000) -- 60000 is timeout for lua-resty-http
        end
      )

      teardown(
        function()
          proxy_client:close()
          admin_client:close()
          helpers.stop_kong()
          db:truncate()
        end
      )

      describe(
        "\n ** Request should go to fallback host when no placeholder header is present ",
        function()

          it(
            "\nStatus code should be 200 and host should be fallback_host",
            function()
              proxy_client = helpers.proxy_client()
                local res =
                  assert(
                  proxy_client:send(
                    {
                      method = "GET",
                      path = "/gethost",
                      headers = {
                        ["Content-type"] = "application/json"
                      }
                    }
                  )
                )
              local body_data = assert(res:read_body())
              body_data = cjson.decode(body_data)
              assert(res.status == 200)
              assert(body_data.headers.host == "service_fallback.com")
            end
          )
        end
      )

      describe(
        "\n ** Request to upstream should be sent to correct interpolated hostname",
        function()
          it(
            "\nStatus code should be 200 and host should be service_abc_xyz.com",
            function()
              proxy_client = helpers.proxy_client()
              local res =
                assert(
                proxy_client:send(
                  {
                    method = "GET",
                    path = "/gethost",
                    headers = {
                      ["Content-type"] = "application/json",
                      ["place_holder1"] = "abc",
                      ["place_holder2"] = "xyz"
                    },
                    data = {}
                  }
                )
              )
              local body_data = assert(res:read_body())
              body_data = cjson.decode(body_data)
              assert(res.status == 200)
              assert(body_data.headers.host == "service_abc_xyz.com")
            end
          )
        end
      )

      describe(
        "\n ** Request to upstream should be sent to fallback hostname when any of the headers is missing",
        function()
          it(
            "\nStatus code should be 200 and host should be fallback_host",
            function()
              proxy_client = helpers.proxy_client()
              local res =
                assert(
                proxy_client:send(
                  {
                    method = "GET",
                    path = "/gethost",
                    headers = {
                      ["Content-type"] = "application/json",
                      ["place_holder1"] = "abc"
                    },
                    data = {}
                  }
                )
              )
              local body_data = assert(res:read_body())
              body_data = cjson.decode(body_data)
              assert(res.status == 200)
              assert(body_data.headers.host == "service_fallback.com")
            end
          )
        end
      )

      describe(
        "\n ** Request to upstream should be sent to correct hostname as per modulo logic",
        function()
          setup(function()
            local plugin = "host-interpolate-by-header"
            local host = "service_shard_<user_id>.com"
            local fallback_host = ""
            local operation = "modulo"
            local modulo_by = 3
            local headers = {"user_id"}

            update_config(plugin, host, fallback_host, operation, modulo_by, headers)
          end)

          it(
            "\nCheck status code and host in response header",
            function()
              proxy_client = helpers.proxy_client()
              local res =
                assert(
                proxy_client:send(
                  {
                    method = "GET",
                    path = "/gethost",
                    headers = {
                      ["Content-type"] = "application/json",
                      ["user_id"] = 13
                    },
                    data = {}
                  }
                )
              )
              local body_data = assert(res:read_body())
              body_data = cjson.decode(body_data)
              assert(res.status == 200)
              assert(body_data.headers.host == "service_shard_1.com")
            end
          )
        end
      )

      describe(
        "\n ** Request to upstream should fail with error code 422 if placeholder header and fallback host is absent",
        function()
          setup(function()
            local plugin = "host-interpolate-by-header"
            local host = "service_shard_<user_id>.com"
            local fallback_host = ""
            local operation = "none"
            local modulo_by = 1
            local headers = {"user_id"}

            update_config(plugin, host, fallback_host, operation, modulo_by, headers)
          end)

          it(
            "\nStatus code should be 422",
            function()
              proxy_client = helpers.proxy_client()
              local res =
                assert(
                proxy_client:send(
                  {
                    method = "GET",
                    path = "/gethost",
                    headers = {
                      ["Content-type"] = "application/json",
                    },
                    data = {}
                  }
                )
              )
              assert(res.status == 422)
            end
          )
        end
      )

      local host_placeholder = "test-header"

      describe(
        "\n ** Should fail with status 502 as the port provided in config is an invalid port",
        function()
          setup(function()
            local plugin = "host-interpolate-by-header"
            local host = "<"..  host_placeholder ..">"
            local fallback_host = ""
            local operation = "none"
            local modulo_by = 1
            local headers = {host_placeholder}
            local port = 10000

            update_config(plugin, host, fallback_host, operation, modulo_by, headers, port)
          end)

          it(
            "\nStatus code should be 502",
            function()
              proxy_client = helpers.proxy_client()
              local res = assert(proxy_client:send(
                {
                  method = "GET",
                  path = "/gethost",
                  headers = {
                    ["Content-type"] = "application/json",
                    [host_placeholder] = SERVER_IP,
                  },
                  data = {}
                }
              ))
              assert(res.status == 502)
            end
          )
        end
      )

      describe(
        "\n ** Should forward request to upstream at given port",
        function()
          setup(function()
            local plugin = "host-interpolate-by-header"
            local host = "<"..host_placeholder..">"
            local fallback_host = ""
            local operation = "none"
            local modulo_by = 1
            local headers = {host_placeholder}
            local port = SERVER_PORT

            update_config(plugin, host, fallback_host, operation, modulo_by, headers, port)
          end)

          it(
            "\nStatus code should be 200",
            function()
              proxy_client = helpers.proxy_client()
              local res = assert(proxy_client:send(
                {
                  method = "GET",
                  path = "/gethost",
                  headers = {
                    ["Content-type"] = "application/json",
                    [host_placeholder] = SERVER_IP,
                  },
                  data = {}
                }
              ))
              assert(res.status == 200)
            end
          )
        end
      )

      describe(
        "\n ** Should successfully replace place_holder containing a hyphen in the host",
        function()
          setup(function()
            local plugin = "host-interpolate-by-header"
            local host = "service_<".. host_placeholder ..">.com"
            local fallback_host = ""
            local operation = "none"
            local modulo_by = 1
            local headers = {host_placeholder}

            update_config(plugin, host, fallback_host, operation, modulo_by, headers)
          end)

          it(
            "\nStatus code should be 200 and host should be service_abc_xyz.com",
            function()
              proxy_client = helpers.proxy_client()
              local res = assert(proxy_client:send(
                {
                  method = "GET",
                  path = "/gethost",
                  headers = {
                    ["Content-type"] = "application/json",
                    [host_placeholder] = "abc_xyz",
                  },
                  data = {}
                }
              ))
              local body_data = assert(res:read_body())
              body_data = cjson.decode(body_data)
              assert(res.status == 200)
              assert(body_data.headers.host == "service_abc_xyz.com")
            end
          )
        end
      )
    end
  )
end
