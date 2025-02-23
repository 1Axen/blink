local ty = require("@structures/ty")
local lir = require("@structures/lir")
local hir = require("@structures/hir")
local attributes = require("@config/attributes")

local fn = require("@builders/fn")
local binary = require("@builders/binary")
local wrapper = require("@builders/wrapper")
local control = require("@builders/control")
local library = require("@builders/library")
local constant = require("@builders/constant")
local condition = require("@builders/condition")
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
type LValue = lir.LValue
type RValue = lir.RValue
type Register = lir.RegisterId

local function build_read(props: ReadProps, block: Builder, map: Map): Register
    local ctx = props.ctx
    
    local key_ty = hir.ty_from_id(ctx.hir, map.index)
    local value_ty = hir.ty_from_id(ctx.hir, map.value)

    local len = length.read(props, block, map)
    local map_register = block:store(wrapper.table({}))

    block:for_numeric(len, function(block)
        local key = ty_builder.read(props, block, key_ty)
        local value = ty_builder.read(props, block, value_ty)
        local map_index = projection.field(map_register, key)
        block:store(value, map_index)
    end)

    return map_register
end

local function build_write(props: WriteProps, block: Builder, map: Map, at: RValue): ()
    local ctx = props.ctx
    
    local key_ty = hir.ty_from_id(ctx.hir, map.index)
    local value_ty = hir.ty_from_id(ctx.hir, map.value)

    local elements_register = block:store(constant.zero)
    local increase_elements = binary.add(elements_register, constant.one) 
    block:for_generic(at, function(block)
        block:store(increase_elements, elements_register)
    end)

    length.write(props, block, map, elements_register)

    block:for_generic(at, function(block, key, value)
        ty_builder.write(props, block, key_ty, key)
        ty_builder.write(props, block, value_ty, value)
    end)
end

return table.freeze({
    read = build_read,
    write = build_write,
})