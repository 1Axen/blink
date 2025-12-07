local attributes = require("@config/attributes")
local ty = require("@ty")
local types = require("@lir/types")

local condition = require("@builders/condition")
local constant = require("@builders/constant")
local fn = require("@builders/fn")
local library = require("@builders/library")

local context = require("@lir/build/context")

local builder_types = require("../builder_types")

type TyBuilder = builder_types.TyBuilder
type ReadProps = builder_types.ReadProps
type WriteProps = builder_types.WriteProps

type Builder = fn.Builder
type Context = context.Context
type Attributes = attributes.Attributes

type Nil = ty.Nil
type LValue<T = any> = types.LValue<T>
type RValue<T = any> = types.RValue<T>
type Register<T = any> = types.RegisterId<T>

local function validate(props: WriteProps, block: Builder, ty: Nil, value: RValue)
	block:if_single(condition.not_equals(value, constant.null), function(block)
		block:call(library.error(`Expected "nil"`))
	end)
end

local function build_read<A>(props: ReadProps, block: Builder, _: Nil, into: LValue<any>?): Register<A>
	return block:store(constant.null, into)
end

local function build_write(props: WriteProps, block: Builder, nnil: Nil, value: RValue): ()
	if props.validate then
		validate(props, block, nnil, value)
	end
end

return table.freeze({
	read = build_read,
	write = build_write,
})
