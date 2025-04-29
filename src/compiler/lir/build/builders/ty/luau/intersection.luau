--!strict

local ty = require("@structures/ty")
local lir = require("@structures/lir")
local attributes = require("@config/attributes")

local fn = require("@builders/fn")
local structure = require("@builders/structure")
local ty_builder = require("@builders/ty")

local context = require("@lir/build/context")

local types = require("@builders/ty/types")

type ReadProps = types.ReadProps
type WriteProps = types.WriteProps

type Builder = fn.Builder
type Context = context.Context
type Attributes = attributes.TypeAttributes

type Intersection = ty.Intersection
type LValue<T> = lir.LValue<T>
type RValue<T> = lir.RValue<T>
type Register<T> = lir.RegisterId<T>

local function build_read(props: ReadProps, block: Builder, intersection: Intersection, into: LValue<any>?): Register<any>
    local register: Register<any> = block:store(structure.struct({}))

    ty_builder.read(props, block, intersection.left :: ty.TyId, register)
    ty_builder.read(props, block, intersection.right :: ty.TyId, register)

    if into then
        return block:store(register, into)
    end

    return register
end

local function build_write(props: WriteProps, block: Builder, intersection: Intersection, value: RValue<any>): ()
    ty_builder.write(props, block, intersection.left :: ty.TyId, value)
    ty_builder.write(props, block, intersection.right :: ty.TyId, value)
end

return table.freeze({
    read = build_read,
    write = build_write,
})