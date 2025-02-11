local ty = require("@structures/ty")
local lir = require("@structures/lir")
local attributes = require("@config/attributes")

local fn = require("@builders/fn")
local control = require("@builders/control")
local library = require("@builders/library")
local constant = require("@builders/constant")
local condition = require("@builders/condition")

local context = require("@lir/build/context")

type Builder = fn.Builder
type Context = context.Context
type Attributes = attributes.TypeAttributes

type Ty = ty.Ty
type LValue = lir.LValue
type RValue = lir.RValue
type Register = lir.RegisterId

local function build_read(ctx: Context, block: Builder, ty: Ty, attributes: Attributes): Register
    return block:store()
end

local function build_write(ctx: Context, block: Builder, ty: Ty, attributes: Attributes, at: LValue): ()

end

local function validate_read(ctx: Context, block: Builder, ty: Ty, at: LValue)
    
end

local function validate_write(ctx: Context, block: Builder, ty: Ty, at: LValue)
    
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