local attributes = require("@config/attributes")
local binary = require("@builders/binary")
local condition = require("@builders/condition")
local constant = require("@builders/constant")
local context = require("@lir/build/context")
local conversion = require("@util/conversion")
local fn = require("@builders/fn")
local globals = require("@builders/globals")
local hir = require("@hir/types")
local length = require("@builders/ty/luau/length")
local library = require("@builders/library")
local lir = require("@lir/types")
local panic = require("@util/panic")
local prefixes = require("@config/prefixes")
local projection = require("@builders/projection")
local structure = require("@builders/structure")
local ternary = require("@builders/ternary")
local ty = require("@ty/types")
local ty_literal = require("@self/luau/literal")
local ty_numeral = require("@self/luau/numeral")
local types = require("@self/types")
local unary = require("@builders/unary")

type Ty = ty.Ty
type TyId = ty.TyId<Ty>

type LValue<T> = lir.LValue<T>
type RValue<T> = lir.RValue<T>
type Register<T> = lir.RegisterId<T>

type Builder = fn.Builder
type Context = context.Context
type Attributes = attributes.Attributes

type TyBuilder = types.TyBuilder
type ReadProps = types.ReadProps
type WriteProps = types.WriteProps
type Props = types.Props

local OPTIONAL_FORMAT = ty_numeral.u8

local function replace_generic(props: Props, generic: ty.Generic): Ty
	local generics = props.generics
	if generics == nil then
		return panic(`Tried to subsitute generic but type has no generics`)
	end

	local target_id = generics[generic.index]
	if target_id == nil then
		return panic(`Generic "{generic.name}" is uninhabited`)
	end

	return hir.ty_from_id(props.ctx.hir, target_id)
end

local function try_replace_generic(props: Props, ty: Ty): Ty
	if ty.kind == "generic" then
		return replace_generic(props, ty)
	end

	return ty
end

local function initialize_generics(props: Props, generic_type: ty.GenericType): { TyId }
	local generics = {}
	local prop_generics = props.generics

	for index, ty_id in generic_type.args do
		local ty = hir.ty_from_id(props.ctx.hir, ty_id)
		if ty.kind == "generic" and prop_generics then
			ty_id = prop_generics[ty.index]
		end

		generics[index] = ty_id
	end

	return generics
end

local function props_with_generics(base_props: Props, generic_type: ty.GenericType): Props
	local new_props = table.clone(base_props)
	new_props.generics = initialize_generics(base_props, generic_type)
	return new_props
end

--TODO: Make value optional when the solver is stable
local builders: { [ty.TyKind]: TyBuilder }
local function builder_from_ty(ty: Ty): TyBuilder
	local builder = builders[ty.kind]
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

local function from_ty_id(ctx: Context, attributes: attributes.Attributes, ty_id: TyId, generics: { TyId }?): lir.FnSet
	do
		local existing = ctx.ty_fn_set_map[ty_id]
		if existing then
			return existing
		end
	end

	-- pre store the ids
	local read_fn_id = context.next_fn_id(ctx)
	local write_fn_id = context.next_fn_id(ctx)
	local fn_set: lir.FnSet = {
		read = read_fn_id,
		write = write_fn_id,
	}

	local hirr = ctx.hir
	local ty = hir.ty_from_id(hirr, ty_id)
	if ty.kind == "reference" then
		ty_id = ty.to
		generics = generics or ty.args
		ty = hir.ty_from_id(hirr, ty.to)
	end

	if ty.kind == "generic_type" then
		generics = generics or ty.args

		local hash = ty.body :: number
		for index, generic_ty_id: TyId in ty.args do
			local generic_ty = hir.ty_from_id(hirr, generic_ty_id)
			if generic_ty.kind == "generic" then
				generic_ty_id = generics[generic_ty.index]
			end

			hash += (index + 1) * (generic_ty_id :: number)
		end

		local existing = ctx.hashed_tys[hash]
		if existing then
			return existing
		end

		ctx.hashed_tys[hash] = fn_set
		ty = hir.ty_from_id(hirr, ty.body)
	end

	ctx.ty_fn_set_map[ty_id] = fn_set

	-- build reader & writer
	local name = tostring(ty_id)
	local decl = hirr.types[ty_id :: hir.DeclId]
	if decl ~= nil then
		name = decl.name
	end

	local read_name = projection.index(globals.types_map, constant.from_value(`{prefixes.ty}read_{name}`))
	local read_fn = fn.create(read_name, {}, { fn.rreturn(ty) }, function(block)
		local props: ReadProps = {
			ctx = ctx,
			generics = generics,
			attributes = attributes,
		}

		local value_register = read_ty(props, block, ty)
		block:rreturn({ value_register })
	end)

	local write_name = projection.index(globals.types_map, constant.from_value(`{prefixes.ty}write_{name}`))
	local write_fn = fn.create(write_name, { fn.argument(ty) }, {}, function(block)
		local props: WriteProps = {
			ctx = ctx,
			validate = true,
			generics = generics,
			attributes = attributes,
		}

		write_ty(props, block, ty, block:argument(1))
	end)

	context.store_fn(ctx, read_fn, read_fn_id)
	context.store_fn(ctx, write_fn, write_fn_id)

	return fn_set
