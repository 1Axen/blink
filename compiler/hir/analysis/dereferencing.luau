local lookup = require("@hir/lookup")
local ty = require("@ty")
local types = require("@hir/types")

type Ty = ty.Ty
type TyId<T = Ty> = ty.TyId<T>

type Hir = types.Hir
type Context = {
	read hir: Hir,
	read encountered: { [Ty]: true? },
}

local function transform<T>(ctx: Context, tty: Ty): Ty
	local encountered = ctx.encountered
	if encountered[tty] then
		return tty
	end

	encountered[tty] = true

	if tty.kind == "map" then
		local index = transform(ctx, tty.index)
		local value = transform(ctx, tty.value)
		if index ~= tty.index or value ~= tty.value then
			return ty.map(index, value, tty.size)
		end
	elseif tty.kind == "array" then
		local of = transform(ctx, tty.of)
		if tty.of ~= of then
			return ty.array(of)
		end
	elseif tty.kind == "struct" then
		local fields = table.clone(tty.fields)
		local invalidated = false
		for index, field in fields do
			local value = transform(ctx, field.value)
			if value ~= field.value then
				invalidated = true
				fields[index] = ty.field(field.name, value)
			end
		end

		if invalidated then
			return ty.struct(fields)
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
			return ty.union(components)
		end
	elseif tty.kind == "discriminated_union" then
		local variants = table.clone(tty.variants)
		local invalidated = false
		for index, variant in variants do
			local key = transform(ctx, variant.key) :: typeof(variant.key)
			local value = transform(ctx, variant.value) :: typeof(variant.value)
			if key ~= variant.key or variant.value ~= value then
				invalidated = true
				variants[index] = ty.variant(key, value)
			end
		end

		if invalidated then
			return ty.discriminated_union(tty.tag, variants)
		end
	elseif tty.kind == "type_instantiation" then
		local body = transform(ctx, tty.body)
		if tty.body ~= body then
			return ty.type_instantiation(tty.type_function, tty.arguments, body)
		end
	elseif tty.kind == "reference" then
		local to = lookup.ty_from_id(ctx.hir, tty.to)
		if encountered[to] == nil then
			return transform(ctx, to)
		end
	end

	return tty
end

local function dereference(hir: Hir)
	local tys = hir.tys
	for ty_id, tty in tys do
		local context: Context = {
			hir = hir,
			encountered = {},
		}
		tys[ty_id] = transform(context, tty)
	end
end

return table.freeze({
	dereference = dereference,
})
