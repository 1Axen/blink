local ty = require("@structures/ty")
local lir = require("@structures/lir")
local attributes = require("@config/attributes")

local fn = require("@builders/fn")
local unary = require("@builders/unary")
local control = require("@builders/control")
local library = require("@builders/library")
local constant = require("@builders/constant")
local condition = require("@builders/condition")

local context = require("@lir/build/context")

local length = require("./length")

type Builder = fn.Builder
type Context = context.Context
type Attributes = attributes.TypeAttributes

type Array = ty.Array
type LValue = lir.LValue
type RValue = lir.RValue
type Register = lir.RegisterId

local function build_read(ctx: Context, block: Builder, array: Array, attributes: Attributes): Register
    local len = length.read(ctx, block, array, attributes)
    return block:store()
end

local function build_write(ctx: Context, block: Builder, array: Array, attributes: Attributes, at: LValue): ()
    local len = length.read(ctx, block, array, attributes, unary.len(at))
end

local function validate_read(ctx: Context, block: Builder, array: Array, at: LValue)
    
end

local function validate_write(ctx: Context, block: Builder, array: Array, at: LValue)
    
end

return table.freeze({
    build = table.freeze({
        read = build_read,
        write = build_write,
    }),
    validate = table.freeze({
        read = validate_read,
        write = validate_write
    })
})