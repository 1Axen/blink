local attributes = require("@config/attributes")
local ty = require("@ty")
local types = require("@lir/types")

local condition = require("@builders/condition")
local constant = require("@builders/constant")
local control = require("@builders/control")
local fn = require("@builders/fn")
local library = require("@builders/library")
local ternary = require("@builders/ternary")

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
type Boolean = ty.Boolean
type Register<T> = types.RegisterId<T>

local function validate(block: Builder, ty: Boolean, value: RValue<boolean>)
	local type = constant.from_value("boolean")
	local equals = condition.not_equals(library.typeof(value), type)

	block:if_single(equals, function(block)
		block:call(library.error(`Expected a boolean`))
	end)
end

local function build_read(props: ReadProps, block: Builder, boolean: ty.Boolean, into: LValue<any>?): Register<boolean>
	local bytes = constant.from_value(1)
	local advance = control.advance(bytes)
	local buffer_read = library.buffer.u8.read(advance)

	local truthful = condition.equals(buffer_read, constant.from_value(1))
	local conversion = ternary(truthful, constant.from_value(true), constant.from_value(false))

	return block:store(conversion, into)
end

local function build_write(props: WriteProps, block: Builder, boolean: ty.Boolean, value: RValue<boolean>): ()
	if props.validate then
		validate(block, boolean, value)
	end

	local bytes = constant.from_value(1)
	local allocate = block:allocate(bytes)

	local truthful = condition.equals(value, constant.from_value(true))
	local conversion = ternary(truthful, constant.from_value(1), constant.from_value(0))
	local buffer_write = library.buffer.u8.write(allocate, conversion)

	block:call(buffer_write)
end

return table.freeze({
	read = build_read,
	write = build_write,
})
