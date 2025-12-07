local context = require("./context")
local hir = require("@hir")
local panic = require("@util/panic")
local string_builder = require("@util/string_builder")
local strong_exhaustive_match = require("@util/strong_exhaustive_match")
local ty = require("@ty")

type Ty = ty.Ty
type Hir = hir.Hir
type StringBuilder = string_builder.StringBuilder

type Context = context.Context

local append_ty: (ctx: Context, tty: Ty) -> ()

local function append_map(ctx: Context, map: ty.Map)
	local builder = ctx.builder
	builder:append("{[")
	append_ty(ctx, map.index)
	builder:append("]: ")
	append_ty(ctx, map.value)
	builder:append("}")
end

local function append_array(ctx: Context, array: ty.Array)
	local builder = ctx.builder
	builder:append("{")
	append_ty(ctx, array.of)
	builder:append("}")
end

local function append_struct(ctx: Context, struct: ty.Struct)
	local builder = ctx.builder
	builder:append("{")
	for _, field in struct.fields do
		builder:append('["')
		builder:append(field.name)
		builder:append('"]: ')
		append_ty(ctx, field.value)
		builder:append(",")
	end
	builder:append("}")
end

-- local function append_optional(ctx: Context, optional: ty.Optional)
-- 	append_ty(ctx, optional.of)
-- 	ctx.builder:append("?")
-- end

local function append_union(ctx: Context, union: ty.Union)
	local builder = ctx.builder
	for index, component in union.components do
		if index > 1 then
			builder:append(" | ")
		end
		append_ty(ctx, component)
	end
end

local function append_string_literal(ctx: Context, literal: ty.StringLiteral)
	local builder = ctx.builder
	builder:append('"')
	builder:append(literal.value)
	builder:append('"')
end

local function append_enum(ctx: Context, enum: ty.Enum)
	local builder = ctx.builder
	builder:append("Enum")
	if enum.type then
		builder:append(".")
		builder:append(enum.type.value)
	end
end

local function append_instance(ctx: Context, instance: ty.Instance)
	local builder = ctx.builder
	if instance.class then
		builder:append(instance.class.value)
	else
		builder:append("Instance")
	end
end

local function append_reference(ctx: Context, reference: ty.Reference)
	local decl_id = reference.to :: hir.DeclId
	local type_decl = hir.decl_from_id(ctx.hir, decl_id)
	if type_decl.kind ~= "type" then
		panic(`expected reference ty id to map to a type decleration, got a "{type_decl.kind}" decleration instead`)
		error("never")
	end

	local builder = ctx.builder
	builder:append(type_decl.name)

	local arguments = reference.arguments
	if arguments then
		builder:append("<")
		for index, argument in arguments do
			if index > 1 then
				builder:append(", ")
			end

			append_ty(ctx, argument)
		end
		builder:append(">")
	end
end

local function append_discriminated_union(ctx: Context, union: ty.DiscriminatedUnion)
	local builder = ctx.builder
	for index, variant in union.variants do
		if index > 1 then
			builder:append(" | ")
		end
		append_struct(ctx, variant.value)
	end
end

local function append_type_instantiation(ctx: Context, instantiation: ty.TypeInstantiation)
	local function_decl_id = instantiation.type_function :: hir.DeclId
	local function_type_decl = hir.decl_from_id(ctx.hir, function_decl_id)
	if function_type_decl.kind ~= "type" then
		panic(
			`expected instantiation type function to map to a type decleration, got a "{function_type_decl.kind}" decleration instead`
		)
		error("never")
	end

	local builder = ctx.builder
	builder:append(function_type_decl.name)

	local arguments = instantiation.arguments
	if arguments then
		builder:append("<")
		for index, argument in arguments do
			if index > 1 then
				builder:append(", ")
			end

			append_ty(ctx, argument)
		end
		builder:append(">")
	end
end

function append_ty(ctx: Context, tty: Ty)
	if tty.kind == "map" then
		append_map(ctx, tty)
	elseif tty.kind == "nil" then
		ctx.builder:append("nil")
	elseif tty.kind == "array" then
		append_array(ctx, tty)
	elseif tty.kind == "struct" then
		append_struct(ctx, tty)
	elseif tty.kind == "union" then
		append_union(ctx, tty)
	elseif tty.kind == "blocked" then
		panic("cannot append blocked type")
	elseif tty.kind == "generic" then
		ctx.builder:append(tty.name)
	elseif tty.kind == "numeral" then
		ctx.builder:append("number")
	elseif tty.kind == "string" then
		ctx.builder:append("string")
	elseif tty.kind == "buffer" then
		ctx.builder:append("buffer")
	elseif tty.kind == "vector" then
		ctx.builder:append("vector")
	elseif tty.kind == "boolean" then
		ctx.builder:append("boolean")
	elseif tty.kind == "string_literal" then
		append_string_literal(ctx, tty)
	elseif tty.kind == "number_literal" then
		ctx.builder:append("number")
	elseif tty.kind == "boolean_literal" then
		ctx.builder:append(tostring(tty.value))
	elseif tty.kind == "roblox_enum" then
		append_enum(ctx, tty)
	elseif tty.kind == "cframe" then
		ctx.builder:append("CFrame")
	elseif tty.kind == "color3" then
		ctx.builder:append("Color3")
	elseif tty.kind == "instance" then
		append_instance(ctx, tty)
	elseif tty.kind == "date_time" then
		ctx.builder:append("DateTime")
	elseif tty.kind == "date_time_millis" then
		ctx.builder:append("DateTimeMillis")
	elseif tty.kind == "brick_color" then
		ctx.builder:append("BrickColor")
	elseif tty.kind == "unknown" then
		ctx.builder:append("unknown")
	elseif tty.kind == "reference" then
		append_reference(ctx, tty)
	elseif tty.kind == "type_instantiation" then
		append_type_instantiation(ctx, tty)
	elseif tty.kind == "discriminated_union" then
		append_discriminated_union(ctx, tty)
	elseif tty.kind == "type_function" then
		append_ty(ctx, tty.body)
	else
		strong_exhaustive_match(tty.kind)
	end
end

return append_ty
