local ty = require("@structures/ty")
local lir = require("@structures/lir")
local attributes = require("@config/attributes")

local numeral = require("../luau/numeral")

local fn = require("@builders/fn")
local control = require("@builders/control")
local library = require("@builders/library")
local constant = require("@builders/constant")
local condition = require("@builders/condition")

local context = require("@lir/build/context")

local types = require("../types")

type TyBuilder = types.TyBuilder
type ReadProps = types.ReadProps
type WriteProps = types.WriteProps

type Builder = fn.Builder
type Context = context.Context
type Attributes = attributes.TypeAttributes

type Color3 = ty.Color3
type LValue = lir.LValue
type RValue = lir.RValue
type Register = lir.RegisterId

local FORMAT = ty.numeral("32", "f")

local function build_read(props: ReadProps, block: Builder, color3_ty: Color3): Register
    local hue = numeral.read(props, block, FORMAT)
    local sat = numeral.read(props, block, FORMAT)
    local val = numeral.read(props, block, FORMAT)
    local color3_ctor = library.Color3.from_HSV(hue, sat, val)
    return block:store(color3_ctor)
end

local function build_write(props: WriteProps, block: Builder, color3_ty: Color3, value: RValue): ()
    local components = block:store_mult(library.Color3.to_HSV(value :: LValue), 3)
    numeral.write(props, block, FORMAT, components[1])
    numeral.write(props, block, FORMAT, components[2])
    numeral.write(props, block, FORMAT, components[3])
end

return table.freeze({
    read = build_read,
    write = build_write,
})