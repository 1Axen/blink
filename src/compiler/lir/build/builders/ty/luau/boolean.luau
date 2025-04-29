local ty = require("@ty/types")
local lir = require("@lir/types")
local attributes = require("@config/attributes")

local fn = require("@builders/fn")
local ternary = require("@builders/ternary")
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

type LValue<T> = lir.LValue<T>
type RValue<T> = lir.RValue<T>
type Boolean = ty.Boolean
type Register<T> = lir.RegisterId<T>

local function validate(block: Builder, ty: Boolean, value: RValue<boolean>)
    local type = constant.from_value("boolean")
    local equals = condition.not_equals(value, type)

    block:if_branch(equals, function(block)
        block:call_lib(library.error(`Expected a boolean`))
    end)
end

local function build_read(props: ReadProps, block: Builder, boolean: ty.Boolean, into: LValue<any>?): Register<boolean>
    local bytes = constant.from_value(1)
    local advance = control.advance(bytes)
    local buffer_read = library.buffer.u8.read(advance)

    local truthful = condition.equals(buffer_read, constant.from_value(1))
    local conversion = ternary(truthful, constant.from_value(true), constant.from_value(false)) 

    return block:store(conversion, into)
end

local function build_write(props: WriteProps, block: Builder, boolean: ty.Boolean, value: RValue<boolean>): ()
    if props.validate then
        validate(block, boolean, value)
    end

    local bytes = constant.from_value(1)
    local allocate = block:store(control.allocate(bytes))

    local truthful = condition.equals(value, constant.from_value(true))
    local conversion = ternary(truthful, constant.from_value(1), constant.from_value(0)) 
    local buffer_write = library.buffer.u8.write(allocate, conversion)

    block:call_lib(buffer_write)
end

return table.freeze({
    read = build_read,
    write = build_write,
})