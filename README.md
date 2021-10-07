## host-interpolate-by-header
![Continuous Integration](https://github.com/dream11/kong-host-interpolate-by-header/workflows/Continuous%20Integration/badge.svg)
![License](https://img.shields.io/badge/license-MIT-green.svg)

**host-interpolate-by-header** is a plugin for [Kong](https://github.com/Mashape/kong) and is used to dynamically update hostname of upstream service by interpolating url with values of request headers.

## How does it work?

1. The plugin reads all the headers from the incoming request specified in the config as `headers`.
2. It transforms the value of the specified headers as per `operation` in the config.
3. It interpolates hostname of the request with above values before making upstream request.
4. The plugin also interpolates the environment variables in the host but does not apply any operation on it.

Example:

### Operation = none

```lua
conf = {
    host = "service_<zone>_<shard>.com",
    headers = {"zone", "shard"},
    environment_variables = {},
    fallback_host = "service_fallback.com",
    operation = "none",
    modulo_by = 1
}
```

Now a request with headers: <br>
 `zone: us-east-1` <br>
 `shard: z3e67`<br>
on kong will be routed to `host = service_us-east-1_z3e67.com`.

### Operation = modulo

```lua
conf = {
    host = "service_<env>_shard_<user_id>.com",
    headers = {"user_id"},
    environment_variables = {"env"},
    fallback_host = "service_fallback.com",
    operation = "modulo",
    modulo_by = 3
}
```
Let's say the environment variable set in nginx worker is `env: production`. <br>
Now a request with header:
 `user_id: 13` <br>
on kong will be routed to `host = service_production_shard_1.com` as `13 % 3 = 1`.<br/>
Note: Operation is not applied on environment variable interpolation.

### Accepted Header

Header names can contain following characters: `a-z`, `A_Z`, `0-9`,`_(underscore)`,`-(hyphen)`<br>
Header names are case-insensitive and are normalized to lowercase, and dashes (-) can be written as underscores (_); that is, the header X-Custom-Header can also be retrieved as x_custom_header ([kong docs]([https://docs.konghq.com/gateway-oss/2.4.x/pdk/kong.request/#kongrequestget_headersmax_headers), [lua-nginx-module](https://github.com/openresty/lua-nginx-module#ngxreqget_headers).
For example, if plugin config contains `host: <Place_Holder>.com, headers :{PLACE_HOLDER}`, following headers will be correctly picked up and interpolated.
```
place-holder : example
Place_Holder : example
place_holder :example
```
Note: The reverse is not true, that is, if plugin config contains "-" in header and request header contains "_", the header won't be retrieved for interpolation.

## Installation

### luarocks
```bash
luarocks install host-interpolate-by-header
```

### source
Clone this repo and run:

     luarocks make
-------------------------
You also need to set the `KONG_PLUGINS` environment variable:

     export KONG_PLUGINS=host-interpolate-by-header

## Usage

### Parameters

| Parameter | Default  | Required | description |
| --- | --- | --- | --- |
| `host` | hostname-<PLACE_HOLDER>.com | true | Hostname of upstream service |
| `headers` | {} | true | array of headers read from request for interpolation |
| `environment_variables` | {} | true | array of environment varibales for interpolation |
| `operation` | none | false | Operation to apply on header value (none/modulo) |
| `modulo_by` | 1 | false | Number to do modulo by when operation = modulo |
| `fallback_host` | - | false | Route to fallback_host if any of the headers is missing in request else error is returned with status code 422 |

[reference]: https://docs.konghq.com/gateway-oss/2.4.x/pdk/kong.request/#kongrequestget_headersmax_headers),[lua

[reference]: https://github.com/openresty/lua-nginx-module#ngxreqget_headers)).<br>
