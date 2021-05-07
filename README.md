## What is host-by-header plugin

**host-by-header** is a plugin for [Kong](https://github.com/Mashape/kong) and is used to dynamically update hostname of upstream service by interpolating url with values of request headers.

## How does it work

- This plugin reads all the headers from the incoming request specified in the conf.
- Transforms the value from headers as per operation in the conf.
- Interpolate hostname of the request with above values before make upstream request.

Example:

# Equals
Conf:
```
{
    host: "service_<zone>_<shard>.com",
    headers: {"zone", "shard"}
}
```

Now a request with headers:
 `zone = us-east-1`
 `shard = z3e67`
on kong will be routed to `host = service_us-east-1_z3e67.com`.

# Modulo
Conf:
```
{
    host: "service_shard_<user_id>.com",
    headers: {"user_id"},
    operation: "modulo",
    modulo_by: 3
}
```

Now a request with header:
 `user_id = 13`
on kong will be routed to `host = service_shard_1.com` as `13 % 3 = 1`.

## Installation

If you're using `luarocks` execute the following:

     luarocks install host-by-header

You also need to set the `KONG_PLUGINS` environment variable

     export KONG_PLUGINS=host-by-header

## Usage

### Parameters

| Parameter | Default  | Required | description |
| --- | --- | --- | --- |
| `host` | hostname-<PLACE_HOLDER>.com | true | Hostname of upstream service |
| `headers` | {} | true | header name to read from request headers |
| `operation` | none | false | Operation to apply on header value (none/modulo) |
| `modulo_by` | 1 | false | Number to do modulo by |



### Running Unit Tests

TBD
