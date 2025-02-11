local ty = require("@structures/ty")
local lir = require("@structures/lir")
local hir = require("@structures/hir")
local attributes = require("@config/attributes")

local ty_numeral = require("../luau/numeral")

local fn = require("@builders/fn")
local control = require("@builders/control")
local library = require("@builders/library")
local constant = require("@builders/constant")
local condition = require("@builders/condition")
local projection = require("@builders/projection")

local context = require("@lir/build/context")

type Builder = fn.Builder
type Context = context.Context
type Attributes = attributes.TypeAttributes

type Instance = ty.Instance

type LValue = lir.LValue
type RValue = lir.RValue
type Register = lir.RegisterId

local DEFAULT_TYPE = constant.from_value("Instance")
local DEFAULT_CLASS = constant.from_value("Instance")

local function build_read(ctx: Context, block: Builder, instance: Instance, attributes: Attributes): Register
    return block:store()
end

local function build_write(ctx: Context, block: Builder, instance: Instance, attributes: Attributes, at: LValue): ()
    
end

local function validate(ctx: Context, block: Builder, instance: Instance, at: LValue)
    
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