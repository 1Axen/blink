local attributes = require("@config/attributes")
local ty = require("@ty")
local types = require("@lir/types")

local constant = require("@builders/constant")
local fn = require("@builders/fn")

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

local function build_read<A>(props: ReadProps, block: Builder, _: Nil, into: LValue<any>?): Register<A>
	return block:store(constant.null, into)
end

local function build_write(props: WriteProps, block: Builder, nnil: Nil, value: RValue): ()
	-- noop
end

return table.freeze({
	read = build_read,
	write = build_write,
})
