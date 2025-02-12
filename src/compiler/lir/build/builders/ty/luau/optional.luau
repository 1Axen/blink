local ty = require("@structures/ty")
local lir = require("@structures/lir")
local attributes = require("@config/attributes")

local types = require("../types")
local numeral = require("./numeral")

local fn = require("@builders/fn")
local ternary = require("@builders/ternary")
local control = require("@builders/control")
local library = require("@builders/library")
local constant = require("@builders/constant")
local condition = require("@builders/condition")
local ty_builder = (require :: any)("@builders/ty") :: types.TyBuilder

local context = require("@lir/build/context")

type Builder = fn.Builder
type Context = context.Context
type Attributes = attributes.TypeAttributes

type Optional = ty.Optional
type LValue = lir.LValue
type RValue = lir.RValue
type Register = lir.RegisterId

local FORMAT = numeral.u8

local function build_read(ctx: Context, block: Builder, optional: Optional, attributes: Attributes): Register
    local byte_register = numeral.build.read(ctx, block, FORMAT, attributes)
    local value_register = block:store()
    
    local exists = condition.equals(byte_register, constant.one)
    block:if_branch(exists, function(block)
        block:store(
            ty_builder.build.read(ctx, block, optional.of, attributes), 
            value_register
        )
    end)

    return value_register
end

local function build_write(ctx: Context, block: Builder, optional: Optional, attributes: Attributes, at: LValue): ()
    local exists = condition.not_equals(at, constant.null)
    local byte_cursor = block:store(control.allocate(constant.one))
    local byte_register = block:store(ternary(exists, constant.one, constant.zero))
    
    block:if_branch(exists, function(block)
        ty_builder.build.write(ctx, block, optional.of, attributes, at)
    end)

    numeral.build.write(ctx, block, FORMAT, attributes, byte_register)
end

local function validate(ctx: Context, block: Builder, optional: Optional, at: LValue)
    
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