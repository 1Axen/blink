local lookup = require("@hir/lookup")
local ty = require("@ty")
local types = require("@hir/types")

type Ty = ty.Ty
type TyId<T = Ty> = ty.TyId<T>

type Hir = types.Hir
type Context = {
	read hir: Hir,
	read cache: { [Ty]: Ty? },
	read encountered: { [Ty]: true? },
}

local function transform<T>(ctx: Context, input: Ty): Ty
	const cache = ctx.cache
	const encountered = ctx.encountered

	const cached = cache[input]
	if cached then
		return cached
	end

	if encountered[input] then
		return input
	end

	encountered[input] = true

	const output = (function(): Ty
		if input.kind == "map" then
			local index = transform(ctx, input.index)
			local value = transform(ctx, input.value)
			if index ~= input.index or value ~= input.value then
				return ty.map(input.node, index, value, input.size)
			end
		elseif input.kind == "array" then
			local of = transform(ctx, input.of)
			if input.of ~= of then
				return ty.array(input.node, of)
			end
		elseif input.kind == "struct" then
			local fields = table.clone(input.fields)
			local invalidated = false
			for index, field in fields do
				local value = transform(ctx, field.value)
				if value ~= field.value then
					invalidated = true
					fields[index] = ty.field(field.node, field.name, value)
				end
			end

			if invalidated then
				return ty.struct(input.node, fields)
			end
		elseif input.kind == "union" then
			local components = table.clone(input.components)
			local invalidated = false
			for index, component in components do
				local transformed = transform(ctx, component)
				if transformed ~= component then
					invalidated = true
					components[index] = transformed
				end
			end

			if invalidated then
				return ty.union(input.node, components)
			end
		elseif input.kind == "discriminated_union" then
			local variants = table.clone(input.variants)
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
				return ty.discriminated_union(input.node, input.tag, variants)
			end
		elseif input.kind == "type_instantiation" then
			local body = transform(ctx, input.body)
			if input.body ~= body then
				return ty.type_instantiation(input.node, input.type_function, input.arguments, body)
			end
		elseif input.kind == "reference" then
			local to = lookup.ty_from_id(ctx.hir, input.to)
			return transform(ctx, to)
		end

		return input
	end)()

	cache[input] = output
	return output
end

local function dereference(hir: Hir)
	local tys = hir.tys
	for ty_id, tty in tys do
		local context: Context = {
			hir = hir,
			cache = {},
			encountered = {},
		}
		tys[ty_id] = transform(context, tty)
	end
end

return table.freeze({
	dereference = dereference,
})
