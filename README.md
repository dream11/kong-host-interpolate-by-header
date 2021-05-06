## What is host-by-header plugin

**host-by-header** is a plugin for [Kong](https://github.com/Mashape/kong) and is used to prepare and set hostnames of upstream services dynamically.

Usecase 1: Let's say you have a lot of users and you shard your `User` microservice by creating 3 stacks of the same application code. Each stack is supposed to handle 1/3 of total users. This sharding is based on simple modulo logic.

This plugin will help you route the request to the correct stack of User microservice based on a header name of your choice.

Usecase 2: Let's say you rewrite a new microservice and want to shift some of the incoming requests to this new stack based on incoming request header. 

## How does it work

This plugin reads a header say `user_id` from the request header.
As per the configuration, it then applied an operation on the value of this header and prepares a value say `X`. Then it replaces `<PLACE_HOLDER>` in the host with X to prepare the final hostname of upstream service.

Example:
Let's say this is the configuration of our plugin:
```
{
    host: "user_service_shard_<PLACEHOLDER>.com",
    header_name: "user_id",
    operation: "modulo",
    arithmetic_operand: 3
}
```

Now a request with `user_id = 13` in its header arrives on Kong. This plugin will read the user_id = 13 and apply a modulo operation on it with operand 3. The final value will be `13 % 3 = 1`.
Final hostname will be resolved as `user_service_shard_1.com`



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
| `header_name` | | true | header name to read from request headers |
| `operation` | none | false | Operation to apply on header value (add/multiply/modulo) |
| `arithmetic_operand` | 1 | false | Arithmetic operand to use with the operation |



### Running Unit Tests

TBD