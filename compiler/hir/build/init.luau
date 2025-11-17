--!strict
--!native
--!optimize 2

local types = require("@config/compilation")

local ast = require("@ast/types")
local hir = require("@hir/types")
local ty = require("@ty/types")

local bounds = require("@config/bounds")
local primitives = require("@config/primitives")

local options = require("@config/options")
local panic = require("@util/panic")
local range = require("@util/range")
local symbols = require("@compiler/symbols")

local attributes = require("@self/attributes")
local report = require("@hir/report")
local strong_exhaustive_match = require("@util/strong_exhaustive_match")

type Ty = ty.Ty
type Decl = hir.Decl
type Node = ast.Node
type Hir = hir.Hir
type Ast = ast.Ast

type TyId<T = Ty> = ty.TyId<T>
type DeclId = hir.DeclId
type NodeId = ast.NodeId
type ScopeId = hir.ScopeId

type Range = range.Range
type Symbols = ast.Symbols

type Generics = {
	args: { TyId<ty.Generic> },
	values: { [string]: TyId<ty.Generic> },
}

type Context = {
	read hir: Hir,
	read file_id: number,
	read options: options.FileOptions,
	read options_declarations: { [string]: ast.StatOption },

	symbols: Symbols,
	scope_id: ScopeId,
	generics: Generics?,
}

local TY_PLACEHOLDER = ty.placeholder()

local expression: (ctx: Context, expr: ast.Expression, node_id: NodeId?, generics: Generics?) -> TyId<any>

local function path_to_segments(path: ast.Path): { string }
	local segments: { string } = {}
	for _, segment in path.segments do
		table.insert(segments, segment.value)
	end

	return segments
end

local function path_to_string(path: ast.Path): string
	return table.concat(path_to_segments(path), ".")
end

local function store_node(ctx: Context, node: Node): NodeId
	ctx.hir.nodes[node.id] = node
	return node.id
end

local function assert_identifier_one_of(ctx: Context, ident: ast.Identifier, valid: { string }): ast.Identifier
	local value = ident.value
	if table.find(valid, value) == nil then
		return report.expect_one_of(ident, valid, value)
	end

	return ident
end

--- Converts an ast `Range` node to a `Range` class
--- Range is validated to be within the `bounds` passed
local function range_node_to_range_class(node: ast.Range, bounds: Range): Range
	local max_node = node.max
	local min_node = node.min

	local max = max_node and max_node.value or bounds.max
	local min = min_node and min_node.value or bounds.min

	if max > bounds.max or min < bounds.min then
		return report.unrepresentable_range(node, bounds)
	end

	return range.create(min, max)
end

--> Luau Primitives

local function ty_string_literal(ctx: Context, expr: ast.ExprString): ty.StringLiteral
	return ty.string_literal(expr.value)
end

local function ty_number_literal(ctx: Context, expr: ast.ExprNumber): ty.NumberLiteral
	return ty.number_literal(expr.value)
end

local function ty_boolean_literal(ctx: Context, expr: ast.ExprBoolean): ty.BooleanLiteral
	return ty.boolean_literal(expr.value)
end

local function ty_numeral(ctx: Context, identifier: string, expr_range: ast.Range?): ty.Numeral
	local numeral: primitives.Primitive = (primitives :: any)[identifier]

	local size: ty.NumSize = string.sub(identifier, 2, 3) :: ty.NumSize
	local format: ty.NumFormat = string.sub(identifier, 1, 1) :: ty.NumFormat
	local range: Range?

	if expr_range then
		range = range_node_to_range_class(expr_range, numeral.range or primitives.f64.range)
	end

	return ty.numeral(size, format, range)
end

local function ty_string(ctx: Context, expr_range: ast.Range?): ty.String
	local bounds = primitives.string.range
	local length = if expr_range then range_node_to_range_class(expr_range, bounds) else nil
	return ty.string(length)
end

local function ty_buffer(ctx: Context, expr_range: ast.Range?): ty.Buffer
	local bounds = primitives.buffer.range
	local length = if expr_range then range_node_to_range_class(expr_range, bounds) else nil
	return ty.buffer(length)
end

local function ty_vector(ctx: Context, expr: ast.ExprReference): ty.Vector
	local expr_range = expr.range
	local expr_generics = expr.generics

	local magnitude: Range?
	if expr_range then
		magnitude = range_node_to_range_class(expr_range, primitives.vector.range)
	end

	local axes: { ty.Axis } = {}
	if expr_generics then
		local values = expr_generics.values
		if #values > 3 then
			return report.extra_generics(expr_generics, 3)
		end

		for index, value in values do
			axes[index] = expression(ctx, value) :: ty.Axis
		end
	end

	return ty.vector(axes, magnitude)
