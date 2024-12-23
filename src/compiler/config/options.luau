local ast = require("@compiler/structures/ast")

export type Option = {
    kind: ast.ExprKind,
    values: {any}?
}

local options: {[string]: Option} = {
    casing = {
        kind = "string",
        values = {"PascalCase", "camelCase", "snake_case"} :: any,
    },

    remote_folder = { kind = "string" },

    types_output = { kind = "string" },
    client_output = { kind = "string" },
    server_output = { kind = "string" },
    tooling_output = { kind = "string" },
    future_library = { kind = "string" },
    promise_library = { kind = "string" },

    polling = { kind = "boolean" },
    typescript = { kind = "boolean" },
    write_validations = { kind = "boolean" },
    manual_replication = { kind = "boolean" },
}

return table.freeze(options)