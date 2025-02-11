local ty = require("@structures/ty")
local lir = require("@structures/lir")
local hir = require("@structures/hir")
local attributes = require("@config/attributes")

local fn = require("@builders/fn")
local control = require("@builders/control")
local library = require("@builders/library")
local constant = require("@builders/constant")
local condition = require("@builders/condition")
local projection = require("@builders/projection")

local struct = require("./struct")
local numeral = require("./numeral")

local conversion = require("@util/conversion")

local context = require("@lir/build/context")

type Builder = fn.Builder
type Context = context.Context
type Attributes = attributes.TypeAttributes

type TaggedEnum = ty.TaggedEnum
type LValue = lir.LValue
type RValue = lir.RValue
type Register = lir.RegisterId

local function build_read(ctx: Context, block: Builder, enum: TaggedEnum, attributes: Attributes): Register
    local total = #enum.variants

    -- account for serdesing from 0
    local format = conversion.to_numeral(total - 1)

    local stored_index = numeral.build.read(ctx, block, format, attributes)
    local value_register = block:store()

    local out_of_bounds = condition.greater_than_or(
        stored_index,
        constant.from_value(total)
    )

    block:if_branch(out_of_bounds, function(block)
        block:call_lib(library.error(`Invalid enum variant`))
    end)
    
    for index, variant in enum.variants do
        local is_variant = condition.equals(
            stored_index,
            constant.from_value(index - 1)
        )

        block:elseif_branch(is_variant, function(block)
            local struct_register = struct.build.read(ctx, block, variant.value, attributes)
            block:store(struct_register, value_register)
        end)
    end

    return value_register
end

local function build_write(ctx: Context, block: Builder, enum: TaggedEnum, attributes: Attributes, at: LValue): ()
    local tag = constant.from_value(enum.tag)
    local total = #enum.variants

    -- account for serdesing from 0
    local format = conversion.to_numeral(total - 1)
    local tag_register = block:store(projection.field(at, tag))

    for index, variant in enum.variants do
        local key = hir.ty_from_id(ctx.hir, variant.key)
        local is_variant = condition.equals(
            tag_register,
            constant.from_ty(key) :: lir.RValue
        )

        local function store_variant(block: Builder)
            local index_register = block:store(constant.from_value(index - 1))
            numeral.build.write(ctx, block, format, attributes, index_register)
            struct.build.write(ctx, block, variant.value, attributes, at)
        end

        if index == 1 then
            block:if_branch(is_variant, store_variant)
        elseif index > 1 then
            block:elseif_branch(is_variant, store_variant)
        end
    end

    block:else_branch(function(block)
        block:call_lib(library.error(`Invalid enum variant`))
    end)
end

local function validate(ctx: Context, block: Builder, enum: TaggedEnum, at: LValue)
    
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