end

local function read_ty_id(props: ReadProps, block: Builder, ty_id: TyId, into: LValue<any>?): LValue<any>
	local tyy = hir.ty_from_id(props.ctx.hir, ty_id)
	if tyy.kind == "reference" then
		ty_id = tyy.to
		tyy = hir.ty_from_id(props.ctx.hir, tyy.to)
	end

	if ty.is_possibly_recursive(tyy) then
		local fn_set = from_ty_id(props.ctx, props.attributes, ty_id, props.generics)
		local register = into or block:reserve()
		block:call_fn(fn_set.read, {}, { register })
		return register
	end

	return read_ty(props, block, tyy, into)
end

local function write_ty_id(props: WriteProps, block: Builder, ty_id: TyId, value: RValue<any>)
	local tyy = hir.ty_from_id(props.ctx.hir, ty_id)
	if tyy.kind == "reference" then
		ty_id = tyy.to
		tyy = hir.ty_from_id(props.ctx.hir, tyy.to)
	end

	if ty.is_possibly_recursive(tyy) then
		local fn_set = from_ty_id(props.ctx, props.attributes, ty_id, props.generics)
		block:call_fn(fn_set.write, { value }, {})
	else
		write_ty(props, block, tyy, value)
	end
end

builders = {
	set = require("@self/luau/set"),
	unit_enum = require("@self/luau/unit_enum"),

	buffer = require("@self/luau/buffer"),
	string = require("@self/luau/string"),
	vector = require("@self/luau/vector"),
	numeral = ty_numeral,
	boolean = require("@self/luau/boolean"),

	string_literal = ty_literal,
	number_literal = ty_literal,
	boolean_literal = ty_literal,

	cframe = require("@self/roblox/cframe"),
	color3 = require("@self/roblox/color3"),
	unknown = require("@self/roblox/unknown"),
	instance = require("@self/roblox/instance"),
	date_time = require("@self/roblox/date_time"),
	brick_color = require("@self/roblox/brick_color"),
	roblox_enum = require("@self/roblox/enum"),
	date_time_millis = require("@self/roblox/date_time_millis"),

	map = table.freeze({
		read = function(props: ReadProps, block: Builder, map: ty.Map, into: LValue<any>?): Register<{ [any]: any }>
			local len = length.read(props, block, map)
			local register = block:store(structure.map({}))

			block:for_numeric(len, function(block)
				local key = read_ty_id(props, block, map.index)
				local value = read_ty_id(props, block, map.value)
				local map_index = projection.field(register, key)
				block:store(value, map_index)
			end)

			if into then
				return block:store(register, into)
			end

			return register
		end,
		write = function(props: WriteProps, block: Builder, map: ty.Map, at: RValue<{ [any]: any }>): ()
			local elements_register = block:store(constant.zero)
			local increase_elements = binary.add(elements_register, constant.one)
			block:for_generic(at, function(block)
				block:store(increase_elements, elements_register)
			end)

			length.write(props, block, map, elements_register)

			block:for_generic(at, function(block, key, value)
				write_ty_id(props, block, map.index, key)
				write_ty_id(props, block, map.value, value)
			end)
		end,
	}),

	array = table.freeze({
		read = function(props: ReadProps, block: Builder, array: ty.Array, into: LValue<any>?): Register<{ any }>
			local len = length.read(props, block, array)
			local register = block:store(library.table.create(len))

			block:for_numeric(len, function(block, index)
				local element = read_ty_id(props, block, array.of)
				local position = projection.field(register :: any, index)
				block:store(element, position)
			end)

			if into then
				return block:store(register, into)
			end

			return register
		end,
		write = function(props: WriteProps, block: Builder, array: ty.Array, value: RValue<{ any }>): ()
			length.write(props, block, array, unary.len(value :: any))
			block:for_generic(value :: any, function(block, _, value)
				write_ty_id(props, block, array.of, value)
			end)
		end,
	}),

	struct = table.freeze({
		read = function(props: ReadProps, block: Builder, struct: ty.Struct, into: LValue<any>?): Register<any>
			local register: Register<any> = block:store(structure.struct({}), into)
			for _, field in struct.fields do
				local name = field.name
				local struct_index = projection.field(register, constant.from_value(name))
				read_ty_id(props, block, field.value, struct_index)
			end

			return register
		end,

		write = function(props: WriteProps, block: Builder, struct: ty.Struct, value: RValue<any>): ()
			for _, field in struct.fields do
				local name = field.name
				local struct_index = projection.field(value :: LValue<any>, constant.from_value(name))
				local field_register = block:store(struct_index)
				write_ty_id(props, block, field.value, field_register)
			end
		end,
	}),

	optional = table.freeze({
		read = function(props: ReadProps, block: Builder, optional: ty.Optional, into: LValue<any>?)
			local byte_register = ty_numeral.read(props, block, OPTIONAL_FORMAT)
			local value_register = (into or block:reserve())

			local exists = condition.equals(byte_register, constant.one)
			block:if_single(exists, function(block)
				props.is_optional = true
				read_ty_id(props, block, optional.of, value_register)
				props.is_optional = false
			end)

			return value_register
		end,
		write = function(props: WriteProps, block: Builder, optional: ty.Optional, value: RValue<any>): ()
			local exists = condition.not_equals(value, constant.null)
			local cursor = block:allocate(constant.one)

			block:if_single(exists, function(block)
				write_ty_id(props, block, optional.of, value)
			end)

			local as_number = ternary(exists, constant.one, constant.zero)
			block:call(library.buffer.u8.write(cursor, as_number))
		end,
	}),

	tagged_enum = table.freeze({
		read = function(props: ReadProps, block: Builder, enum: ty.TaggedEnum, into: LValue<any>?)
			local variants = enum.variants
			local variants_count = #variants

			-- account for serdesing from 0
			local format = conversion.to_min_numeral(variants_count - 1)

			local value = into or block:reserve()
			local stored_value = ty_numeral.read(props, block, format)

			block:if_chain(variants_count + 1, function(index)
				if index > variants_count then
					local fallback = condition.equals(constant.truth, constant.truth)
					return fallback,
						function(block: Builder)
							block:call(library.error("Invalid enum variant"))
						end
				end

				local variant_value = variants[index].value
				local variant_index = constant.from_value(index - 1)

				local is_variant = condition.equals(stored_value, variant_index)
				return is_variant,
					function(block: Builder)
						builders.struct.read(props, block, variant_value, value)
					end
			end)

			return value
		end,
		write = function(props: WriteProps, block: Builder, enum: ty.TaggedEnum, value: RValue<any>): ()
			local ctx = props.ctx
			local variants = enum.variants
			local variants_count = #variants

			-- account for serdesing from 0
			local format = conversion.to_min_numeral(variants_count - 1)
			local tag_value = block:store(projection.field(value :: any, constant.from_value(enum.tag)))

			block:if_chain(variants_count + 1, function(index)
				if index > variants_count then
					local fallback = condition.equals(constant.truth, constant.truth)
					return fallback,
						function(block: Builder)
							block:call(library.error("Invalid enum variant"))
						end
				end

				local variant = variants[index]
				local variant_value = variant.value
				local variant_index = constant.from_value(index - 1)

				local key_ty = hir.ty_from_id(ctx.hir, variant.key)
				local is_variant = condition.equals(tag_value, constant.from_ty(key_ty :: any))

				return is_variant,
					function(block: Builder)
						ty_numeral.write(props, block, format, variant_index)
						builders.struct.write(props, block, variant_value, value)
					end
			end)
		end,
	}),

	generic_type = table.freeze({
		read = function(props: ReadProps, block: Builder, generic_type: ty.GenericType, into: LValue<any>?)
			local read_props = props_with_generics(props, generic_type) :: ReadProps
			return read_ty_id(read_props, block, generic_type.body, into)
		end,
		write = function(props: WriteProps, block: Builder, generic_type: ty.GenericType, value: RValue<any>): ()
			local write_props = props_with_generics(props, generic_type) :: WriteProps
			write_ty_id(write_props, block, generic_type.body, value)
		end,
	}),

	intersection = table.freeze({
		read = function(
			props: ReadProps,
			block: Builder,
			intersection: ty.Intersection,
			into: LValue<any>?
		): Register<any>
			local register: Register<any> = block:store(structure.struct({}))

			read_ty_id(props, block, intersection.left :: TyId, register)
			read_ty_id(props, block, intersection.right :: TyId, register)

			if into then
				return block:store(register, into)
			end

			return register
		end,
		write = function(props: WriteProps, block: Builder, intersection: ty.Intersection, value: RValue<any>): ()
			write_ty_id(props, block, intersection.left :: TyId, value)
			write_ty_id(props, block, intersection.right :: TyId, value)
		end,
	}),
}

return table.freeze({
	from_ty_id = from_ty_id,
})
