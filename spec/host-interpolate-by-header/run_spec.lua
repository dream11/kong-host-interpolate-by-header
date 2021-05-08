local cjson = require "cjson"

local helpers = require "spec.helpers"
local inspect = require "inspect"

for _, strategy in helpers.each_strategy() do
	describe(
		"Testing host-interpolate-by-header plugin working on[#" .. strategy .. "]",
		function()
			local proxy_client
			local bp
			local db
			local mock_host = helpers.mock_upstream_host
			local admin_client  -- internally uses lua-resty-http
			local host_by_header_plugin

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

					host_by_header_plugin = bp.plugins:insert {
						name = "host-interpolate-by-header",
						config = {
							host = "roadster-<PLACE_HOLDER>.com",
							header_name = "contestdb",
							operation = "none",
							arithmetic_operand = 1,
						}
					}

					local fixtures1 = {
						dns_mock = helpers.dns_mock.new()
					}
					fixtures1.dns_mock:SRV {
						name = "roadster-voltdb5.com",
						target = "127.0.0.1",
						port = 15555
					}
					fixtures1.dns_mock:SRV {
						name = "roadster-2.com",
						target = "127.0.0.1",
						port = 15555
					}
					fixtures1.dns_mock:SRV {
						name = "roadster-50.com",
						target = "127.0.0.1",
						port = 15555
					}
					fixtures1.dns_mock:SRV {
						name = "roadster-4.com",
						target = "127.0.0.1",
						port = 15555
					}
					fixtures1.dns_mock:SRV {
						name = "test.com",
						target = "127.0.0.1",
						port = 15555
					}

					assert(
						helpers.start_kong(
							{
								database = strategy,
								plugins = "app-config,host-interpolate-by-header",
								nginx_conf = "/kong/spec/fixtures/custom_plugins/kong/plugins/custom_nginx.template"
							},
							nil,
							nil,
							fixtures1
						)
					)

					admin_client = helpers.admin_client(60000) -- 60000 is timeout for lua-resty-http
					proxy_client = helpers.proxy_client()
				end
			)

			-- before_each(
			-- 	function()
			-- 		proxy_client = helpers.proxy_client()
			-- 	end
			-- )

			-- after_each(
			-- 	function()
			-- 		proxy_client:close()
			-- 	end
			-- )

			teardown(
				function()
					admin_client:close()
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
									["host"] = "test.com",
									["Content-type"] = "application/json"
								}
							}
						)
					)

					it(
						"\nRequest to upstream should be sent to original hostname",
						function()
							local proxied_host = res.headers["incoming-host"]
							assert(res.status == 200)
							assert(proxied_host == "test.com")
						end
					)
				end
			)

			describe(
				"Request should have placeholder in host specified",
				function()
					admin_client = helpers.admin_client(60000)
					local url = "/plugins/" .. host_by_header_plugin["id"]
					local admin_res = admin_client:patch(
						url,
						{
							headers = {
								["Content-Type"] = "application/json"
							},
							body = {
								name = "host-interpolate-by-header",
								config = {
									host = "roadster-<PLACE_HOLDER>.com",
									header_name = "contestdb",
									operation = "none",
									arithmetic_operand = 1,
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
									["host"] = "test.com",
									["Content-type"] = "application/json",
									["contestdb"] = "voltdb5",
								}
							}
						)
					)
					it(
						"\nRequest to upstream should be sent to correct hostname",
						function()
							local proxied_host = res.headers["incoming-host"]

							assert(res.status == 200)
							assert(proxied_host == "roadster-voltdb5.com")
						end
					)
				end
			)

			describe(
				"Request should have placeholder with correct addition",
				function()
					admin_client = helpers.admin_client(60000)
					local url = "/plugins/" .. host_by_header_plugin["id"]
					local admin_res = admin_client:patch(
						url,
						{
							headers = {
								["Content-Type"] = "application/json"
							},
							body = {
								name = "host-interpolate-by-header",
								config = {
									host = "roadster-<PLACE_HOLDER>.com",
									header_name = "contestdb",
									operation = "add",
									arithmetic_operand = 1,
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
									["host"] = "test.com",
									["Content-type"] = "application/json",
									["contestdb"] = "1",
								}
							}
						)
					)
					it(
						"\nRequest to upstream should be sent to correct hostname",
						function()
							local proxied_host = res.headers["incoming-host"]
							assert(res.status == 200)
							assert(proxied_host == "roadster-2.com")
						end
					)
				end
			)

			describe(
				"Request should have placeholder with correct multiplication",
				function()
					admin_client = helpers.admin_client(60000)
					local url = "/plugins/" .. host_by_header_plugin["id"]
					local admin_res = admin_client:patch(
						url,
						{
							headers = {
								["Content-Type"] = "application/json"
							},
							body = {
								name = "host-interpolate-by-header",
								config = {
									host = "roadster-<PLACE_HOLDER>.com",
									header_name = "contestdb",
									operation = "multiply",
									arithmetic_operand = 10,
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
									["host"] = "test.com",
									["Content-type"] = "application/json",
									["contestdb"] = "5",
								}
							}
						)
					)
					it(
						"\nRequest to upstream should be sent to correct hostname",
						function()
							local proxied_host = res.headers["incoming-host"]
							assert(res.status == 200)
							assert(proxied_host == "roadster-50.com")
						end
					)
				end
			)

			describe(
				"Request should have placeholder with correct modulo",
				function()
					admin_client = helpers.admin_client(60000)
					local url = "/plugins/" .. host_by_header_plugin["id"]
					local admin_res = admin_client:patch(
						url,
						{
							headers = {
								["Content-Type"] = "application/json"
							},
							body = {
								name = "host-interpolate-by-header",
								config = {
									host = "roadster-<PLACE_HOLDER>.com",
									header_name = "auth-userid",
									operation = "modulo",
									arithmetic_operand = 5,
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
									["host"] = "test.com",
									["Content-type"] = "application/json",
									["auth-userid"] = "1234",
								}
							}
						)
					)
					it(
						"\nRequest to upstream should be sent to correct hostname",
						function()
							local proxied_host = res.headers["incoming-host"]
							assert(res.status == 200)
							assert(proxied_host == "roadster-4.com")
						end
					)
				end
			)
		end
	)
end
