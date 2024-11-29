--!strict
--!native
--!optimize 2

--- x: line
--- y: character in line
--- z: position in buffer
export type Location = {
    x: number,
    y: number,
    z: number
}

local function create(position: number, line: number, character: number): Location
    -- TODO: Uncomment and remove "fake" vector
    ---return vector.create(line, character, position)
    return {
        x = line,
        y = character,
        z = position
    }
end

local function line(location: Location)
    return location.x
end

local function position(location: Location)
    return location.z
end

local function character(location: Location)
    return location.y
end

return table.freeze({
    create = create,
    line = line,
    position = position,
    character = character
})