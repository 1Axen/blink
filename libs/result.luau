export type Ok<T> = {
	read value: T,
	read error: nil,
}
export type Error<E> = {
	read value: nil,
	read error: E,
}

export type Result<T, E> = Ok<T> | Error<E>

local function ok<T>(value: T): Ok<T>
	return { value = value, error = nil }
end

local function err<E>(err: E): Error<E>
	return { value = nil, error = err }
end

return table.freeze({
	ok = ok,
	err = err,
})
