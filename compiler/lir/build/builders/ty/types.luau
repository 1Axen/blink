local attributes = require("@config/attributes")
local lir = require("@lir/types")
local ty = require("@ty/types")

local context = require("@lir/build/context")
local fn = require("@builders/fn")

type Ty = ty.Ty
type TyId = ty.TyId
type LValue<T> = lir.LValue<T>
type RValue<T> = lir.RValue<T>
type Register<T> = lir.RegisterId<T>

type Builder = fn.Builder
type Context = context.Context
type Attributes = attributes.Attributes

export type ReadProps = {
	ctx: Context,
	generics: { TyId }?,
	-- This is an ugly hack for instances
	is_optional: boolean?,
	attributes: Attributes,
}

export type WriteProps = {
	ctx: Context,
	generics: { TyId }?,
	validate: boolean,
	attributes: Attributes,
}

export type Props = | ReadProps | WriteProps

export type TyBuilder = {
	read read: (props: ReadProps, block: Builder, ty: Ty, into: LValue<any>?) -> Register<any>,
	read write: (props: WriteProps, block: Builder, ty: Ty, value: RValue<any>) -> (),
}

return nil
