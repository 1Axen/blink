--!strict

local types = require("@lir/types")

type RValue<T> = types.RValue<T>
type BinaryAdd<T> = types.BinaryAdd<T>
type BinarySub<T> = types.BinarySub<T>
type BinaryMul<T> = types.BinaryMul<T>
type BinaryDiv<T> = types.BinaryDiv<T>
type BinaryMod<T> = types.BinaryMod<T>
type BinaryPow<T> = types.BinaryPow<T>
type BinaryIDiv<T> = types.BinaryIDiv<T>

local function binary_add(left: RValue<number>, right: RValue<number>): BinaryAdd<number>
	return {
		__phantom_type = nil :: any,

		type = "binary",
		kind = "add",
		left = left,
		right = right,
	}
end

local function binary_sub(left: RValue<number>, right: RValue<number>): BinarySub<number>
	return {
		__phantom_type = nil :: any,

		type = "binary",
		kind = "sub",
		left = left,
		right = right,
	}
end

local function binary_mul(left: RValue<number>, right: RValue<number>): BinaryMul<number>
	return {
		__phantom_type = nil :: any,

		type = "binary",
		kind = "mul",
		left = left,
		right = right,
	}
end

local function binary_div(left: RValue<number>, right: RValue<number>): BinaryDiv<number>
	return {
		__phantom_type = nil :: any,

		type = "binary",
		kind = "div",
		left = left,
		right = right,
	}
end

local function binary_mod(left: RValue<number>, right: RValue<number>): BinaryMod<number>
	return {
		__phantom_type = nil :: any,

		type = "binary",
		kind = "mod",
		left = left,
		right = right,
	}
end

local function binary_pow(left: RValue<number>, right: RValue<number>): BinaryPow<number>
	return {
		__phantom_type = nil :: any,

		type = "binary",
		kind = "pow",
		left = left,
		right = right,
	}
end

local function binary_idiv(left: RValue<number>, right: RValue<number>): BinaryIDiv<number>
	return {
		__phantom_type = nil :: any,

		type = "binary",
		kind = "idiv",
		left = left,
		right = right,
	}
end

local function binary_add_vec(left: RValue<vector>, right: RValue<number>): BinaryAdd<vector>
	return binary_add(left :: any, right) :: any
end

local function binary_sub_vec(left: RValue<vector>, right: RValue<number>): BinarySub<vector>
	return binary_sub(left :: any, right) :: any
end

local function binary_mul_vec(left: RValue<vector>, right: RValue<number>): BinaryMul<vector>
	return binary_mul(left :: any, right) :: any
end

local function binary_div_vec(left: RValue<vector>, right: RValue<number>): BinaryDiv<vector>
	return binary_div(left :: any, right) :: any
end

local function binary_mod_vec(left: RValue<vector>, right: RValue<number>): BinaryMod<vector>
	return binary_mod(left :: any, right) :: any
end

local function binary_pow_vec(left: RValue<vector>, right: RValue<number>): BinaryPow<vector>
	return binary_pow(left :: any, right) :: any
end

local function binary_idiv_vec(left: RValue<vector>, right: RValue<number>): BinaryIDiv<vector>
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
