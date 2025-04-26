local ty = require("@structures/ty")
local lir = require("@structures/lir")
local attributes = require("@config/attributes")

local fn = require("@builders/fn")
local unary = require("@builders/unary")
local library = require("@builders/library")
local projection = require("@builders/projection")

local context = require("@lir/build/context")

local length = require("./length")
local ty_builder = require("@builders/ty")

local types = require("../types")

type TyBuilder = types.TyBuilder
type ReadProps = types.ReadProps
type WriteProps = types.WriteProps

type Builder = fn.Builder
type Context = context.Context
type Attributes = attributes.TypeAttributes

type Array = ty.Array
type LValue<T> = lir.LValue<T>
type RValue<T> = lir.RValue<T>
type Register<T> = lir.RegisterId<T>

local function build_read(props: ReadProps, block: Builder, array: ty.Array): Register<{any}>
    local len = length.read(props, block, array)
    local array_register = block:store(library.table.create(len))
    
    block:for_numeric(len, function(block, index)
        local element = ty_builder.read(props, block, array.of)
        local position = projection.field(array_register :: any, index)
        block:store(element, position)
    end)

    return array_register
end

local function build_write(props: WriteProps, block: Builder, array: ty.Array, value: RValue<{any}>): ()
    length.write(props, block, array, unary.len(value :: any))
    block:for_generic(value :: any, function(block, _, value)
        ty_builder.write(props, block, array.of, value)
    end)
end

return table.freeze({
    read = build_read,
    write = build_write,
})