local cjson = require "cjson"

local helpers = require "spec.helpers"

for _, strategy in helpers.each_strategy() do
	describe(
		"Testing host-interpolate-by-header plugin working on[#" .. strategy .. "]",
		function()
			local proxy_client
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

					bp.plugins:insert {
						name = "host-interpolate-by-header",
						config = {
							host = "service_<PLACE_HOLDER1>_<PLACE_HOLDER2>.com",
							headers = {"PLACE_HOLDER1", "PLACE_HOLDER2"},
							operation = "none",
							modulo_by = 1,
						}
					}

					local fixtures1 = {
						dns_mock = helpers.dns_mock.new()
					}
					fixtures1.dns_mock:SRV {
						name = "service_abc_xyz.com",
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
							fixtures1
						)
					)
					proxy_client = helpers.proxy_client()
				end
			)

			teardown(
				function()
					proxy_client:close()
					helpers.stop_kong()
					db:truncate()
				end
			)

			describe(
				"Request should go as it is when no such header is present",
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
						"\nRequest to upstream should be sent to original hostname",
						function()
							assert(res.status == 422)
						end
					)
				end
			)

      describe(
				"Upstream host should be interpolated by request headers",
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
						"\nRequest to upstream should be sent to original hostname #test",
						function()
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
