--!strict

local lir = require("@structures/lir")

type Global = lir.Global

local function global(identifier: string): Global
    return {
        type = "global",
        identifier = identifier
    }
end

return table.freeze({
    incoming = {
        buffer = global("in_buffer"),
        cursor = global("in_cursor"),
        length = global("in_length"),
        unknown = global("in_unknown"),
        unknown_cursor = global("in_unknown_cursor"),
    },

    outgoing = {
        buffer = global("out_buffer"),
        cursor = global("out_cursor"),
        length = global("out_length"),
        unknown = global("out_unknown")
    },

    events = {
        invocations = global("invocations"),

        queues = {
            reliable = global("reliable_queue"),
            unreliable = global("unreliable_queue"),
        },

        connections = {
            reliable = global("reliable_connections"),
            unreliable = global("unreliable_connections")
        },
        
        instances = {
            folder = global("EVENTS_FOLDER"),
            reliable = global("RELIABLE_EVENT"),
        },
    }
})