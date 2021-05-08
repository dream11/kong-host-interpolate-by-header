package = "host-interpolate-by-header"

version = "1.0.0-1"

supported_platforms = {"linux", "macosx"}
source = {
    url = "https://github.com/dream11/kong-plugins"
}

description = {
    summary = "Plugin for routing to a host based on request header"
}

dependencies = {
    "lua >= 5.1"
}

build = {
    type = "builtin",
    modules = {
        ["kong.plugins.host-interpolate-by-header.handler"] = "kong/plugins/handler.lua",
        ["kong.plugins.host-interpolate-by-header.schema"] = "kong/plugins/schema.lua",
    },
}
