local attributes = require("@config/attributes")
local lir = require("@lir/types")
local ty = require("@ty/types")

local ty_numeral = require("../luau/numeral")

local constant = require("@builders/constant")
local fn = require("@builders/fn")
local library = require("@builders/library")
local projection = require("@builders/projection")

local context = require("@lir/build/context")

local types = require("../types")

type TyBuilder = types.TyBuilder
type ReadProps = types.ReadProps
type WriteProps = types.WriteProps

type Builder = fn.Builder
type Context = context.Context
type Attributes = attributes.TypeAttributes

type LValue<T> = lir.LValue<T>
type RValue<T> = lir.RValue<T>
type Register<T> = lir.RegisterId<T>

local FORMAT = ty_numeral.u16

local function build_read(
	props: ReadProps,
	block: Builder,
	brick_color: ty.BrickColor,
	into: LValue<any>?
): Register<BrickColor>
	local number = ty_numeral.read(props, block, FORMAT)
	return block:store(library.BrickColor.new(number), into)
end

local function build_write(props: WriteProps, block: Builder, brick_color: ty.BrickColor, value: RValue<BrickColor>): ()
	local number = projection.index(value :: any, constant.from_value("Number")) :: lir.ProjIndex<number>
	ty_numeral.write(props, block, FORMAT, number)
end

return table.freeze({
	read = build_read,
	write = build_write,
})
