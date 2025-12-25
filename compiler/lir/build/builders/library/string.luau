--!strict

local types = require("@lir/types")

local constant = require("@builders/constant")
local projection = require("@builders/projection")

type Call<T> = types.ProjCall<T>
type RValue<T> = types.RValue<T>
type Constant<T> = types.Constant<T>

local function string_format<T>(template: string, ...: RValue<T>): Call<string>
	return projection.call(constant.from_value("string.format"), { constant.from_value(template), ... } :: any)
end

return table.freeze({
	format = string_format,
})
