local ty = require("@structures/ty")
local hir = require("@structures/hir")
local lir = require("@structures/lir")
local attributes = require("@config/attributes")

local fn = require("@builders/fn")

local context = require("@lir/build/context")
local ty_builder = require("@builders/ty")

local types = require("../types")

type TyBuilder = types.TyBuilder
type ReadProps = types.ReadProps
type WriteProps = types.WriteProps

type Builder = fn.Builder
type Context = context.Context
type Attributes = attributes.TypeAttributes

type Ty = ty.Ty
type TyId = ty.TyId
type GenericType = ty.GenericType

type LValue<T> = lir.LValue<T>
type RValue<T> = lir.RValue<T>
type Register<T> = lir.RegisterId<T>


local function props_with_generics(base_props: ReadProps | WriteProps, generic_type: GenericType): ReadProps | WriteProps
    local args: {TyId} = {}
    local generics = base_props.generics
    
    for index, generic_id in generic_type.args do
        local generic_ty = hir.ty_from_id(base_props.ctx.hir, generic_id)
        if generic_ty.kind == "generic" and generics then
            generic_id = generics[generic_ty.index]
        end

        args[index] = generic_id
    end
    
    local new_props = table.clone(base_props)
    new_props.generics = args
    
    return new_props
end

local function build_read(props: ReadProps, block: Builder, generic_type: GenericType): Register<any>
    local new_props = props_with_generics(props, generic_type) :: ReadProps
    return ty_builder.read_ty(new_props, block, generic_type.def)
end

local function build_write(props: WriteProps, block: Builder, generic_type: GenericType, value: RValue<any>): ()
    local new_props = props_with_generics(props, generic_type) :: WriteProps
    ty_builder.write_ty(new_props, block, generic_type.def, value)
end

return table.freeze({
    read = build_read,
    write = build_write,
})