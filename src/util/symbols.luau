--!strict
--!native
--!optimize 2

export type Symbols<T, L> = {
    name: string,
    parent: Symbols<T, L>?,
    values: {[string]: T},
    locals: {[string]: L},
    children: {[string]: Symbols<T, L>},
}

local function create<T, L>(name: string): Symbols<T, L>
    return {
        name = name,
        parent = nil,
        values = {},
        locals = {},
        children = {},
    }
end

local function inner<T, L>(self: Symbols<T, L>, name: string): Symbols<T, L>
    assert(self[name] == nil, `Symbols struct "{self.name}" already has a child "{name}"`)

    local symbols = create(name)
    self.children[name] = symbols
    symbols.parent = self

    return symbols
end

local function set<T, L>(self: Symbols<T, L>, key: string, value: T)
    self.values[key] = value
end

local function search<T, L>(self: Symbols<T, L>, path: string): (T | L)?
    local node: Symbols<T, L>? = self
    local segments = string.split(path, ".")

    while node ~= nil do
        local segment = table.remove(segments, 1)
        if segment == nil then
            break
        end

        local child = node.children[segment]
        if child then
            node = child
            continue
        end

        local loc = node.locals[segment]
        if loc ~= nil then
            return loc
        end

        local value = node.values[segment]
        if value ~= nil then
            return value
        end

        node = node.parent
    end

    return nil
end

local function set_local<T, V>(self: Symbols<T, V>, key: string, value: V)
    self.locals[key] = value
end

local function clear_locals<T, V>(self: Symbols<T, V>, key: string, value: V)
    table.clear(self.locals)
end

return table.freeze({
    create = create,
    inner = inner,
    set = set,
    search = search,

    set_local = set_local,
    clear_locals = clear_locals
})