end

local function ty_boolean(ctx: Context): ty.Boolean
	return ty.boolean()
end

local function ty_unknown(ctx: Context): ty.Unknown
	return ty.unknown()
end

--> ROBLOX Primitives

local function ty_roblox_enum(ctx: Context, expr_generics: ast.GenericsArgs?): ty.Enum
	local enum_type: TyId<ty.StringLiteral>?
	if expr_generics then
		local values = expr_generics.values
		if #values > 1 then
			return report.extra_generics(expr_generics, 1)
		end

		local generic = values[1]
		enum_type = expression(ctx, generic) :: TyId<ty.StringLiteral>
	end

	return ty.roblox_enum(enum_type)
end

local function ty_color3(ctx: Context): ty.Color3
	return ty.color3()
end

local function ty_cframe(ctx: Context, expr_generics: ast.GenericsArgs?): ty.CFrame
	local generics: { TyId<ty.Numeral> } = {}
	if expr_generics then
		local values = expr_generics.values
		if #values > 2 then
			return report.extra_generics(expr_generics, 2)
		end

		for index, value in values do
			local ty_id = expression(ctx, value) :: TyId<ty.Numeral>
			generics[index] = ty_id
		end
	end

	return ty.cframe(generics[1], generics[2])
end

local function ty_date_time(ctx: Context): ty.DateTime
	return ty.date_time()
end

local function ty_date_time_millis(ctx: Context): ty.DateTimeMillis
	return ty.date_time_millis()
end

local function ty_brick_color(ctx: Context): ty.BrickColor
	return ty.brick_color()
end

local function ty_instance(ctx: Context, expr_generics: ast.GenericsArgs?): ty.Instance
	local class: TyId<ty.StringLiteral>?
	if expr_generics then
		local values = expr_generics.values
		if #values > 1 then
			return report.extra_generics(expr_generics, 1)
		end

		class = expression(ctx, values[1]) :: TyId<ty.StringLiteral>
	end

	return ty.instance(class)
end

--- Returns a `ty` from a `reference` **to a primitive (u8, string, buffer, etc.)**
local function ty_primitive(ctx: Context, expr: ast.ExprReference, path: string): Ty
	if
		path == "u8"
		or path == "u16"
		or path == "u24"
		or path == "u32"
		or path == "u48"
		or path == "i8"
		or path == "i16"
		or path == "i24"
		or path == "i32"
		or path == "i48"
		or path == "f16"
		or path == "f32"
		or path == "f64"
	then
		return ty_numeral(ctx, path, expr.range)
	elseif path == "string" then
		return ty_string(ctx, expr.range)
	elseif path == "buffer" then
		return ty_buffer(ctx, expr.range)
	elseif path == "vector" then
		return ty_vector(ctx, expr)
	elseif path == "boolean" then
		return ty_boolean(ctx)
	elseif path == "unknown" then
		return ty_unknown(ctx)
	elseif path == "Enum" then
		return ty_roblox_enum(ctx, expr.generics)
	elseif path == "CFrame" then
		return ty_cframe(ctx, expr.generics)
	elseif path == "Instance" then
		return ty_instance(ctx, expr.generics)
	elseif path == "Color3" then
		return ty_color3(ctx)
	elseif path == "DateTime" then
		return ty_date_time(ctx)
	elseif path == "BrickColor" then
		return ty_brick_color(ctx)
	elseif path == "DateTimeMillis" then
		return ty_date_time_millis(ctx)
	end

	return panic(`Unhandled primitive "{path}"`)
end

local function ty_map(ctx: Context, expr: ast.ExprMap): ty.Map
	local index = expression(ctx, expr.index)
	local value = expression(ctx, expr.value)

	local range: Range
	if expr.range then
		range = range_node_to_range_class(expr.range, bounds.map)
	end

	return ty.map(index, value, range)
end

local function ty_unit_enum(ctx: Context, expr: ast.ExprEnum): ty.UnitEnum
	local variants = {}
	for _, node in expr.variants do
		local variant = expression(ctx, node)
		table.insert(variants, variant)
	end

	return ty.unit_enum(variants)
end

local function ty_array(ctx: Context, expr: ast.ExprArray): ty.Array
	local of = expression(ctx, expr.value)
	local size: Range?
	if expr.range then
		size = range_node_to_range_class(expr.range, bounds.array)
	end

	return ty.array(of, size)
end

local function ty_field(ctx: Context, expr: ast.ExprField): ty.Field
	local name = expr.name.value
	local value = expression(ctx, expr.value)
	return ty.field(name, value)
