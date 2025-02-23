local ty = require("@structures/ty")
local lir = require("@structures/lir")
local attributes = require("@config/attributes")

local fn = require("@builders/fn")
local context = require("@lir/build/context")

type Ty = ty.Ty
type RValue<T> = lir.RValue<T>
type Register<T> = lir.RegisterId<T>

type Builder = fn.Builder
type Context = context.Context
type Attributes = attributes.TypeAttributes

export type ReadProps = {
    ctx: Context,
    attributes: Attributes,
}

export type WriteProps = {
    ctx: Context,
    validate: boolean,
    attributes: Attributes,
}

export type TyBuilder = {
    read read: (props: ReadProps, block: Builder, ty: Ty) -> Register<any>,
    read write: (props: WriteProps, block: Builder, ty: Ty, value: RValue<any>) -> ()
}

return nil