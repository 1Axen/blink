local attributes = require("@config/attributes")
local hir = require("@hir/types")
local lir = require("@lir/types")
local ty = require("@ty/types")

local condition = require("@builders/condition")
local constant = require("@builders/constant")
local fn = require("@builders/fn")
local library = require("@builders/library")

local binary = require("@builders/binary")
local context = require("@lir/build/context")
local globals = require("@builders/globals")
local projection = require("@builders/projection")

local types = require("../types")

type TyBuilder = types.TyBuilder
type ReadProps = types.ReadProps
type WriteProps = types.WriteProps

type Builder = fn.Builder
type Context = context.Context
type Attributes = attributes.TypeAttributes

type Instance = ty.Instance

type LValue<T> = lir.LValue<T>
type RValue<T> = lir.RValue<T>
type Register<T> = lir.RegisterId<T>

local DEFAULT_TYPE = constant.from_value("Instance")

local function validate(ctx: Context, block: Builder, instance: Instance, value: RValue<Instance>)
	local is_not_type = condition.not_equals(library.typeof(value :: any), DEFAULT_TYPE)
	block:if_branch(is_not_type, function(block)
		block:call_lib(library.error("Expected an Instance"))
	end)

	local class_ty_id = instance.class
	if class_ty_id == nil then
		return
	end

	-- LUAU
	local class_ty = hir.ty_from_id(ctx.hir, class_ty_id)
	local class_constant = constant.from_value(class_ty.value)
	local is_not_class =
		condition.not_equals(library.Instance.is_a(value :: any, class_constant), constant.from_value(true))

	block:if_branch(is_not_class, function(block)
		block:call_lib(library.error(`Expected an Instance of class "{class_constant.value}"`))
	end)
end

local function validate_optional(ctx: Context, block: Builder, instance: Instance, value: RValue<Instance>)
	block:if_branch(condition.not_equals(value, constant.null), function(block)
		validate(ctx, block, instance, value)
	end)
end

local function build_read(props: ReadProps, block: Builder, instance: Instance, into: LValue<any>?): Register<Instance>
	local unknown_cursor = globals.incoming.unknown_cursor
	local value = projection.field(globals.incoming.unknown :: LValue<any>, unknown_cursor) :: lir.ProjField<Instance>
	block:store(binary.add(unknown_cursor, constant.one), unknown_cursor)

	local register = block:store(value, into)
	if props.is_optional then
		validate_optional(props.ctx, block, instance, register)
	else
		validate(props.ctx, block, instance, register)
	end

	return register
end

local function build_write(props: WriteProps, block: Builder, instance: Instance, value: RValue<Instance>): ()
	if props.validate then
		validate(props.ctx, block, instance, value)
	end

	block:call_lib(library.table.insert(globals.outgoing.unknown, value))
end

return table.freeze({
	read = build_read,
	write = build_write,
})
