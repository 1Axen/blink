local ty = require("@structures/ty")
local lir = require("@structures/lir")
local attributes = require("@config/attributes")

local ty_numeral = require("../luau/numeral")

local fn = require("@builders/fn")
local control = require("@builders/control")
local library = require("@builders/library")
local constant = require("@builders/constant")
local condition = require("@builders/condition")
local projection = require("@builders/projection")

local context = require("@lir/build/context")

local types = require("../types")

type TyBuilder = types.TyBuilder
type ReadProps = types.ReadProps
type WriteProps = types.WriteProps

type Builder = fn.Builder
type Context = context.Context
type Attributes = attributes.TypeAttributes

type BrickColor = ty.BrickColor
type LValue = lir.LValue
type RValue = lir.RValue
type Register = lir.RegisterId

local FORMAT = ty_numeral.u16

local function build_read(props: ReadProps, block: Builder, brick_color: BrickColor): Register
    local number = ty_numeral.read(props, block, FORMAT)
    return block:store(library.BrickColor.new(number))
end

local function build_write(props: WriteProps, block: Builder, brick_color: BrickColor, value: RValue): ()
    local number = projection.index(value :: LValue, constant.from_value("Number"))
    ty_numeral.write(props, block, FORMAT, number)
end

return table.freeze({
    read = build_read,
    write = build_write,
})