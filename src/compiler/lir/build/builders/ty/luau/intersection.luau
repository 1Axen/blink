--!strict

local ty = require("@structures/ty")
local lir = require("@structures/lir")
local hir = require("@structures/hir")
local attributes = require("@config/attributes")

local fn = require("@builders/fn")
local control = require("@builders/control")
local wrapper = require("@builders/wrapper")
local library = require("@builders/library")
local constant = require("@builders/constant")
local condition = require("@builders/condition")
local projection = require("@builders/projection")
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

local function build_read(props: ReadProps, block: Builder, intersection: Intersection): Register<any>
    local register: Register<any> = block:store(wrapper.table({}))

    local left_ty = hir.ty_from_id(props.ctx.hir, intersection.left)
    local right_ty = hir.ty_from_id(props.ctx.hir, intersection.right)

    ty_builder.read(props, block, left_ty, register)
    ty_builder.read(props, block, right_ty, register)

    return register
end

local function build_write(props: WriteProps, block: Builder, intersection: Intersection, value: RValue<any>): ()
    local left_ty = hir.ty_from_id(props.ctx.hir, intersection.left)
    local right_ty = hir.ty_from_id(props.ctx.hir, intersection.right)

    ty_builder.write(props, block, left_ty, value)
    ty_builder.write(props, block, right_ty, value)
end

return table.freeze({
    read = build_read,
    write = build_write,
})