local panic = require("@util/panic")

export type Some<T> = {
	read value: T,
	read has_value: true,
}

export type None = {
	read has_value: false,
}

export type Option<T> = Some<T> | None

local function some<T>(value: T): Some<T>
	return {
		value = value,
		has_value = true,
	}
end

local function none(): None
	return {
		has_value = false,
	}
end

--- Returns the contained `Some` value, panics if the `self` value is `None`.
local function unwrap<T>(self: Option<T>): T
	if self.has_value == false then
		return panic(`Called "option.unwrap" on a "None" value`)
	end

	return self.value
end

--- Returns the contained `Some` value or a provided default.
local function unwrap_or<T>(self: Option<T>, default: T): T
	if self.has_value then
		return self.value
	end

	return default
end

return table.freeze({
	some = some,
	none = none,
	unwrap = unwrap,
	unwrap_or = unwrap_or,
})
