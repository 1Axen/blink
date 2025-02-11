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

type Builder = fn.Builder
type Context = context.Context
type Attributes = attributes.TypeAttributes

type Color3 = ty.Color3
type LValue = lir.LValue
type RValue = lir.RValue
type Register = lir.RegisterId

local FORMAT = ty.numeral("32", "f")

local function build_read(ctx: Context, block: Builder, color3_ty: Color3, attributes: Attributes): Register
    local hue = numeral.build.read(ctx, block, FORMAT, attributes)
    local sat = numeral.build.read(ctx, block, FORMAT, attributes)
    local val = numeral.build.read(ctx, block, FORMAT, attributes)
    local color3_ctor = library.Color3.from_HSV(hue, sat, val)
    return block:store(color3_ctor)
end

local function build_write(ctx: Context, block: Builder, color3_ty: Color3, attributes: Attributes, at: LValue): ()
    local components = block:store_mult(library.Color3.to_HSV(at), 3)
    numeral.build.write(ctx, block, FORMAT, attributes, components[1])
    numeral.build.write(ctx, block, FORMAT, attributes, components[2])
    numeral.build.write(ctx, block, FORMAT, attributes, components[3])
end

local function validate(ctx: Context, block: Builder, color3_ty: Color3, at: LValue)
    
end

return table.freeze({
    build = table.freeze({
        read = build_read,
        write = build_write,
    }),
    validate = table.freeze({
        read = validate,
        write = validate
    })
})