local INVOCATIONS = table.create(256)

local RELIABLE_QUEUE = table.create(256)
local UNRELIABLE_QUEUE = table.create(256)

local RELIABLE_CONNECTIONS = table.create(256)
local UNRELIABLE_CONNECTIONS = table.create(256)

local function crate_iterator(queue: {any}): () -> (() -> (...any))
    return function()
        local items = #queue
        return function()
            if items <= 0 then
                return nil
            end

            items -= 1
            return (items + 1), unpack(table.remove(queue, 1) :: any)
        end
    end
end