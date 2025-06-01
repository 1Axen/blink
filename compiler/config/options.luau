local ast = require("@ast/types")

export type Option = {
    kind: ast.ExprKind,
    values: {string | number | boolean}?
}

local options: {[string]: Option} = {
    typescript = { kind = "boolean" :: "boolean" },
    shared_output = { kind = "string" :: "string" },
    client_output = { kind = "string" :: "string" },
    server_output = { kind = "string" :: "string" },

    casing = {
        kind = "string" :: "string",
        values = {"PascalCase", "camelCase", "snake_case"},
    },
    
    future_library = { kind = "string" :: "string" },
    promise_library = { kind = "string" :: "string" },
    
    polling = { kind = "boolean" :: "boolean" },
    remote_folder = { kind = "string" :: "string" },
    manual_replication = { kind = "boolean" :: "boolean" },
}

export type FileOptions = {
    -- Ignored
    typescript: boolean?,
    shared_output: string?,
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