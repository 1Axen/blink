local ty = require("@ty")
local types = require("@hir/types")

type Ty = ty.Ty
type TyId<T = Ty> = ty.TyId<T>

type Hir = types.Hir
type Context = {
	read hir: Hir,
	read encountered: { [Ty]: true? },
}

local function transform(ctx: Context, tty: Ty): Ty
	local encountered = ctx.encountered
	if encountered[tty] then
		return tty
	end

	encountered[tty] = true

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
		local queue = table.clone(tty.components)
		local new_components = table.create(#tty.components) :: typeof(tty.components)

		local invalidated = false
		local nil_inserted = false
		while true do
			local component = table.remove(queue)
			if component == nil then
				break
			end

			if component.kind == "union" then
				invalidated = true
				table.move(component.components, 1, #component.components, #queue + 1, queue)
				continue
			end

			local transformed = transform(ctx, component)
			if transformed ~= component then
				invalidated = true
			end

			if transformed.kind == "nil" then
				if nil_inserted then
					invalidated = true
					continue
				end

				nil_inserted = true
			end

			table.insert(new_components, transformed)
		end

		if invalidated then
			return ty.union(tty.node, new_components)
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
	elseif tty.kind == "type_instantiation" then
		local body = transform(ctx, tty.body)
		if tty.body ~= body then
			return ty.type_instantiation(tty.node, tty.type_function, tty.arguments, body)
		end
	elseif tty.kind == "reference" and tty.arguments then
		local arguments = table.clone(tty.arguments)
		local invalidated = false

		for index, argument in arguments do
			local new_argument = transform(ctx, argument)
			if argument ~= new_argument then
				invalidated = true
				arguments[index] = new_argument
			end
		end

		if invalidated then
			return ty.reference(tty.node, tty.to, arguments)
		end
	end

	return tty
end

local function flatten(hir: Hir)
	local tys = hir.tys
	for ty_id, tty in tys do
		local ctx: Context = {
			hir = hir,
			encountered = {},
		}

		tys[ty_id] = transform(ctx, tty)
	end
end

return table.freeze({
	flatten = flatten,
})
