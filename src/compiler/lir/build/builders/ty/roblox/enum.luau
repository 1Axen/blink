local ty = require("@structures/ty")
local lir = require("@structures/lir")
local hir = require("@structures/hir")
local attributes = require("@config/attributes")

local ty_string = require("../luau/string")
local ty_numeral = require("../luau/numeral")

local fn = require("@builders/fn")
local control = require("@builders/control")
local library = require("@builders/library")
local constant = require("@builders/constant")
local condition = require("@builders/condition")
local projection = require("@builders/projection")

local context = require("@lir/build/context")

type Builder = fn.Builder
type Context = context.Context
type Attributes = attributes.TypeAttributes

type Enum = ty.Enum
type LValue = lir.LValue
type Register = lir.RegisterId

local const = constant.from_value

local NAME_FORMAT = ty.string()
local VALUE_FORMAT = ty.numeral("16", "u")

local function to_static_enum_type(ctx: Context, ty: Enum): lir.Constant<string>?
    local ty_id = ty.type
    if ty_id == nil then
        return nil
    end

    local ty = hir.ty_from_id(ctx.hir, ty_id) :: ty.StringLiteral
    return constant.from_value(ty.value)
end

local function build_read(ctx: Context, block: Builder, ty: Enum, attributes: Attributes): Register
    -- Enum[name]
    local name = ty_string.build.read(ctx, block, NAME_FORMAT, attributes)
    local enum = projection.field(
        const("Enum"), 
        name
    )

    -- enum:FromValue(value)
    local value = ty_numeral.build.read(ctx, block, VALUE_FORMAT, attributes)
    local enum_item = projection.namecall(
        enum, 
        const("FromValue"), 
        {value :: lir.RValue}
    )
    
    return block:store(enum_item)
end

local function build_write(ctx: Context, block: Builder, ty: Enum, attributes: Attributes, at: LValue): ()
    -- tostring(enum.EnumType)
    local enum_type = projection.index(at, const("EnumType"))
    local name = block:store(library.tostring(enum_type))
    ty_string.build.write(ctx, block, NAME_FORMAT, attributes, name)

    -- enum.Value
    local value = block:store(projection.index(at, const("Value")))
    ty_numeral.build.write(ctx, block, VALUE_FORMAT, attributes, value)
end

local function validate(ctx: Context, block: Builder, ty: Enum, at: LValue)
    local static_enum_type = to_static_enum_type(ctx, ty)
    if static_enum_type == nil then
        return
    end

    local enum_type = projection.index(at, const("EnumType"))
    local type_cond = condition.not_equals(enum_type, static_enum_type)

    block:if_branch(type_cond, function(block)
        block:call_lib(library.error(`Expected an enum of type: "{static_enum_type.value}"`))
    end)
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