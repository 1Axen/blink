--!strict

local lir = require("@lir/types")

type Global<T = any> = lir.Global<T>

local function global<T>(identifier: string): Global<T>
    return {
        __phantom_type = nil :: any,
        
        type = "global",
        identifier = identifier
    }
end

return table.freeze({
    incoming = {
        buffer = global("in_buffer") :: Global<buffer>,
        cursor = global("in_cursor") :: Global<number>,
        length = global("in_length") :: Global<number>,
        unknown = global("in_unknown"):: Global<{unknown}>,
        unknown_cursor = global("in_unknown_cursor") :: Global<number>,
    },

    outgoing = {
        buffer = global("out_buffer") :: Global<buffer>,
        cursor = global("out_cursor") :: Global<number>,
        length = global("out_length") :: Global<number>,
        unknown = global("out_unknown") :: Global<{unknown}>
    },

    events = {
        invocations = global("invocations") :: Global<number>,

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