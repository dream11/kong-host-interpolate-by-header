local cjson = require "cjson"
local helpers = require "spec.helpers"

for _, strategy in helpers.each_strategy() do
  describe(
    "Testing host-interpolate-by-header plugin working on[#" .. strategy .. "]",
    function()
      local proxy_client, admin_client, host_interpolate_by_header
      local bp
      local db

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
                    port = 15555,
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
            target = "127.0.0.1",
            port = 15555
          }
          fixtures.dns_mock:SRV {
            name = "service_fallback.com",
            target = "127.0.0.1",
            port = 15555
          }
          fixtures.dns_mock:SRV {
            name = "service_shard_1.com",
            target = "127.0.0.1",
            port = 15555
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
        "\n ** Request should go to fallback host when no such header is present",
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

          it(
            "\nStatus code should be 200 and host should be fallback_host",
            function()
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

          it(
            "\nStatus code should be 200 and host should be service_abc_xyz.com",
            function()
              local body_data = assert(res:read_body())
              body_data = cjson.decode(body_data)
              assert(res.status == 200)
              assert(body_data.headers.host == "service_abc_xyz.com")
            end
          )
        end
      )

      describe(
        "\n ** Request to upstream should be sent to fallback hostname when any of the header is missing",
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

          it(
            "\nStatus code should be 200 and host should be fallback_host",
            function()
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
          -- Update plugin config via admin_client
          admin_client = helpers.admin_client(60000)
          local url = "/plugins/" .. host_interpolate_by_header["id"]
          admin_client:patch(
            url,
            {
              headers = {
                ["Content-Type"] = "application/json"
              },
              body = {
                name = "host-interpolate-by-header",
                config = {
                  host = "service_shard_<user_id>.com",
                  fallback_host = "",
                  headers = {"user_id"},
                  operation = "modulo",
                  modulo_by = 3,
                },
                enabled = true,
                consumer = nil
              }
            }
          )

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

          it(
            "\nCheck status code and host in response header",
            function()
              local body_data = assert(res:read_body())
              body_data = cjson.decode(body_data)
              assert(res.status == 200)
              assert(body_data.headers.host == "service_shard_1.com")
            end
          )
        end
      )

      describe(
        "\n ** Request to upstream should fail with error code 422",
        function()
          -- Update plugin config via admin_client
          admin_client = helpers.admin_client(60000)
          local url = "/plugins/" .. host_interpolate_by_header["id"]
          assert(admin_client:patch(
            url,
            {
              headers = {
                ["Content-Type"] = "application/json"
              },
              body = {
                name = "host-interpolate-by-header",
                config = {
                  host = "service_shard_<user_id>.com",
                  fallback_host = "",
                  headers = {"user_id"},
                  operation = "none",
                  modulo_by = 1,
                },
                enabled = true,
                consumer = nil
              }
            }
          ))

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

          it(
            "\nStatus code should be 422",
            function()
              assert(res.status == 422)
            end
          )
        end
      )

      describe(
        "\n ** Should forward request to upstream at given port",
        function()
          -- Update plugin config via admin_client
          admin_client = helpers.admin_client(60000)
          local url = "/plugins/" .. host_interpolate_by_header["id"]
          assert(admin_client:patch(
            url,
            {
              headers = {
                ["Content-Type"] = "application/json"
              },
              body = {
                name = "host-interpolate-by-header",
                config = {
                  host = "<test-header>",
                  fallback_host = "",
                  headers = {"test-header"},
                  port = 15555,
                  operation = "none",
                  modulo_by = 1,
                },
                enabled = true,
                consumer = nil
              }
            }
          ))

          proxy_client = helpers.proxy_client()
          local res = assert(proxy_client:send(
            {
              method = "GET",
              path = "/gethost",
              headers = {
                ["Content-type"] = "application/json",
                ["test-header"] = "127.0.0.1",
              },
              data = {}
            }
          ))

          it(
            "\nStatus code should be 200",
            function()
              assert(res.status == 200)
            end
          )
        end
      )

      describe(
        "\n ** Should fail with status 502 as the port provided in config is an invalid port",
        function()
          -- Update plugin config via admin_client
          admin_client = helpers.admin_client(60000)
          local url = "/plugins/" .. host_interpolate_by_header["id"]
          assert(admin_client:patch(
            url,
            {
              headers = {
                ["Content-Type"] = "application/json"
              },
              body = {
                name = "host-interpolate-by-header",
                config = {
                  host = "<test-header>",
                  fallback_host = "",
                  headers = {"test-header"},
                  port = 10000,
                  operation = "none",
                  modulo_by = 1,
                },
                enabled = true,
                consumer = nil
              }
            }
          ))

          proxy_client = helpers.proxy_client()
          local res = assert(proxy_client:send(
            {
              method = "GET",
              path = "/gethost",
              headers = {
                ["Content-type"] = "application/json",
                ["test-header"] = "127.0.0.1",
              },
              data = {}
            }
          ))

          it(
            "\nStatus code should be 502",
            function()
              assert(res.status == 502)
            end
          )
        end
      )

      describe(
        "\n ** Should replace place_holder with a hyphen in the host",
        function()
          -- Update plugin config via admin_client
          admin_client = helpers.admin_client(60000)
          local url = "/plugins/" .. host_interpolate_by_header["id"]
          assert(admin_client:patch(
            url,
            {
              headers = {
                ["Content-Type"] = "application/json"
              },
              body = {
                name = "host-interpolate-by-header",
                config = {
                  host = "service_<test-header>.com",
                  fallback_host = "",
                  headers = {"test-header"},
                  operation = "none",
                  modulo_by = 1,
                },
                enabled = true,
                consumer = nil
              }
            }
          ))

          proxy_client = helpers.proxy_client()
          local res = assert(proxy_client:send(
            {
              method = "GET",
              path = "/gethost",
              headers = {
                ["Content-type"] = "application/json",
                ["test-header"] = "abc_xyz",
              },
              data = {}
            }
          ))

          it(
            "\nStatus code should be 200",
            function()
              assert(res.status == 200)
            end
          )
        end
      )
    end
  )
end
