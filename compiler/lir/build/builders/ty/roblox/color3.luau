local attributes = require("@config/attributes")
local ty = require("@ty")
local types = require("@lir/types")

local numeral = require("../luau/numeral")

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

type LValue<T> = types.LValue<T>
type RValue<T> = types.RValue<T>
type Register<T> = types.RegisterId<T>

local FORMAT = ty.numeral(nil, "32", "f")

local function build_read(props: ReadProps, block: Builder, color3_ty: ty.Color3, into: LValue<any>?): Register<Color3>
	local hue = numeral.read(props, block, FORMAT)
	local sat = numeral.read(props, block, FORMAT)
	local val = numeral.read(props, block, FORMAT)
	local color3_ctor = library.Color3.from_HSV(hue, sat, val)
	return block:store(color3_ctor, into)
end

local function build_write(props: WriteProps, block: Builder, color3_ty: ty.Color3, value: RValue<Color3>): ()
	local components = block:store_mult(library.Color3.to_HSV(value) :: any, 3) :: { Register<number> }
	numeral.write(props, block, FORMAT, components[1])
	numeral.write(props, block, FORMAT, components[2])
	numeral.write(props, block, FORMAT, components[3])
end

return table.freeze({
	read = build_read,
	write = build_write,
})
