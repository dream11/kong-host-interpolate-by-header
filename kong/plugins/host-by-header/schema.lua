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
						header_name = {
							type = "string",
                            len_min = 1,
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
                                "multiply",
                                "add",
                                "modulo",
                            },
                        },
					},
                    {
						arithmetic_operand = {
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
