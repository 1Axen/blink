local runtime = require("@util/runtime")
local component = require("@self/component")

local CWD: string;
local RUNTIME = runtime()
local SEPARATOR = "/"

if RUNTIME == "Lune" then
    local process = require("@lune/process")
    CWD = process.cwd
elseif RUNTIME == "ROBLOX" then
    CWD = ""
end

type Component = component.Component
type Components = {Component}

export type Path = {
    read components: {Component}
}

local function rsplit_file_name(file_name: string): (string, string?)
    local reversed = string.reverse(file_name)
    local reverse_index = string.find(reversed, ".", 1, true)

    local length = #file_name
    local index = reverse_index and (1 + length - reverse_index)

    if index == nil then
        return file_name, nil
    end

    local after = string.sub(file_name, index + 1)
    local before = string.sub(file_name, 1, index - 1)

    if before == "" then
        return file_name, nil
    end

    return before, after
end

--- returns an array of the path's components
local function string_to_components(path: string): Components
    --- replaces windows "\" with unix "/"
    path = (string.gsub(path, "\\", SEPARATOR))

    local slices = string.split(path, SEPARATOR)

    -- remove the blank space inserted when the last character is the separator
    local elements = #slices
    if slices[elements] == "" then
        slices[elements] = nil
    end

    return component.from_slices(slices)
end

local function from_path(path: Path): Path
    local components = table.clone(path.components)
    return {
        components = components
    }
end

local function from_string(str: string): Path
    local components = string_to_components(str)
    return { 
        components = components 
    }
end

local CWD_PATH = from_string(CWD)

--- returns the last component of the path
local function get_back(self: Path): Component
    return self.components[#self.components]
end

--- returns the first component of the path
local function get_front(self: Path): Component
    return self.components[1]
end

local function get_file_name(self: Path): string?
    local back = get_back(self)
    if back == nil then
        return nil
    end

    if back.kind ~= "normal" then
        return nil
    end

    return back.value
end

local function get_file_stem(self: Path): string?
    local file_name = get_file_name(self)
    if file_name == nil then
        return nil
    end

    local before, after = rsplit_file_name(file_name)
    return before or after
end

--- Returns the file extension
local function get_file_extension(self: Path): string?
    local file_name = get_file_name(self)
    if file_name == nil then
        return nil
    end

    local before, after = rsplit_file_name(file_name)
    return before and after
end

local function pop(self: Path, index: number): (Path, string?)
    local path = from_path(self)
    local element = table.remove(path.components, index)
    return path, element and component.to_string(element) or nil
end

local function join(left: Path, right: Path): Path
    local path = from_path(left)
    table.move(right.components, 1, #right.components, #path.components + 1, path.components)
    return path
end

local function parent(self: Path): Path?
    local components = self.components
    if #components <= 1 then
        return nil
    end

    local path = from_path(self)
    path.components[#path.components] = nil
    
    return path
end

local function starts_with(self: Path, slice: string): boolean
    local front = get_front(self)
    if front == nil then
        return false
    end

    local value = component.to_string(front)
    return (string.sub(value, 1, #slice) == slice)
end

local function strip_file_name(self: Path): Path
    if get_file_name(self) == nil then
        return self 
    end

    local stripped = from_path(self)
    local components = stripped.components
    table.remove(components, #components)
    
    return stripped
end

local function with_file_name(self: Path, stem: string, extension: string): Path
    local new_path: Path;
    if get_file_name(self) ~= nil then
        new_path = strip_file_name(self)
    else
        new_path = from_path(self)
    end

    table.insert(new_path.components, component.from_slice(`{stem}.{extension}`))
    return new_path
end

local function append_file_name(self: Path, stem: string, extension: string): Path
    local new_path = from_path(self)
    table.insert(new_path.components, component.from_slice(`{stem}.{extension}`))
    return new_path
end

local function is_absolute_path(self: Path): boolean
    local first = get_front(self)
    if first == nil then
        return false
    end

    return (first.kind == "root")
end

local function is_relative_path(self: Path): boolean
    return (is_absolute_path(self) == false)
end

--- converts the path to a string
local function to_string(self: Path): string
    local slices = table.create(#self.components) :: {string}
    for index, path_component in self.components do
        slices[index] = component.to_string(path_component)
    end

    return table.concat(slices, SEPARATOR)
end

local function to_absolute_path(self: Path): Path
    if is_absolute_path(self) then
        return self
    end

    return join(CWD_PATH, self)
end

return table.freeze({
    from_string = from_string,

    file_name = get_file_name,
    file_stem = get_file_stem,
    file_extension = get_file_extension,

    pop = pop,
    join = join,
    parent = parent,
    
    starts_with = starts_with,

    with_file_name = with_file_name,
    strip_file_name = strip_file_name,
    append_file_name = append_file_name,

    is_relative_path = is_relative_path,
    is_absolute_path = is_absolute_path,

    to_string = to_string,
    to_absolute_path = to_absolute_path,
})