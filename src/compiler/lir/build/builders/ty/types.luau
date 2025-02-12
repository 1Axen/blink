local ty = require("@structures/ty")
local lir = require("@structures/lir")
local attributes = require("@config/attributes")

local fn = require("@builders/fn")
local context = require("@lir/build/context")

type Ty = ty.Ty
type LValue = lir.LValue
type Register = lir.RegisterId

type Builder = fn.Builder
type Context = context.Context
type Attributes = attributes.TypeAttributes

export type TyBuilder = {
    build: {
        read: (ctx: Context, block: Builder, ty: Ty, attributes: Attributes) -> Register,
        write: (ctx: Context, block: Builder, ty: Ty, attributes: Attributes, at: LValue) -> ()
    },
    validate: {
        read: (ctx: Context, block: Builder, ty: Ty, at: LValue) -> (),
        write: (ctx: Context, block: Builder, ty: Ty, at: LValue) -> ()
    },
}

return nil