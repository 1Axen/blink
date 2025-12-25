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

type LValue<T = any> = types.LValue<T>
type RValue<T = any> = types.RValue<T>
type Literal = ty.Literal
type Register<T = any> = types.RegisterId<T>

local function validate(props: WriteProps, block: Builder, ty: Literal, value: RValue)
	local constant = constant.from_ty(ty :: any)
	local equals = condition.not_equals(value, constant :: any)

	block:if_single(equals, function(block)
		local message = library.string.format(`Expected {ty.value}, got %* instead`, value)
		block:call(library.error_rvalue(message))
	end)
end

local function build_read<A>(props: ReadProps, block: Builder, literal: ty.Literal, into: LValue<any>?): Register<A>
	local constant = constant.from_ty((literal :: any) :: { kind: any, value: A })
	return block:store(constant, into)
end

local function build_write(props: WriteProps, block: Builder, literal: ty.Literal, value: RValue): ()
	if props.validate then
		validate(props, block, literal, value)
	end
end

return table.freeze({
	read = build_read,
	write = build_write,
})