end

local function ty_struct(ctx: Context, expr: ast.ExprStruct): ty.Struct
	local fields: { ty.Field } = {}
	for index, field in expr.fields do
		fields[index] = ty_field(ctx, field)
	end

	return ty.struct(fields)
end

local function ty_intersection(ctx: Context, expr: ast.ExprUnion): ty.Intersection
	local left = expression(ctx, expr.left) :: TyId<ty.IntersectionSide>
	local right = expression(ctx, expr.right) :: TyId<ty.IntersectionSide>
	return ty.intersection(left, right)
end

local function ty_optional(ctx: Context, expr: ast.ExprOptional): ty.Optional
	local of = expression(ctx, expr.value)
	return ty.optional(of)
end

local function ty_tagged_enum(ctx: Context, expr: ast.ExprTaggedEnum): ty.TaggedEnum
	local tag = expr.tag.value
	local variants: { ty.Variant } = {}
	for index, node in expr.variants do
		local key = expression(ctx, node.key) :: TyId<ty.Literal>
		local value = ty_struct(ctx, node.value)
		local variant = ty.variant(key, value)

		-- add tag field to variant struct
		local struct = variant.value
		table.insert(struct.fields, 1, ty.field(tag, key :: TyId))

		variants[index] = variant
	end

	return ty.tagged_enum(tag, variants)
end

--- Returns the `ty_id` of the `ty` referenced
local function ty_reference(ctx: Context, expr: ast.ExprReference, node_id: NodeId): Ty
	--[[
        Phases:
        1 - Check if the reference is a generic parameter, return the generic parameter if it is, otherwise Continue
        2 - Check whether the reference exists, continue if it does, otherwise report an unknown reference
        3 - If any generics were passed alongside the reference convert them into an array of corresponding ty's
        4 - If any generics were passed then check whether the referenced ty accepts generics, if it does then continue to 5.1, else report extra generics
        4.1 - Validate whether the exact amount of generics were passed, report too few or too many if not, else create a new ty (generic type) and return it
        5 - Return the referenced ty
    --]]

	-- Phase 1:
	if ctx.generics then
		local path_string = path_to_string(expr.path)
		local generic_ty_id = ctx.generics.values[path_string]
		if generic_ty_id then
			local node = hir.node_from_id(ctx.hir, node_id)
			if node.kind == "type" then
				return ty.generic_type(generic_ty_id :: TyId, { generic_ty_id :: TyId })
			end

			return hir.ty_from_id(ctx.hir, generic_ty_id)
		end
	end

	-- Phase 2:
	local path_segments = path_to_segments(expr.path)
	local decl_node = symbols.search(ctx.symbols, path_segments)
	if decl_node == nil or decl_node.kind ~= "type" then
		return report.unknown_reference(expr)
	end

	-- Phase 3:
	local generics: { TyId } = {}
	local expr_generics = expr.generics
	if expr_generics then
		for index, value in expr_generics.values do
			generics[index] = expression(ctx, value)
		end
	end

	local decl_id = decl_node.id :: DeclId
	local type_decl = hir.decl_from_id(ctx.hir, decl_id)

	-- Phase 4:
	local decl_generics = type_decl.generics
	if decl_generics then
		-- Phase 4.1:
		local n_decl_generics = #decl_generics
		if expr_generics == nil then
			return report.few_none_generics(expr.path, n_decl_generics)
		end

		local n_expr_generics = #expr_generics.values
		if n_expr_generics > n_decl_generics then
			return report.extra_generics(expr_generics, n_decl_generics)
		elseif n_expr_generics < n_decl_generics then
			return report.few_generics(expr_generics, n_decl_generics)
		end
	elseif expr_generics then
		return report.extra_generics(expr_generics, 0)
	end

	-- Phase 5:
	return ty.reference(type_decl.ty_id, generics)
end

