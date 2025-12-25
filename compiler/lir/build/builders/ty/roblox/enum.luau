local attributes = require("@config/attributes")
local ty = require("@ty")
local types = require("@lir/types")

local ty_numeral = require("../luau/numeral")
local ty_string = require("../luau/string")

local condition = require("@builders/condition")
local constant = require("@builders/constant")
local fn = require("@builders/fn")
local library = require("@builders/library")
local projection = require("@builders/projection")

local context = require("@lir/build/context")

local builder_types = require("../builder_types")

type TyBuilder = builder_types.TyBuilder
type ReadProps = builder_types.ReadProps
type WriteProps = builder_types.WriteProps

type Builder = fn.Builder
type Context = context.Context
type Attributes = attributes.Attributes

type LValue<T> = types.LValue<T>
type RValue<T> = types.RValue<T>
type Register<T> = types.RegisterId<T>

local const = constant.from_value

local NAME_FORMAT = ty.string()
local VALUE_FORMAT = ty.numeral("16", "u")

local function to_static_enum_type(ctx: Context, ty: ty.Enum): types.Constant<string>?
	local enum_type = ty.type
	if enum_type == nil then
		return nil
	end

	return projection.index(constant.from_value("Enum"), constant.from_value(enum_type.value))
end

local function validate(props: WriteProps, block: Builder, ty: ty.Enum, at: RValue<EnumItem>)
	local expected_typeof = constant.from_value("EnumItem")
	local typeof_value = library.typeof(at)
	local typeof_condition = condition.not_equals(typeof_value, expected_typeof)
	block:if_single(typeof_condition, function(block: fn.Builder)
		local message = library.string.format("Expected an EnumItem, got %s instead", typeof_value)
		block:call(library.error_rvalue(message))
	end)

	local static_enum_type = to_static_enum_type(props.ctx, ty)
	if static_enum_type == nil then
		return
	end

	local enum_type = projection.index(at :: any, const("EnumType"))
	local enum_type_cond = condition.not_equals(enum_type, static_enum_type)

	block:if_single(enum_type_cond, function(block)
		local message = library.string.format(
			`Expected an enum of type "{static_enum_type.value}", got one of type "%*" instead`,
			enum_type
		)
		block:call(library.error_rvalue(message))
	end)
end

local function build_read(props: ReadProps, block: Builder, ty: ty.Enum, into: LValue<any>?): Register<EnumItem>
	-- Enum[name]
	local name = ty_string.read(props, block, NAME_FORMAT, attributes)
	local enum = projection.field(const("Enum"), name :: any) :: types.ProjField<Enum>

	-- enum:FromValue(value)
	local value = ty_numeral.read(props, block, VALUE_FORMAT, attributes)
	local enum_item =
		projection.namecall(enum :: any, const("FromValue"), { value :: any }) :: types.ProjNamecall<EnumItem>

	return block:store(enum_item, into)
end

local function build_write(props: WriteProps, block: Builder, ty: ty.Enum, value: RValue<EnumItem>): ()
	if props.validate then
		validate(props, block, ty, value)
	end

	-- tostring(enum.EnumType)
	local enum_type = projection.index(value :: any, const("EnumType")) :: types.ProjIndex<Enum>
	local name = block:store(library.tostring(enum_type :: any))
	ty_string.write(props, block, NAME_FORMAT, name)

	-- enum.Value
	local enum_value = block:store(projection.index(value :: any, const("Value")) :: types.ProjIndex<number>)
	ty_numeral.write(props, block, VALUE_FORMAT, enum_value)
end

return table.freeze({
	read = build_read,
	write = build_write,
})
