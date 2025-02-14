local invocations = table.create(256)

local reliable_queue = table.create(256)
local unreliable_queue = table.create(256)

local reliable_connections = table.create(256)
local unreliable_connections = table.create(256)

local function create_iterator(queue: {any}): () -> (() -> (...any))
    return function()
        local index = #queue
        return function()
            if index <= 0 then
                return nil
            end

            index -= 1
            return (index + 1), unpack(table.remove(queue, 1) :: any)
        end
    end
end