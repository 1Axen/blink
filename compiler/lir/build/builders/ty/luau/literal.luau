local attributes = require("@config/attributes")
local lir = require("@lir/types")
local ty = require("@ty/types")

local condition = require("@builders/condition")
local constant = require("@builders/constant")
local fn = require("@builders/fn")
local library = require("@builders/library")

local context = require("@lir/build/context")

local types = require("../types")

type TyBuilder = types.TyBuilder
type ReadProps = types.ReadProps
type WriteProps = types.WriteProps

type Builder = fn.Builder
type Context = context.Context
type Attributes = attributes.Attributes

type LValue<T = any> = lir.LValue<T>
type RValue<T = any> = lir.RValue<T>
type Literal = ty.Literal
type Register<T = any> = lir.RegisterId<T>

local function validate(props: WriteProps, block: Builder, ty: Literal, value: RValue)
	local constant = constant.from_ty(ty :: any)
	local equals = condition.not_equals(value, constant :: any)

	block:if_branch(equals, function(block)
		block:call(library.error(`Expected "{ty.value}"`))
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
