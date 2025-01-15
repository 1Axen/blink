export type Ok<T> = {
    read value: T,
}
export type Error<E> = {
    read error: E
}

export type Result<T, E> = Ok<T> | Error<E>

local function ok<T>(value: T): Ok<T>
    return { value = value }
end

local function err<E>(err: E): Error<E>
    return { error = err }
end

return table.freeze({
    ok = ok,
    err = err
})