local ty = require("@structures/ty")
local lir = require("@structures/lir")
local attributes = require("@config/attributes")

local fn = require("@builders/fn")
local binary = require("@builders/binary")
local constant = require("@builders/constant")
local structure = require("@builders/structure")
local projection = require("@builders/projection")
local ty_builder = require("@builders/ty")

local length = require("./length")

local context = require("@lir/build/context")

local types = require("../types")

type TyBuilder = types.TyBuilder
type ReadProps = types.ReadProps
type WriteProps = types.WriteProps

type Builder = fn.Builder
type Context = context.Context
type Attributes = attributes.TypeAttributes

type Map = ty.Map
type LValue<T> = lir.LValue<T>
type RValue<T> = lir.RValue<T>
type Register<T> = lir.RegisterId<T>

local function build_read(props: ReadProps, block: Builder, map: Map, into: LValue<any>?): Register<{[any]: any}>
    local len = length.read(props, block, map)
    local register = block:store(structure.map({}))

    block:for_numeric(len, function(block)
        local key = ty_builder.read(props, block, map.index)
        local value = ty_builder.read(props, block, map.value)
        local map_index = projection.field(register, key)
        block:store(value, map_index)
    end)

    if into then
        return block:store(register, into)
    end

    return register
end

local function build_write(props: WriteProps, block: Builder, map: Map, at: RValue<{[any]: any}>): ()
    local elements_register = block:store(constant.zero)
    local increase_elements = binary.add(elements_register, constant.one) 
    block:for_generic(at, function(block)
        block:store(increase_elements, elements_register)
    end)

    length.write(props, block, map, elements_register)

    block:for_generic(at, function(block, key, value)
        ty_builder.write(props, block, map.index, key)
        ty_builder.write(props, block, map.value, value)
    end)
end

return table.freeze({
    read = build_read,
    write = build_write,
})