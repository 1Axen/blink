local lookup = require("@hir/lookup")
local panic = require("@util/panic")
local ty = require("@ty")
local types = require("@hir/types")

type Ty = ty.Ty
type TyId<T = Ty> = ty.TyId<T>
type TypeInstantiation = ty.TypeInstantiation

type Hir = types.Hir

type Arguments = { Ty }
type Context = {
	read hir: Hir,
	read cache: { [string]: TypeInstantiation? },
	arguments: Arguments,
}

local function hash(body: Ty, arguments: { Ty }): string
	local segments = table.create(#arguments + 1, "")
	for index, ty in { body, unpack(arguments) } do
		segments[index] = tostring(ty)
	end
	return table.concat(segments, "+")
end

local function transform(ctx: Context, tty: Ty): Ty
	local hir = ctx.hir
	local arguments = ctx.arguments
	local instantiation_cache = ctx.cache

	if tty.kind == "map" then
		local index = transform(ctx, tty.index)
		local value = transform(ctx, tty.value)
		if index ~= tty.index or value ~= tty.value then
			return ty.map(tty.node, index, value, tty.size)
		end
	elseif tty.kind == "array" then
		local of = transform(ctx, tty.of)
		if tty.of ~= of then
			return ty.array(tty.node, of)
		end
	elseif tty.kind == "struct" then
		local fields = table.clone(tty.fields)
		local invalidated = false
		for index, field in fields do
			local value = transform(ctx, field.value)
			if value ~= field.value then
				invalidated = true
				fields[index] = ty.field(field.node, field.name, value)
			end
		end

		if invalidated then
			return ty.struct(tty.node, fields)
		end
	elseif tty.kind == "union" then
		local components = table.clone(tty.components)
		local invalidated = false
		for index, component in components do
			local transformed = transform(ctx, component)
			if transformed ~= component then
				invalidated = true
				components[index] = transformed
			end
		end

		if invalidated then
			return ty.union(tty.node, components)
		end
	elseif tty.kind == "discriminated_union" then
		local variants = table.clone(tty.variants)
		local invalidated = false
		for index, variant in variants do
			local key = transform(ctx, variant.key) :: typeof(variant.key)
			local value = transform(ctx, variant.value) :: typeof(variant.value)
			if key ~= variant.key or variant.value ~= value then
				invalidated = true
				variants[index] = ty.variant(variant.node, key, value)
			end
		end

		if invalidated then
			return ty.discriminated_union(tty.node, tty.tag, variants)
		end
	elseif tty.kind == "generic" then
		local generic = arguments[tty.index]
		if generic == nil then
			panic(`Generic {tty.name}:{tty.index} was not supplied`)
		end

		return generic
	elseif tty.kind == "reference" then
		local to_ty_id = tty.to
		local to_ty = lookup.ty_from_id(hir, to_ty_id)
		if to_ty.kind == "type_function" then
			local reference_arguments = tty.arguments
			if reference_arguments == nil then
				return panic("Expected reference to a type function to have arguments")
			end

			local new_arguments = table.create(#reference_arguments) :: Arguments
			for index, argument in reference_arguments do
				new_arguments[index] = transform(ctx, argument)
			end

			local instantiation_hash = hash(to_ty.body, new_arguments)
			local existing_instantiation = instantiation_cache[instantiation_hash]
			if existing_instantiation then
				return existing_instantiation
			end

			local type_instantiation = ty.type_instantiation(tty.node, to_ty_id, new_arguments, ty.blocked())
			instantiation_cache[instantiation_hash] = type_instantiation

			ctx.arguments = new_arguments
			type_instantiation.body = transform(ctx, to_ty.body)
			ctx.arguments = arguments

			return type_instantiation
		end
	elseif tty.kind == "vector" then
		local axes = { tty.x, tty.y, tty.z }
		local invalidated = false
		for index, axis in axes do
			-- TODO: Remove cast once iteration refines nil
			assert(axis)

			local transformed = transform(ctx, axis) :: ty.Axis
			if axis ~= transformed then
				invalidated = true
				axes[index] = transformed
			end
		end

		if invalidated then
			return ty.vector(tty.node, axes, tty.magnitude)
		end
	elseif tty.kind == "cframe" then
		local position = tty.position
		local new_position = position
		if position then
			new_position = transform(ctx, position) :: typeof(position)
		end

		local rotation = tty.rotation
		local new_rotation = rotation
		if rotation then
			new_rotation = transform(ctx, rotation) :: typeof(rotation)
		end

		if position ~= new_position or rotation ~= new_rotation then
			return ty.cframe(tty.node, new_position, new_rotation)
		end
	elseif tty.kind == "instance" and tty.class then
		local class = tty.class
		local new_class = transform(ctx, class) :: typeof(class)
		if new_class ~= class then
			return ty.instance(tty.node, new_class)
		end
	elseif tty.kind == "roblox_enum" and tty.type then
		local enum_type = tty.type
		local new_enum_type = transform(ctx, enum_type) :: typeof(enum_type)
		if new_enum_type ~= enum_type then
			return ty.roblox_enum(tty.node, new_enum_type)
		end
	end

	return tty
end

local function instantiate(hir: Hir)
	local tys = hir.tys
	for ty_id, tty in tys do
		local ctx: Context = {
			hir = hir,
			cache = {},
			arguments = {},
		}

		tys[ty_id] = transform(ctx, tty)
	end
end

return table.freeze({
	instantiate = instantiate,
})
