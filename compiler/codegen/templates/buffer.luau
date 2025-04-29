--!strict
local in_buffer = buffer.create(64)
local in_cursor = 0
local in_length = 64
local in_unknown: {any} = table.create(16)
local in_unknown_cursor = 1

local out_buffer = buffer.create(64)
local out_cursor = 0
local out_length = 64
local out_unknown: {any} = table.create(16)

type Save = {
    buffer: buffer,
    cursor: number,
    length: number,
    unknown: {any},
    unknown_cursor: number
}

local function advance(bytes: number): number
    local cursor = in_cursor
    in_cursor = (cursor + bytes) :: number
    return cursor
end

local function allocate(bytes: number): number
    local cursor = out_cursor
    local in_use = (cursor + bytes)

    if in_use > out_length then
        while in_use > out_length do
            out_length *= 1.5
        end

        local buf = buffer.create(out_length)
        buffer.copy(buf, 0, out_buffer, 0, cursor)
        out_buffer = buf
    end

    out_cursor = (cursor + bytes) :: number
    return cursor
end

local function create_save(): Save
    return {
        buffer = out_buffer,
        length = out_length,
        cursor = out_cursor,
        unknown = out_unknown,
        unknown_cursor = 0
    }
end

local function update_save(save: Save)
    save.buffer = out_buffer
    save.length = out_length
    save.cursor = out_cursor
    save.unknown = out_unknown
end

local function reset_out()
    out_buffer = buffer.create(64)
    out_cursor = 0
    out_length = 64
    out_unknown = table.create(16)
end

--- Loads a save for writing
local function load_save(save: Save)
    out_buffer = save.buffer
    out_cursor = save.cursor
    out_length = save.length
    out_unknown = save.unknown
end

--- Loads an external buffer for reading
--- Buffer length is read from `buf`
--- `cursor` defaults to `0`
local function load_external_in(buf: buffer, unknown: {any}, cursor: number?)
    in_buffer = buf
    in_cursor = cursor or 0
    in_length = buffer.len(buf)
    in_unknown = table.create(16)
    in_unknown_cursor = 0
end

--- Loads an external buffer for writing
--- Buffer length is read from `buf`
--- `cursor` defaults to `0`
local function load_external_out(buf: buffer, unknown: {any}, cursor: number?)
    out_buffer = buf
    out_cursor = cursor or 0
    out_length = buffer.len(buf)
    out_unknown = table.create(16)
end

--- Loads an external (user provided) buffer for reading
--- Buffer length and cursor must be provided
local function load_external_in_fast(buf: buffer, cursor: number, length: number, unknown: {unknown})
    in_buffer = buf
    in_cursor = cursor
    in_length = length
    in_unknown = unknown
    in_unknown_cursor = table.maxn(unknown)
end

--- Loads an external (user provided) buffer for writing
--- Buffer length and cursor must be provided
local function load_external_out_fast(buf: buffer, cursor: number, length: number, unknown: {unknown})
    out_buffer = buf
    out_cursor = cursor
    out_length = length
    out_unknown = unknown
end

-- TESTING --

export type State = {
    read ["in"]: Save,
    read out: Save
}

local function state(): State
    return {
        ["in"] = {
            length = in_length,
            cursor = in_cursor,
            buffer = in_buffer,
            unknown = in_unknown,
            unknown_cursor = in_unknown_cursor
        },
        ["out"] = {
            length = out_length,
            cursor = out_cursor,
            buffer = out_buffer,
            unknown = out_unknown,
            unknown_cursor = 0
        }
    }
end

return table.freeze({
    state = state,
    advance = advance,
    allocate = allocate
})