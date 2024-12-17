--!strict
--!native
--!optimize 2

export type Symbols<T> = {
    name: string,
    parent: Symbols<T>?,
    values: {[string]: T},
    children: {[string]: Symbols<T>},
}

local function create<T>(name: string): Symbols<T>
    return {
        name = name,
        parent = nil :: any,
        values = {},
        children = {}
    }
end

local function inner<T>(self: Symbols<T>, name: string): Symbols<T>
    assert(self.children[name] == nil, `Symbols struct "{self.name}" already has a child "{name}"`)

    local symbols = create(name)
    self.children[name] = symbols
    symbols.parent = self

    return symbols
end

local function set<T>(self: Symbols<T>, key: string, value: T)
    self.values[key] = value
end

local function search<T>(self: Symbols<T>, path: {string}): T?
    local node: Symbols<T>? = self
    local segments = table.clone(path)

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

        local value = node.values[segment]
        if value ~= nil then
            return value
        end

        node = node.parent
    end

    return nil
end

return table.freeze({
    create = create,
    inner = inner,
    set = set,
    search = search
})