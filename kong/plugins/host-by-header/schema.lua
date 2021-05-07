local typedefs = require "kong.db.schema.typedefs"

return {
  name = "host-by-header",
  fields = {
    {consumer = typedefs.no_consumer},
    {protocols = typedefs.protocols_http},
    {
      config = {
        type = "record",
        fields = {
          {
            host = {
              type = "string",
              default = "hostname-<PLACE_HOLDER>.com",
              required = true
            }
          },
          {
            headers = {
              type = "array",
              default = {},
              elements = { type = "string" },
              required = true
            }
          },
          {
            operation = {
              type = "string",
              len_min = 0,
              default = "none",
              one_of = {
                "none",
                "modulo"
              },
            },
          },
          {
            modulo_by = {
              type = "number",
              default = 1
            }
          },
        },
      }
    }
  },
  entity_checks = {
  }
}
