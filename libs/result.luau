export type Ok<T> = {
	read ok: true,
	read value: T,
}
export type Error<E> = {
	read ok: false,
	read error: E,
}

export type Result<T, E> = Ok<T> | Error<E>

local function ok<T>(value: T): Ok<T>
	return { ok = true, value = value }
end

local function err<E>(err: E): Error<E>
	return { ok = false, error = err }
end

return table.freeze({
	ok = ok,
	err = err,
})