function expression(
	ctx: Context,
	expr: ast.Expression | ast.Identifier,
	node_id: NodeId?,
	generics: Generics?
): TyId<Ty>
	node_id = node_id or store_node(ctx, expr)

	local tys = ctx.hir.tys
	local ty_id = node_id :: TyId
	tys[ty_id] = TY_PLACEHOLDER

	if generics ~= nil then
		ctx.generics = generics
	end

	--> process node
	local new_ty: Ty
	if expr.kind == "map" then
		new_ty = ty_map(ctx, expr)
	elseif expr.kind == "enum" then
		new_ty = ty_unit_enum(ctx, expr)
	elseif expr.kind == "array" then
		new_ty = ty_array(ctx, expr)
	elseif expr.kind == "union" then
		new_ty = ty_intersection(ctx, expr)
	elseif expr.kind == "string" then
		new_ty = ty_string_literal(ctx, expr)
	elseif expr.kind == "struct" then
		new_ty = ty_struct(ctx, expr)
	elseif expr.kind == "number" then
		new_ty = ty_number_literal(ctx, expr)
	elseif expr.kind == "boolean" then
		new_ty = ty_boolean_literal(ctx, expr)
	elseif expr.kind == "tagged_enum" then
		new_ty = ty_tagged_enum(ctx, expr)
	elseif expr.kind == "optional" then
		new_ty = ty_optional(ctx, expr)
	elseif expr.kind == "reference" then
		local path = path_to_string(expr.path)
		local primitive = (primitives :: { [string]: any? })[path]
		if primitive then
			new_ty = ty_primitive(ctx, expr, path)
		else
			new_ty = ty_reference(ctx, expr, node_id)
		end
	elseif expr.kind == "identifier" then
		new_ty = ty_string_literal(ctx, expr :: any)
	else
		return strong_exhaustive_match(expr.kind)
	end

	if generics then
		local expr_node_id = store_node(ctx, expr)
		local expr_ty_id = expr_node_id :: TyId

		tys[expr_ty_id] = new_ty
		new_ty = ty.generic_type(expr_ty_id, generics.args :: { TyId })

		ctx.generics = nil
	end

	--> store ty
	tys[ty_id] = new_ty

	return ty_id
end

local function expr_pack(ctx: Context, expr: ast.ExprPack): { hir.Parameter }
	local parameters: { hir.Parameter } = {}
	for index, expr in expr.values do
		local name = if expr.name then expr.name.value else nil
		local ty_id = expression(ctx, expr.value)
		local parameter: hir.Parameter = {
			name = name,
			ty_id = ty_id,
		}

		table.insert(parameters, parameter)
	end

	return parameters
end

local function stat_type(ctx: Context, stat: ast.StatType): hir.Type
	--> lower generics
	local args: { TyId<ty.Generic> }?
	if stat.generics then
		args = {}

		for index, value in stat.generics.values do
			local node_id = store_node(ctx, value)
			local ty_id = node_id :: TyId<ty.Generic>

			local name = value.name.value
			local generic = ty.generic(name, index)

			args[index] = ty_id
			ctx.hir.tys[ty_id :: TyId] = generic
		end
	end

	--> lower expression
	local node_id = store_node(ctx, stat)

	return {
		id = node_id :: DeclId,
		kind = "type",
		name = stat.name.value,
		scope_id = ctx.scope_id,
		attributes = attributes.from_nodes(stat.attributes),

		ty_id = node_id :: TyId,
		generics = args,
	}
end

local function stat_event(ctx: Context, stat: ast.StatEvent): hir.Event
	local name = stat.name.value
	local from =
		assert_identifier_one_of(ctx, stat.from, { "Client", "Server", "Both" }).value :: index<hir.Event, "from">
	local call = assert_identifier_one_of(
		ctx,
		stat.call,
		{ "ManySync", "SingleSync", "ManyAsync", "SingleAsync", "Polling" }
	).value :: index<hir.Event, "call">
	local reliability =
		assert_identifier_one_of(ctx, stat.type, { "Reliable", "Unreliable" }).value :: index<hir.Event, "type">

	return {
		id = stat.id :: DeclId,
		kind = "event",
		scope_id = ctx.scope_id,
		attributes = attributes.from_nodes(stat.attributes),

		name = name,
		from = from,
		type = reliability,
		call = call,
	}
end

local function stat_function(ctx: Context, stat: ast.StatFunction): hir.Function
	local name = stat.name.value
	local yield =
		assert_identifier_one_of(ctx, stat.yield, { "Coroutine", "Promise", "Future" }).value :: index<hir.Function, "yield">

	return {
		id = stat.id :: DeclId,
		kind = "function",
		scope_id = ctx.scope_id,
		attributes = attributes.from_nodes(stat.attributes),

		name = name,
		yield = yield,
	}
end

type Collection = {
	read types: { hir.Type },
	read events: { hir.Event },
	read functs: { hir.Function },
}

