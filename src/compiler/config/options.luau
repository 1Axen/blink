local ast = require("@compiler/structures/ast")

export type Option = {
    kind: ast.ExprKind,
    values: {any}?
}

local options: {[string]: Option} = {
    output = { kind = "string" },
    typescript = { kind = "boolean" },
    client_output = { kind = "string" },
    server_output = { kind = "string" },

    casing = {
        kind = "string",
        values = {"PascalCase", "camelCase", "snake_case"},
    },
    
    future_library = { kind = "string" },
    promise_library = { kind = "string" },
    
    polling = { kind = "boolean" },
    remote_folder = { kind = "string" },
    manual_replication = { kind = "boolean" },
}

export type FileOptions = {
    -- Ignored
    output: string?,
    typescript: boolean?,
    client_output: string?,
    server_output: string?,

    --- The casing of the user facing interface
    --- Defaults to "snake_case"
    casing: "PascalCase" | "camelCase" | "snake_case",

    --- Path from the output files to the future library
    future_library: string?,
    --- Path from the output files to the promise library
    promise_library: string?,

    --- Default poll value of events
    --- Defaults to `false`
    polling: boolean?,
    --- The name of the folder containing the remote events
    remote_folder: string?,
    --- Manual event loop control
    manual_replication: boolean?
}

return table.freeze(options)