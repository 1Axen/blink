--!strict

local types = require("@lir/types")

type RValue = types.RValue<number>
type Readable<T> = types.Readable<T>
type BinaryAdd<T> = types.BinaryAdd<T>
type BinarySub<T> = types.BinarySub<T>
type BinaryMul<T> = types.BinaryMul<T>
type BinaryDiv<T> = types.BinaryDiv<T>
type BinaryMod<T> = types.BinaryMod<T>
type BinaryPow<T> = types.BinaryPow<T>
type BinaryIDiv<T> = types.BinaryIDiv<T>

local function binary_add(left: Readable<number>, right: Readable<number>): BinaryAdd<number>
	return {
		__readable = nil :: any,

		type = "binary",
		kind = "add",
		left = left :: RValue,
		right = right :: RValue,
	}
end

local function binary_sub(left: Readable<number>, right: Readable<number>): BinarySub<number>
	return {
		__readable = nil :: any,

		type = "binary",
		kind = "sub",
		left = left :: RValue,
		right = right :: RValue,
	}
end

local function binary_mul(left: Readable<number>, right: Readable<number>): BinaryMul<number>
	return {
		__readable = nil :: any,

		type = "binary",
		kind = "mul",
		left = left :: RValue,
		right = right :: RValue,
	}
end

local function binary_div(left: Readable<number>, right: Readable<number>): BinaryDiv<number>
	return {
		__readable = nil :: any,

		type = "binary",
		kind = "div",
		left = left :: RValue,
		right = right :: RValue,
	}
end

local function binary_mod(left: Readable<number>, right: Readable<number>): BinaryMod<number>
	return {
		__readable = nil :: any,

		type = "binary",
		kind = "mod",
		left = left :: RValue,
		right = right :: RValue,
	}
end

local function binary_pow(left: Readable<number>, right: Readable<number>): BinaryPow<number>
	return {
		__readable = nil :: any,

		type = "binary",
		kind = "pow",
		left = left :: RValue,
		right = right :: RValue,
	}
end

local function binary_idiv(left: Readable<number>, right: Readable<number>): BinaryIDiv<number>
	return {
		__readable = nil :: any,

		type = "binary",
		kind = "idiv",
		left = left :: RValue,
		right = right :: RValue,
	}
end

local function binary_add_vec(left: Readable<vector>, right: Readable<number>): BinaryAdd<vector>
	return binary_add(left :: any, right) :: any
end

local function binary_sub_vec(left: Readable<vector>, right: Readable<number>): BinarySub<vector>
	return binary_sub(left :: any, right) :: any
end

local function binary_mul_vec(left: Readable<vector>, right: Readable<number>): BinaryMul<vector>
	return binary_mul(left :: any, right) :: any
end

local function binary_div_vec(left: Readable<vector>, right: Readable<number>): BinaryDiv<vector>
	return binary_div(left :: any, right) :: any
end

local function binary_mod_vec(left: Readable<vector>, right: Readable<number>): BinaryMod<vector>
	return binary_mod(left :: any, right) :: any
end

local function binary_pow_vec(left: Readable<vector>, right: Readable<number>): BinaryPow<vector>
	return binary_pow(left :: any, right) :: any
end

local function binary_idiv_vec(left: Readable<vector>, right: Readable<number>): BinaryIDiv<vector>
	return binary_idiv(left :: any, right) :: any
end

return table.freeze({
	add = binary_add,
	sub = binary_sub,
	mul = binary_mul,
	div = binary_div,
	mod = binary_mod,
	pow = binary_pow,
	idiv = binary_idiv,

	add_vec = binary_add_vec,
	sub_vec = binary_sub_vec,
	mul_vec = binary_mul_vec,
	div_vec = binary_div_vec,
	mod_vec = binary_mod_vec,
	pow_vec = binary_pow_vec,
	idiv_vec = binary_idiv_vec,
})
