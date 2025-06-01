local hir = require("@hir/types")
local lir = require("@lir/types")
local ty = require("@ty/types")

local attributes = require("@config/attributes")

local context = require("@lir/build/context")
local fn = require("@builders/fn")

local panic = require("@util/panic")

local types = require("@self/types")

local ty_set = require("@self/luau/set")
local ty_unit_enum = require("@self/luau/unit_enum")

local ty_boolean = require("@self/luau/boolean")
local ty_buffer = require("@self/luau/buffer")
local ty_literal = require("@self/luau/literal")
local ty_numeral = require("@self/luau/numeral")
local ty_string = require("@self/luau/string")
local ty_vector = require("@self/luau/vector")

local ty_brick_color = require("@self/roblox/brick_color")
local ty_cframe = require("@self/roblox/cframe")
local ty_color3 = require("@self/roblox/color3")
local ty_date_time = require("@self/roblox/date_time")
local ty_date_time_millis = require("@self/roblox/date_time_millis")
local ty_enum = require("@self/roblox/enum")
local ty_instance = require("@self/roblox/instance")
local ty_unknown = require("@self/roblox/unknown")

local fmt_id = require("@compiler/id/format")

type Ty = ty.Ty
type TyId = ty.TyId<Ty>

type LValue<T> = lir.LValue<T>
type RValue<T> = lir.RValue<T>
type Register<T> = lir.RegisterId<T>

type Builder = fn.Builder
type Context = context.Context
type Attributes = attributes.TypeAttributes

type TyBuilder = types.TyBuilder
type ReadProps = types.ReadProps
type WriteProps = types.WriteProps
type Props = types.Props

-- cyclical ty builders
local ty_map: TyBuilder?
local ty_array: TyBuilder?
local ty_struct: TyBuilder?
local ty_optional: TyBuilder?
local ty_tagged_enum: TyBuilder?
local ty_generic_type: TyBuilder?
local ty_intersection: TyBuilder?

local BUILDERS: { [ty.TyKind]: TyBuilder? } = {
	set = ty_set,
	unit_enum = ty_unit_enum,

	buffer = ty_buffer,
	string = ty_string,
	vector = ty_vector,
	numeral = ty_numeral,
	boolean = ty_boolean,

	string_literal = ty_literal,
	number_literal = ty_literal,
	boolean_literal = ty_literal,

	cframe = ty_cframe,
	color3 = ty_color3,
	unknown = ty_unknown,
	instance = ty_instance,
	date_time = ty_date_time,
	brick_color = ty_brick_color,
	roblox_enum = ty_enum,
	date_time_millis = ty_date_time_millis,
} :: any

local function import_cyclic()
	ty_map = (require :: any)("./luau/map")
	ty_array = (require :: any)("./luau/array")
	ty_struct = (require :: any)("./luau/struct")
	ty_optional = (require :: any)("./luau/optional")
	ty_tagged_enum = (require :: any)("./luau/tagged_enum")
	ty_generic_type = (require :: any)("./luau/generic_type")
	ty_intersection = (require :: any)("./luau/intersection")

	BUILDERS.map = ty_map
	BUILDERS.array = ty_array
	BUILDERS.struct = ty_struct
	BUILDERS.optional = ty_optional
	BUILDERS.tagged_enum = ty_tagged_enum
	BUILDERS.generic_type = ty_generic_type
	BUILDERS.intersection = ty_intersection
end

local function replace_generic(props: Props, generic: ty.Generic): Ty
	local generics = props.generics
	if generics == nil then
		return panic(`Tried to subsitute generic but type has no generics`)
	end

	local target_id = generics[generic.index]
	return hir.ty_from_id(props.ctx.hir, target_id)
end

local function try_replace_generic(props: Props, ty: Ty): Ty
	if ty.kind == "generic" then
		return replace_generic(props, ty)
	end

	return ty
end

local function builder_from_ty(ty: Ty): TyBuilder
	if ty_map == nil then
		import_cyclic()
	end

	local builder = BUILDERS[ty.kind]
	if builder == nil then
		return panic(`Unhandled ty kind: "{ty.kind}"`)
	end

	return builder
end

local function read_ty(props: ReadProps, block: Builder, ty: Ty, into: LValue<any>?): LValue<any>
	ty = try_replace_generic(props, ty)
	local builder = builder_from_ty(ty)
	return builder.read(props, block, ty, into)
end

local function write_ty(props: WriteProps, block: Builder, ty: Ty, value: RValue<any>)
	ty = try_replace_generic(props, ty)
	local builder = builder_from_ty(ty)
	builder.write(props, block, ty, value)
end

local function read_ty_id(props: ReadProps, block: Builder, ty_id: TyId, into: LValue<any>?)
	print(`Building reader for {fmt_id(ty_id)}`)
	local ty = hir.ty_from_id(props.ctx.hir, ty_id)
	return read_ty(props, block, ty, into)
end

local function write_ty_id(props: WriteProps, block: Builder, ty_id: TyId, value: RValue<any>)
	print(`Building writer for {fmt_id(ty_id)}`)
	local ty = hir.ty_from_id(props.ctx.hir, ty_id)
	write_ty(props, block, ty, value)
end

return table.freeze({
	read = read_ty_id,
	write = write_ty_id,
	read_ty = read_ty,
	write_ty = write_ty,
})
