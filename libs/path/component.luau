local PARENT = ".."
local SIBLING = "."

export type Component = 
    | { read kind: "normal", read value: string }
    | { read kind: "sibling" } -- "."
    | { read kind: "parent" } -- ".."
    | { read kind: "root", read value: string } -- UNIX root or Windows drive letter
;

local function is_drive_letter(char: string): boolean
    local byte = string.byte(char)
    return (byte >= 65 and byte <= 90) 
        or (byte >= 97 and byte <= 122)
end

local function is_drive(slice: string): boolean
    local letter = string.sub(slice, 1, 1)
    if is_drive_letter(letter) and string.sub(slice, 2, 2) == ":" then
        return true
    end

    return false
end

local function from_slice(slice: string): Component
    if slice == SIBLING then
        return { kind = "sibling" }
    elseif slice == PARENT then
        return { kind = "parent" }
    end

    return { kind = "normal", value = slice }
end

local function from_slices(slices: {string}): {Component}
    local components = table.create(#slices) :: {Component}
    for index, slice in slices do
        --> root
        if index == 1 and slice == "" or is_drive(slice) then
            table.insert(components, {kind = "root", value = slice})
            continue
        elseif index == #slices and slice == "" then
            continue
        end
        
        table.insert(components, from_slice(slice))
    end

    return components
end

local function to_string(self: Component): string
    if self.kind == "normal" then
        return self.value
    elseif self.kind == "root" then
        return self.value
    elseif self.kind == "sibling" then
        return SIBLING
    elseif self.kind == "parent" then
        return PARENT
    end

    error(`Unhandled component kind: "{self.kind}"`)
end

return table.freeze({
    from_slice = from_slice,
    from_slices = from_slices,
    to_string = to_string,
})