local function traverse_block(ctx: Context, block: ast.Block, prev_collection: Collection?): Collection
	local ctx_hir = ctx.hir
	local collection: Collection = prev_collection or {
		types = {},
		events = {},
		functs = {},
	}

	for _, stat in block.statements do
		local node_id = store_node(ctx, stat)
		local decl_id = node_id :: DeclId

		if stat.kind == "type" then
			local decl = stat_type(ctx, stat)
			ctx_hir.types[decl_id] = decl
			table.insert(collection.types, decl)
		elseif stat.kind == "event" then
			local decl = stat_event(ctx, stat)
			ctx_hir.events[decl_id] = decl
			table.insert(collection.events, decl)
		elseif stat.kind == "function" then
			local decl = stat_function(ctx, stat)
			ctx_hir.functs[decl_id] = decl
			table.insert(collection.functs, decl)
		elseif stat.kind == "scope" then
			local body = stat.body
			local name = stat.name.value
			local scope_id = stat.id :: ScopeId

			local prev_id = ctx.scope_id
			local symbols = symbols.child(ctx.symbols, name)
			if symbols == nil then
				panic(`expected previous scope to have symbols`)
			end

			ctx.scope_id = scope_id
			ctx_hir.scopes[scope_id] = symbols

			traverse_block(ctx, body, collection)
			ctx.scope_id = prev_id
		elseif stat.kind == "option" then
			local options_declarations = ctx.options_declarations

			local name = stat.name.value
			local existing_declaration = options_declarations[name]
			if existing_declaration then
				report.duplicate_option(stat, existing_declaration)
			end

			local option_config = options[name]
			if option_config == nil then
				report.unknown_option(stat)
			end

			local value_expr = stat.value
			if value_expr.kind ~= option_config.kind then
				report.invalid_option_type(stat, option_config.kind)
			end

			local value = value_expr.value
			if option_config.values and table.find(option_config.values, value) == nil then
				report.invalid_option_value(stat, option_config.values)
			end

			local file_options = ctx.options :: { [string]: any }
			file_options[name] = value
		end
	end

	return collection
end

local function switch_scope(ctx: Context, scope_id: ScopeId)
	if scope_id ~= ctx.scope_id then
		ctx.scope_id = scope_id
		ctx.symbols = ctx.hir.scopes[scope_id]
	end
end

local function build_tys(ctx: Context, collection: Collection)
	local hirr = ctx.hir

	for _, decl_type in collection.types do
		local decl_id = decl_type.id
		local node_id = decl_id :: NodeId
		local stat_node = hir.node_from_id(hirr, node_id) :: ast.StatType

		local generics: Generics?
		local decl_generics = decl_type.generics
		if decl_generics then
			local values: index<Generics, "values"> = {}
			for _, ty_id in decl_generics do
				local generic = hir.ty_from_id(hirr, ty_id)
				values[generic.name] = ty_id
			end

			generics = {
				args = decl_generics,
				values = values,
			}
		end

		switch_scope(ctx, decl_type.scope_id)
		expression(ctx, stat_node.value, node_id, generics)
	end

	for _, decl_event in collection.events do
		local node = hir.node_from_id(hirr, decl_event.id :: NodeId) :: ast.StatEvent
		if node.data == nil then
			continue
		end

		switch_scope(ctx, decl_event.scope_id)
		decl_event.data = expr_pack(ctx, node.data)
	end

	for _, decl_funct in collection.functs do
		local node = hir.node_from_id(hirr, decl_funct.id :: NodeId) :: ast.StatFunction
		if node.data ~= nil then
			switch_scope(ctx, decl_funct.scope_id)
			decl_funct.data = expr_pack(ctx, node.data)
		end

		if node.ret ~= nil then
			switch_scope(ctx, decl_funct.scope_id)
			decl_funct.ret = expr_pack(ctx, node.ret)
		end
	end
end

local function traverse_ast(hirr: Hir, file_id: number, ast: Ast)
	local scope_id = ast.body.id :: ScopeId
	local context: Context = {
		hir = hirr,

		options = {},
		options_declarations = {},

		symbols = ast.symbols,
		file_id = file_id,
		scope_id = ast.body.id :: ScopeId,
	}

	hirr.scopes[scope_id] = ast.symbols
	hirr.options[file_id] = context.options

	local collection = traverse_block(context, ast.body)
	build_tys(context, collection)
end

--[=[
    Constructs a HIR from the provided files map.
    @param `files` - A map of `file_id` to an `AST`. A `file_id` of **0** must always correspond to the **entry file**.
]=]
local function from_files(files: types.FilesMap): Hir
	local hirr: Hir = {
		tys = {},
		nodes = {},

		types = {},
		events = {},
		functs = {},
		scopes = {},

		options = {},
	}

	-- traverse file asts
	for file_id, file_ast in files do
		traverse_ast(hirr, file_id, file_ast)
	end

	return hirr
end

return table.freeze({
	from_files = from_files,
})
