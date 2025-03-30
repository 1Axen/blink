local ty = require("@structures/ty")
local lir = require("@structures/lir")
local attributes = require("@config/attributes")

local fn = require("@builders/fn")
local ternary = require("@builders/ternary")
local structure = require("@builders/structure")
local constant = require("@builders/constant")
local condition = require("@builders/condition")
local projection = require("@builders/projection")

local context = require("@lir/build/context")

local numeral = require("./numeral")

local types = require("../types")

type TyBuilder = types.TyBuilder
type ReadProps = types.ReadProps
type WriteProps = types.WriteProps

type Builder = fn.Builder
type Context = context.Context
type Attributes = attributes.TypeAttributes

type Set = ty.Set
type LValue<T> = lir.LValue<T>
type RValue<T> = lir.RValue<T>
type Register<T> = lir.RegisterId<T>

type LuauSet = {[string]: any}

local FORMAT = numeral.u8

local function build_read(props: ReadProps, block: Builder, set: Set): Register<LuauSet>
    local set_register = block:store(structure.struct({})) :: Register<any>

    for _, item in set.items do
        local value = numeral.read(props, block, FORMAT)
        local field = projection.field(set_register, constant.from_value(item.value) :: RValue<any>) 
        local in_set = condition.equals(value, constant.one)
        block:store(in_set, field)
    end

    return set_register
end

local function build_write(props: WriteProps, block: Builder, set: Set, value: RValue<LuauSet>): ()
    for _, item in set.items do
        local field = projection.field(value :: any, constant.from_value(item.value) :: RValue<any>)
        local in_set = condition.equals(field, constant.truth)
        local value_register = block:store(ternary(in_set, constant.one, constant.zero)) :: Register<number>
        numeral.write(props, block, FORMAT, value_register)
    end
end

return table.freeze({
    read = build_read,
    write = build_write,
})