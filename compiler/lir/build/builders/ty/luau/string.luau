local lir = require("@lir/types")
local ty = require("@ty/types")

local attributes = require("@config/attributes")

local control = require("@builders/control")
local fn = require("@builders/fn")
local library = require("@builders/library")
local unary = require("@builders/unary")

local context = require("@lir/build/context")
local length = require("./length")

local types = require("../types")

type TyBuilder = types.TyBuilder
type ReadProps = types.ReadProps
type WriteProps = types.WriteProps

type Builder = fn.Builder
type Context = context.Context
type Attributes = attributes.Attributes

type String = ty.String
type LValue<T> = lir.LValue<T>
type RValue<T> = lir.RValue<T>
type Register<T> = lir.RegisterId<T>

local function build_read(props: ReadProps, block: Builder, ty: String, into: LValue<any>?): Register<string>
	local len = length.read(props, block, ty)
	local cursor = control.advance(len)
	return block:store(library.buffer.string.read(cursor, len), into)
end

local function build_write(props: WriteProps, block: Builder, ty: String, value: RValue<string>): ()
	local len = length.write(props, block, ty, unary.len(value :: any))
	local cursor = block:allocate(len)
	block:call(library.buffer.string.write(cursor, len, value))
end

return table.freeze({
	read = build_read,
	write = build_write,
})
