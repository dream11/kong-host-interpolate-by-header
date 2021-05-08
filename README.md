## host-interpolate-by-header
[![Build Status](https://travis-ci.com/dream11/kong-host-interpolate-by-header.svg?token=1GXCQ7wuyr9U61oT9yZt&branch=master)](https://travis-ci.com/dream11/kong-host-interpolate-by-header)

**host-interpolate-by-header** is a plugin for [Kong](https://github.com/Mashape/kong) and is used to dynamically update hostname of upstream service by interpolating url with values of request headers.

## How does it work?

- This plugin reads all the headers from the incoming request specified in the conf.
- Transforms the value from headers as per operation in the conf.
- Interpolate hostname of the request with above values before make upstream request.

Example:

### Equals
Conf:
```
{
    host: "service_<zone>_<shard>.com",
    headers: {"zone", "shard"}
}
```

Now a request with headers: <br>
 `zone: us-east-1` <br>
 `shard: z3e67`<br>
on kong will be routed to `host = service_us-east-1_z3e67.com`.

#### Modulo
Conf:
```
{
    host: "service_shard_<user_id>.com",
    headers: {"user_id"},
    operation: "modulo",
    modulo_by: 3
}
```

Now a request with header:<br>
 `user_id: 13` <br>
on kong will be routed to `host = service_shard_1.com` as `13 % 3 = 1`.

## Installation

You also need to set the `KONG_PLUGINS` environment variable

     export KONG_PLUGINS=host-interpolate-by-header

## Usage

### Parameters

| Parameter | Default  | Required | description |
| --- | --- | --- | --- |
| `host` | hostname-<PLACE_HOLDER>.com | true | Hostname of upstream service |
| `headers` | {} | true | header name to read from request headers |
| `operation` | none | false | Operation to apply on header value (none/modulo) |
| `modulo_by` | 1 | false | Number to do modulo by |
| `fallback_host` | - | false | Route to fallback_host if headers are not present in req |



### Running Unit Tests

TBD
