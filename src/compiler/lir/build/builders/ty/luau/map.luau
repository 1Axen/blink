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

type Builder = fn.Builder
type Context = context.Context
type Attributes = attributes.TypeAttributes

type Map = ty.Map
type LValue = lir.LValue
type RValue = lir.RValue
type Register = lir.RegisterId

local function build_read(ctx: Context, block: Builder, map: Map, attributes: Attributes): Register
    local index_ty = hir.ty_from_id(ctx.hir, map.index)
    local value_ty = hir.ty_from_id(ctx.hir, map.value)

    local len = length.read(ctx, block, map, attributes)
    local map_register = block:store(wrapper.table({}))

    block:for_numeric(len, function(block)
        local index_register = ty_builder.build.read(ctx, block, index_ty, attributes)
        local value_register = ty_builder.build.read(ctx, block, value_ty, attributes)
        local index_into_map = projection.field(map_register, index_register)
        block:store(value_register, index_into_map)
    end)

    return map_register
end

local function build_write(ctx: Context, block: Builder, map: Map, attributes: Attributes, at: LValue): ()
    local index_ty = hir.ty_from_id(ctx.hir, map.index)
    local value_ty = hir.ty_from_id(ctx.hir, map.value)

    local elements_register = block:store(constant.zero)
    local increase_elements = binary.add(elements_register, constant.one) 
    block:for_generic(at, function(block)
        block:store(increase_elements, elements_register)
    end)

    length.write(ctx, block, map, attributes, elements_register)

    block:for_generic(at, function(block, index_register, value_register)
        ty_builder.build.write(ctx, block, index_ty, attributes, index_register)
        ty_builder.build.write(ctx, block, value_ty, attributes, value_register)
    end)
end

local function validate_read(ctx: Context, block: Builder, map: Map, at: LValue)
    
end

local function validate_write(ctx: Context, block: Builder, map: Map, at: LValue)
    
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