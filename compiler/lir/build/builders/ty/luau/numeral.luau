local attributes = require("@config/attributes")
local lir = require("@lir/types")
local ty = require("@ty/types")

local binary = require("@builders/binary")
local condition = require("@builders/condition")
local constant = require("@builders/constant")
local control = require("@builders/control")
local fn = require("@builders/fn")
local library = require("@builders/library")

local context = require("@lir/build/context")

local panic = require("@util/panic")
local strong_exhaustive_match = require("@util/strong_exhaustive_match")

type function concat_literal_union(left: any, right: any)
	local left_components: { any } = left:components()
	local right_components: { any } = right:components()

	local combined_components = {}
	for _, left_singleton in left_components do
		for _, right_singleton in right_components do
			local combined_singleton = types.singleton(left_singleton:value() .. right_singleton:value())
			table.insert(combined_components, combined_singleton)
		end
	end

	return types.unionof(table.unpack(combined_components))
end

local builder_types = require("../types")

type TyBuilder = builder_types.TyBuilder
type ReadProps = builder_types.ReadProps
type WriteProps = builder_types.WriteProps

type Builder = fn.Builder
type Context = context.Context
type Attributes = attributes.Attributes

type LValue<T> = lir.LValue<T>
type RValue<T> = lir.RValue<T>
type Register<T> = lir.RegisterId<T>

type Call<T> = lir.ProjCall<T>
type Advance = lir.CtrlAdvance<number>
type Allocate = lir.CtrlAllocate<number>

type ReadCtor = (cursor: Advance) -> Call<number>
type WriteCtor = (cursor: Register<number>, value: RValue<number>) -> Call<nil>

local BYTE = constant.from_value(2 ^ 8)
local SHORT = constant.from_value(2 ^ 16)

local function size_to_byte_size(size: ty.NumSize): number
	if size == "8" then
		return 1
	elseif size == "16" then
		return 2
	elseif size == "24" then
		return 3
	elseif size == "32" then
		return 4
	elseif size == "48" then
		return 6
	elseif size == "64" then
		return 8
	else
		return strong_exhaustive_match(size)
	end
end

local function methods_from_numeral(ty: ty.Numeral): { read: ReadCtor, write: WriteCtor }
	local index = (ty.format .. ty.size)
	local methods = (library.buffer :: any)[index]
	if methods == nil then
		return panic(`No buffer ctor methods exist for numeral kind: "{index}"`)
	end

	return methods
end

local function read_24()
	local lower_offset = control.advance(constant.from_value(1))
	local lower = library.buffer.u8.read(lower_offset)

	local upper_offset = control.advance(constant.from_value(2))
	local upper = binary.mul(library.buffer.u16.read(upper_offset), BYTE)

	return binary.add(lower, upper)
end

local function read_u24(block: Builder, into: LValue<any>?): Register<number>
	return block:store(read_24(), into)
end

local function read_i24(block: Builder, into: LValue<any>?): Register<number>
	local value = read_24()
	value = binary.sub(value, constant.from_value(2 ^ 23))
	return block:store(value, into)
end

local function write_u24(block: Builder, value: RValue<number>)
	local lower_offset = block:store(control.allocate(constant.from_value(1)))
	block:call_lib(library.buffer.u8.write(lower_offset, value))

	local upper_offset = block:store(control.allocate(constant.from_value(2)))
	block:call_lib(library.buffer.u16.write(upper_offset, binary.idiv(value, BYTE)))
end

local function write_i24(block: Builder, value: RValue<number>)
	local register = block:store(binary.add(value, constant.from_value(2 ^ 23)))
	write_u24(block, register :: RValue<number>)
end

local function read_48()
	local lower_offset = control.advance(constant.from_value(2))
	local lower = library.buffer.u16.read(lower_offset)

	local upper_offset = control.advance(constant.from_value(4))
	local upper = binary.mul(library.buffer.u32.read(upper_offset), SHORT)

	return binary.add(lower, upper)
end

