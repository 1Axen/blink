local attributes = require("@config/attributes")
local ty = require("@ty")
local types = require("@lir/types")

local context = require("@lir/build/context")
local fn = require("@builders/fn")

type Ty = ty.Ty
type TyId = ty.TyId
type LValue<T> = types.LValue<T>
type RValue<T> = types.RValue<T>
type Register<T> = types.RegisterId<T>

type Builder = fn.Builder
type Context = context.Context
type Attributes = attributes.Attributes

export type ReadProps = {
	ctx: Context,
	attributes: Attributes,
}

export type WriteProps = {
	ctx: Context,
	validate: boolean,
	attributes: Attributes,
}

export type Props = | ReadProps | WriteProps

export type TyBuilder = {
	read read: (props: ReadProps, block: Builder, ty: Ty, into: LValue<any>?) -> Register<any>,
	read write: (props: WriteProps, block: Builder, ty: Ty, value: RValue<any>) -> (),
}

return nil
