local attributes = require("@config/attributes")
local ty = require("@ty")
local types = require("@lir/types")

local condition = require("@builders/condition")
local constant = require("@builders/constant")
local fn = require("@builders/fn")
local library = require("@builders/library")

local binary = require("@builders/binary")
local context = require("@lir/build/context")
local globals = require("@builders/globals")
local projection = require("@builders/projection")

local builder_types = require("../builder_types")

type TyBuilder = builder_types.TyBuilder
type ReadProps = builder_types.ReadProps
type WriteProps = builder_types.WriteProps

type Builder = fn.Builder
type Context = context.Context
type Attributes = attributes.Attributes

type Instance = ty.Instance

type LValue<T> = types.LValue<T>
type RValue<T> = types.RValue<T>
type Register<T> = types.RegisterId<T>

local DEFAULT_TYPE = constant.from_value("Instance")

local function validate(ctx: Context, block: Builder, instance: Instance, value: RValue<Instance>)
	local is_not_type = condition.not_equals(library.typeof(value :: any), DEFAULT_TYPE)
	block:if_single(is_not_type, function(block)
		block:call(library.error("Expected an Instance"))
	end)

	local class_ty = instance.class
	if class_ty == nil then
		return
	end

	-- LUAU
	local class = constant.from_value(class_ty.value)
	local is_not_class = condition.not_equals(library.Instance.is_a(value :: any, class), constant.from_value(true))

	block:if_single(is_not_class, function(block)
		block:call(library.error(`Expected an Instance of class "{class.value}"`))
	end)
end

local function build_read(props: ReadProps, block: Builder, instance: Instance, into: LValue<any>?): Register<Instance>
	local unknown_cursor = globals.incoming.unknown_cursor
	local value = projection.field(globals.incoming.unknown :: LValue<any>, unknown_cursor) :: types.ProjField<Instance>
	block:store(binary.add(unknown_cursor, constant.one), unknown_cursor)

	local register = block:store(value, into)
	validate(props.ctx, block, instance, register)

	return register
end

local function build_write(props: WriteProps, block: Builder, instance: Instance, value: RValue<Instance>): ()
	if props.validate then
		validate(props.ctx, block, instance, value)
	end

	block:call(library.table.insert(globals.outgoing.unknown, value))
end

return table.freeze({
	read = build_read,
	write = build_write,
})