local function read_u48(block: Builder, into: LValue<any>?): Register<number>
	return block:store(read_48(), into)
end

local function write_u48(block: Builder, value: RValue<number>)
	local lower_offset = block:store(control.allocate(constant.from_value(2)))
	block:call_lib(library.buffer.u16.write(lower_offset, value))

	local upper_offset = block:store(control.allocate(constant.from_value(4)))
	block:call_lib(library.buffer.u32.write(upper_offset, binary.idiv(value, SHORT)))
end

local function read_i48(block: Builder, into: LValue<any>?): Register<number>
	local value = read_48()
	value = binary.sub(value, constant.from_value(2 ^ 47))
	return block:store(value, into)
end

local function write_i48(block: Builder, value: RValue<number>)
	local register = block:store(binary.add(value, constant.from_value(2 ^ 47)))
	write_u48(block, register :: RValue<number>)
end

local function read_f16(block: Builder, into: LValue<any>?): Register<number>
	block:remark("f16 is not implemented")
	return block:store(constant.zero, into)
end

local function write_f16(block: Builder, value: RValue<number>)
	block:remark("f16 is not implemented")
end

local function validate(block: Builder, ty: ty.Numeral, value: RValue<number>)
	local bounds = ty.bounds
	if bounds == nil then
		return
	end

	local lower = condition.less_than(value, constant.from_value(bounds.min))
	local upper = condition.greater_than(value, constant.from_value(bounds.max))

	block:if_branch(lower, function(block)
		block:call_lib(library.error(`Expected number to be greater than or equal to {bounds.min}`))
	end)

	block:if_branch(upper, function(block)
		block:call_lib(library.error(`Expected number to be less than or equal to {bounds.max}`))
	end)
end

local function build_read(props: ReadProps, block: Builder, ty: ty.Numeral, into: LValue<any>?): Register<number>
	local format: concat_literal_union<ty.NumFormat, ty.NumSize> = (ty.format .. ty.size) :: any
	if format == "u24" then
		return read_u24(block)
	elseif format == "i24" then
		return read_i24(block)
	elseif format == "u48" then
		return read_u48(block)
	elseif format == "i48" then
		return read_i48(block)
	elseif format == "f16" then
		return read_f16(block)
	end

	local size = size_to_byte_size(ty.size)
	local bytes = constant.from_value(size)

	local cursor = control.advance(bytes)
	local methods = methods_from_numeral(ty)

	local register = block:store(methods.read(cursor), into)
	validate(block, ty, register)

	return register
end

local function build_write(props: WriteProps, block: Builder, ty: ty.Numeral, value: RValue<number>)
	if props.validate then
		validate(block, ty, value)
	end

	local format: concat_literal_union<ty.NumFormat, ty.NumSize> = (ty.format .. ty.size) :: any
	if format == "u24" then
		return write_u24(block, value)
	elseif format == "i24" then
		return write_i24(block, value)
	elseif format == "u48" then
		return write_u48(block, value)
	elseif format == "i48" then
		return write_i48(block, value)
	elseif format == "f16" then
		return write_f16(block, value)
	end

	local size = size_to_byte_size(ty.size)
	local bytes = constant.from_value(size)
	local methods = methods_from_numeral(ty)

	local cursor = block:store(control.allocate(bytes))
	block:call_lib(methods.write(cursor, value))
end

return table.freeze({
	read = build_read,
	write = build_write,

	u8 = ty.numeral("8", "u"),
	u16 = ty.numeral("16", "u"),
	u24 = ty.numeral("24", "u"),
	u32 = ty.numeral("32", "u"),
	u48 = ty.numeral("48", "u"),

	i8 = ty.numeral("8", "i"),
	i16 = ty.numeral("16", "i"),
	i24 = ty.numeral("24", "i"),
	i32 = ty.numeral("32", "i"),
	i48 = ty.numeral("48", "i"),

	f16 = ty.numeral("16", "f"),
	f32 = ty.numeral("32", "f"),
	f64 = ty.numeral("64", "f"),
})
