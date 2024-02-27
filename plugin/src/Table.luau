local Table = {}

function Table.MergeArrays(a: {any}, b: {any}): {any}
    local Array = table.create(#a + #b)
    
    for _, Element in a do
        table.insert(Array, Element)
    end

    for _, Element in b do
        table.insert(Array, Element)
    end

    return Array
end

function Table.MergeDictionaries(a: {[any]: any}, b: {[any]: any}): {[any]: any}
    local Dictionary = table.clone(a)
    for Key, Value in b do
        if Dictionary[Key] then
            warn(`Key "{Key}" already exists in the first dictionary.`)
            continue
        end

        Dictionary[Key] = Value
    end
    return Dictionary
end

function Table.GetDictionaryKeys(Dictionary: {[any]: any}): {any}
    local Keys = {}
    for Key in Dictionary do
        table.insert(Keys, Key)
    end
    return Keys
end

return Table