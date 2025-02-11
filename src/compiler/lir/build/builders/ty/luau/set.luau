local ty = require("@structures/ty")
local lir = require("@structures/lir")
local attributes = require("@config/attributes")

local fn = require("@builders/fn")
local ternary = require("@builders/ternary")
local wrapper = require("@builders/wrapper")
local control = require("@builders/control")
local library = require("@builders/library")
local constant = require("@builders/constant")
local condition = require("@builders/condition")
local projection = require("@builders/projection")

local context = require("@lir/build/context")

local numeral = require("./numeral")

type Builder = fn.Builder
type Context = context.Context
type Attributes = attributes.TypeAttributes

type Set = ty.Set
type LValue = lir.LValue
type RValue = lir.RValue
type Register = lir.RegisterId

local FORMAT = numeral.u8

local function build_read(ctx: Context, block: Builder, set: Set, attributes: Attributes): Register
    local set_register = block:store(wrapper.table({}))

    for _, item in set.items do
        local value = numeral.build.read(ctx, block, FORMAT, attributes)
        local field = projection.field(set_register, constant.from_value(item.value))
        local in_set = condition.equals(value, constant.one)
        block:store(in_set, field)
    end

    return set_register
end

local function build_write(ctx: Context, block: Builder, set: Set, attributes: Attributes, at: LValue): ()
    for _, item in set.items do
        local field = projection.field(at, constant.from_value(item.value))
        local in_set = condition.equals(field, constant.truth)
        local value_register = block:store(ternary(in_set, constant.one, constant.zero))
        numeral.build.write(ctx, block, FORMAT, attributes, value_register)
    end
end

local function validate(ctx: Context, block: Builder, set: Set, at: LValue)
    
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