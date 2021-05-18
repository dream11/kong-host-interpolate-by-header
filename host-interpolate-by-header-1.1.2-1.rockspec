package = "host-interpolate-by-header"

version = "1.1.2-1"

supported_platforms = {"linux", "macosx"}
source = {
    url = "git://github.com/chirag-d11/kong-host-interpolate-by-header",
    tag = "v1.1.2"
}

description = {
    summary = "Kong plugin for routing to a host based on request header",
    homepage = "https://github.com/dream11/kong-host-interpolate-by-header/tree/luarocks-upload",
    license = "MIT",
    maintainer = "Dream11 <tech@dream11.com>"
}

dependencies = {
    "lua >= 5.1"
}

build = {
    type = "builtin",
    modules = {
        ["kong.plugins.host-interpolate-by-header.handler"] = "kong/plugins/host-interpolate-by-header/handler.lua",
        ["kong.plugins.host-interpolate-by-header.schema"] = "kong/plugins/host-interpolate-by-header/schema.lua",
    },
}
