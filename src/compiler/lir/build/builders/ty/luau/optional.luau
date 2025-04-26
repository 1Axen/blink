local ty = require("@structures/ty")
local lir = require("@structures/lir")
local hir = require("@structures/hir")
local attributes = require("@config/attributes")

local numeral = require("./numeral")

local fn = require("@builders/fn")
local ternary = require("@builders/ternary")
local control = require("@builders/control")
local library = require("@builders/library")
local constant = require("@builders/constant")
local condition = require("@builders/condition")
local ty_builder = require("@builders/ty")

local context = require("@lir/build/context")

local types = require("../types")

type TyBuilder = types.TyBuilder
type ReadProps = types.ReadProps
type WriteProps = types.WriteProps

type Builder = fn.Builder
type Context = context.Context
type Attributes = attributes.TypeAttributes

type Optional = ty.Optional
type LValue<T> = lir.LValue<T>
type RValue<T> = lir.RValue<T>
type Register<T> = lir.RegisterId<T>

local FORMAT = numeral.u8

local function build_read(props: ReadProps, block: Builder, optional: Optional): Register<unknown>
    local ctx = props.ctx

    local byte_register = numeral.read(props, block, FORMAT)
    local value_register = block:reserve()
    
    local exists = condition.equals(byte_register, constant.one)
    block:if_branch(exists, function(block)
        block:store(
            ty_builder.read(props, block, optional.of),
            value_register
        )
    end)

    return value_register
end

local function build_write(props: WriteProps, block: Builder, optional: Optional, value: RValue<any>): ()
    local ctx = props.ctx

    local exists = condition.not_equals(value, constant.null)
    local cursor = block:store(control.allocate(constant.one))
    
    block:if_branch(exists, function(block)
        ty_builder.write(props, block, optional.of, value)
    end)

    local as_number = ternary(exists, constant.one, constant.zero)
    block:call_lib(library.buffer.u8.write(cursor, as_number))
end

return table.freeze({
    read = build_read,
    write = build_write,
})