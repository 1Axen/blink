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

type Writeable<T> = types.Writeable<T>
type Readable<T> = types.Readable<T>
type Register<T> = types.RegisterId<T>

const ENUM_GLOBAL = constant.from_value("Enum")

const ITEM_TYPE = constant.from_value("EnumItem")
const TYPE_FIELD = constant.from_value("EnumType")
const VALUE_FIELD = constant.from_value("Value")
const FROM_VALUE_METHOD = constant.from_value("FromValue")

local NAME_FORMAT = ty.string()
local VALUE_FORMAT = ty.numeral(nil, "16", "u")

local function to_enum_type(ctx: Context, ty: ty.Enum): Readable<Enum>?
	local type_name = ty.type
	if type_name == nil then
		return nil
	end
	return projection.field(ENUM_GLOBAL, constant.from_ty(type_name))
end

local function validate(props: WriteProps, block: Builder, ty: ty.Enum, value: Readable<EnumItem>)
	local typeof_value = library.typeof(value)
	block:if_single(condition.not_equals(typeof_value, ITEM_TYPE), function(block: fn.Builder)
		local message = library.string.format("Expected an EnumItem, got %s instead", typeof_value)
		block:call(library.error_rvalue(message))
	end)

	local expected_enum_type = to_enum_type(props.ctx, ty)
	if expected_enum_type == nil then
		return
	end

	local enum_type = projection.index(value, TYPE_FIELD) :: types.ProjIndex<Enum>
	block:if_single(condition.not_equals(enum_type, expected_enum_type), function(block)
		local message = library.string.format(
			`Expected an enum of type "%*", got one of type "%*" instead`,
			expected_enum_type,
			enum_type
		)
		block:call(library.error_rvalue(message))
	end)
end

local function build_read(props: ReadProps, block: Builder, ty: ty.Enum, into: Writeable<any>?): Register<EnumItem>
	-- Enum[name]
	local name = ty_string.read(props, block, NAME_FORMAT, attributes)
	local enum = projection.field(ENUM_GLOBAL, name) :: types.ProjIndex<Enum>

	-- enum:FromValue(value)
	local value = ty_numeral.read(props, block, VALUE_FORMAT, attributes)
	local enum_item = projection.namecall(enum, FROM_VALUE_METHOD, { value }) :: types.ProjNamecall<EnumItem>

	return block:store(enum_item, into)
end

local function build_write(props: WriteProps, block: Builder, ty: ty.Enum, value: Readable<EnumItem>): ()
	if props.validate then
		validate(props, block, ty, value)
	end

	-- tostring(enum.EnumType)
	local enum_type = projection.index(value, TYPE_FIELD) :: types.ProjIndex<Enum>
	local name = block:store(library.tostring(enum_type))
	ty_string.write(props, block, NAME_FORMAT, name)

	-- enum.Value
	local enum_value = block:store(projection.index(value, VALUE_FIELD) :: types.ProjIndex<number>)
	ty_numeral.write(props, block, VALUE_FORMAT, enum_value)
end

return table.freeze({
	read = build_read,
	write = build_write,
})
