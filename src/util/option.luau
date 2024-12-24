export type Some<T> = {
    read value: T,
    read has_value: true, 
}
export type None = {
    read has_value: false
}

export type Option<T> = Some<T> | None

local function some<T>(value: T): Some<T>
    return {
        value = value,
        has_value = true
    }
end

local function none(): None
    return {
        has_value = false
    }
end

return table.freeze({
    some = some,
    none = none
})