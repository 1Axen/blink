local ty = require("@structures/ty")
local lir = require("@structures/lir")
local hir = require("@structures/hir")
local attributes = require("@config/attributes")

local ty_string = require("../luau/string")
local ty_numeral = require("../luau/numeral")

local fn = require("@builders/fn")
local library = require("@builders/library")
local constant = require("@builders/constant")
local condition = require("@builders/condition")
local projection = require("@builders/projection")

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
type Register<T> = lir.RegisterId<T>

local const = constant.from_value

local NAME_FORMAT = ty.string()
local VALUE_FORMAT = ty.numeral("16", "u")

local function to_static_enum_type(ctx: Context, ty: ty.Enum): lir.Constant<string>?
    local ty_id = ty.type
    if ty_id == nil then
        return nil
    end

    local literal = hir.ty_from_id(ctx.hir, ty_id) :: ty.StringLiteral
    return constant.from_value(literal.value)
end

local function validate(props: WriteProps, block: Builder, ty: ty.Enum, at: RValue<EnumItem>)
    local static_enum_type = to_static_enum_type(props.ctx, ty)
    if static_enum_type == nil then
        return
    end

    local enum_type = projection.index(at :: any, const("EnumType"))
    local type_cond = condition.not_equals(enum_type, static_enum_type)

    block:if_branch(type_cond, function(block)
        block:call_lib(library.error(`Expected an enum of type: "{static_enum_type.value}"`))
    end)
end

local function build_read(props: ReadProps, block: Builder, ty: ty.Enum, into: LValue<any>?): Register<EnumItem>
    -- Enum[name]
    local name = ty_string.read(props, block, NAME_FORMAT, attributes)
    local enum = projection.field(
        const("Enum"), 
        name :: any
    ) :: lir.ProjField<Enum>

    -- enum:FromValue(value)
    local value = ty_numeral.read(props, block, VALUE_FORMAT, attributes)
    local enum_item = projection.namecall(
        enum :: any, 
        const("FromValue"), 
        {value :: any}
    ) :: lir.ProjNamecall<EnumItem>
    
    return block:store(enum_item, into)
end

local function build_write(props: WriteProps, block: Builder, ty: ty.Enum, value: RValue<EnumItem>): ()
    if props.validate then
        validate(props, block, ty, value)
    end

    -- tostring(enum.EnumType)
    local enum_type = projection.index(value :: any, const("EnumType")) :: lir.ProjIndex<Enum>
    local name = block:store(library.tostring(enum_type :: any))
    ty_string.write(props, block, NAME_FORMAT, name)

    -- enum.Value
    local enum_value = block:store(projection.index(value :: any, const("Value")) :: lir.ProjIndex<number>)
    ty_numeral.write(props, block, VALUE_FORMAT, enum_value)
end

return table.freeze({
    read = build_read,
    write = build_write,
})