--!strict
--!native
--!optimize 2

local id = require("@compiler/id")

local ast = require("@ast/types")
local codes = require("@config/codes")
local options = require("@config/options")
local primitives = require("@config/primitives")

local diagnostics = require("@util/diagnostics")
local panic = require("@util/panic")
local range = require("@util/range")
local symbols = require("@util/symbols")

local fmt_ast = require("@ast/format")

local report = require("./report")

type Ast = ast.Ast
type Range = range.Range
type Literal = string | number | boolean
export type Symbols = symbols.Symbols<ast.Statement>

type Context = {
	symbols: Symbols,
}

local DUMMY_ID = id.DUMMY_ID

local block: (ctx: Context, block: ast.Block, name: string) -> ()
local statement: (ctx: Context, statement: ast.Statement) -> ()
local expression: (ctx: Context, expression: ast.Expression) -> ()

local function as_literal(expr: ast.Expression): Literal | never
	if expr.kind == "string" then
		return expr.value :: string
	elseif expr.kind == "number" then
		return expr.value :: number
	elseif expr.kind == "boolean" then
		return expr.value :: boolean
	end

	return diagnostics.report
		.create("Error")
		.with_code(codes.parser.SyntaxError)
		.with_message(`Expected one of string, number, boolean; got "{expr.kind}" instead`)
		.with_label(
			diagnostics.label
				.create((expr :: ast.Expression).span)
				.with_color(diagnostics.style.color.red)
				.with_message("Expected one of string, number, boolean")
		)
		.finish()
		.error()
end

local function assert_id(node: ast.Node)
	if node.id == DUMMY_ID then
		panic(`AST node [{fmt_ast.node(node)}] wasn't assigned an id`)
	end
end

local function expr_range(ctx: Context, range: ast.Range): ast.Range
	local min = range.min
	local max = range.max

	local max_value = max and max.value or 0
	local min_value = min and min.value or max_value

	if min_value > max_value then
		return report.invalid_range(range)
	end

	return range
end

local function expr_reference(ctx: Context, expr: ast.ExprReference): never?
	local range = expr.range
	local generics = expr.generics

	if generics then
		for index, generic in generics.values do
			expression(ctx, generic)
		end
	end

	if range then
		range = expr_range(ctx, range)
	end

	return nil
end

local function expr_set(ctx: Context, expr: ast.ExprSet): never?
	local entries: { [string]: report.Entry } = {}
	for _, entry in expr.values do
		local previous = entries[entry.value]
		if previous then
			return report.duplicate_entry(expr, previous, entry)
		end

		entries[entry.value] = entry
	end

	return nil
end

local function expr_map(ctx: Context, expr: ast.ExprMap): never?
	expression(ctx, expr.index)
	expression(ctx, expr.value)
	return nil
end

local function expr_pack(ctx: Context, expr: ast.ExprPack): never?
	for _, value in expr.values do
		expression(ctx, value.value)
	end

	return nil
end

local function expr_enum(ctx: Context, expr: ast.ExprEnum): never?
	local variants: { [string]: report.Entry } = {}
	for _, variant in expr.variants do
		local value = variant.value
		local previous = variants[value]
		if previous ~= nil then
			return report.duplicate_entry(expr, previous, variant)
		end

		variants[value] = variant
	end

	return nil
end

local function expr_struct(ctx: Context, expr: ast.ExprStruct): never?
	local fields: { [string]: report.Entry } = {}
	for _, field in expr.fields do
		local name = field.name
		local value = name.value
		local previous = fields[value]

		if previous ~= nil then
			return report.duplicate_entry(expr, previous, name)
		end

		fields[value] = name
		expression(ctx, field.value)
	end

	return nil
end

local function expr_union(ctx: Context, expr: ast.ExprUnion)
	expression(ctx, expr.left)
	expression(ctx, expr.right)
end

local function expr_array(ctx: Context, expr: ast.ExprArray)
	expression(ctx, expr.value)
end

local function expr_optional(ctx: Context, expr: ast.ExprOptional)
	expression(ctx, expr.value)
end

local function expr_tagged_enum(ctx: Context, expr: ast.ExprTaggedEnum): never?
	local tag = expr.tag
	local variants = {}

	for _, variant in expr.variants do
		-- check for duplicate variants
		local key = variant.key
		local str_name = tostring(key.value)

		local previous = variants[str_name]
		if previous ~= nil then
			return report.duplicate_entry(expr, previous, key)
		end

		variants[str_name] = key

		-- check for tag field
		for _, field in variant.value.fields do
			if field.name.value == tag.value then
				return report.tagged_enum_tag_in_variant(tag, field)
			end
		end

		-- validate the variants struct
		expr_struct(ctx, variant.value)
	end

	return nil
end

local function expr_pack_or_single(ctx: Context, expr: ast.Expression | ast.ExprPack)
	if expr.kind == "pack" then
		expr_pack(ctx, expr)
	else
		expression(ctx, expr)
	end
end

local function stat_type(ctx: Context, stat: ast.StatType): never?
	local name = stat.name
	local value = stat.value
	local primitive = (primitives :: any)[name.value]

	if stat.generics then
		for _, generic in stat.generics.values do
			assert_id(generic)
		end
	end

	if primitive ~= nil then
		return diagnostics.report
			.create("Error")
			.with_code(codes.analysis.ReservedIdentifier)
			.with_message(`Cannot use reserved identifier "{name.value}"`)
			.with_label(
				diagnostics.label
					.create(name.span)
					.with_color(diagnostics.style.color.red)
					.with_message(`Change identifier`)
			)
			.finish()
			.error()
	end

	--> replace expression if needed (resolved reference)
	expression(ctx, value)

	return nil
end

local function stat_event(ctx: Context, stat: ast.StatEvent)
	local data = stat.data
	if data ~= nil then
		expr_pack_or_single(ctx, data)
	end
end

local function stat_import(ctx: Context, stat: ast.StatImport): never?
	local path = stat.path
	local path_string = path.value

	do
		-- @ or ./
		local prefix_first = string.sub(path_string, 1, 1)
		if prefix_first ~= "@" and prefix_first ~= "." then
			return report.import_prefix(path, prefix_first)
		end

		-- ../ or ./
		if prefix_first == "." then
			local prefix_second = string.sub(path_string, 2, 2)
			if prefix_second ~= "." and prefix_second ~= "/" then
				return report.import_prefix(path, prefix_second)
			end
		end
	end

	do
		-- name.*
		local path_extension: string = string.match(path_string, "[%s%w%p]+%.[%w%p]+$") :: string
		if path_extension then
			return report.import_extension(path, path_extension)
		end
	end

	return nil
end

local function stat_option(ctx: Context, stat: ast.StatOption): never?
	local name = stat.name
	local value = stat.value

	local opt_config = options[name.value]
	if opt_config == nil then
		return diagnostics.report
			.create("Error")
			.with_code(codes.analysis.UnknownOption)
			.with_message(`Unknown option "{name.value}"`)
			.with_label(
				diagnostics.label
					.create(name.span)
					.with_color(diagnostics.style.color.red)
					.with_message(`"{name.value}" is not a valid option`)
			)
			.finish()
			.error()
	end

	if value.kind ~= opt_config.kind then
		return diagnostics.report
			.create("Error")
			.with_code(codes.analysis.InvalidOption)
			.with_message(`Option "{name}" expects a value of kind "{opt_config.kind}"`)
			.with_label(
				diagnostics.label
					.create(value.span)
					.with_color(diagnostics.style.color.red)
					.with_message(`Expected a value of kind "{opt_config.kind}", got "{value.kind}" instead`)
			)
			.finish()
			.error()
	end

	local literal = as_literal(value)
	if opt_config.values and table.find(opt_config.values, literal) == nil then
		local possible_values = `"{table.concat(opt_config.values, '", ')}"`
		return diagnostics.report
			.create("Error")
			.with_code(codes.analysis.InvalidOption)
			.with_message(`Option "{name}" expects one of {possible_values}`)
			.with_label(
				diagnostics.label
					.create(value.span)
					.with_color(diagnostics.style.color.red)
					.with_message(`Replace with one of {possible_values}`)
			)
			.finish()
			.error()
	end

	return nil
end

local function stat_function(ctx: Context, stat: ast.StatFunction)
	local data = stat.data
	if data ~= nil then
		expr_pack_or_single(ctx, data)
	end

	local ret = stat.ret
	if ret ~= nil then
		expr_pack_or_single(ctx, ret)
	end
end

function expression(ctx: Context, expr: ast.Expression)
	assert_id(expr)

	if expr.kind == "map" then
		expr_map(ctx, expr)
	elseif expr.kind == "set" then
		expr_set(ctx, expr)
	elseif expr.kind == "array" then
		expr_array(ctx, expr)
	elseif expr.kind == "enum" then
		expr_enum(ctx, expr)
	elseif expr.kind == "struct" then
		expr_struct(ctx, expr)
	elseif expr.kind == "union" then
		expr_union(ctx, expr)
	elseif expr.kind == "tagged_enum" then
		expr_tagged_enum(ctx, expr)
	elseif expr.kind == "optional" then
		expr_optional(ctx, expr)
	elseif expr.kind == "reference" then
		expr_reference(ctx, expr :: any)
	end
end

function statement(ctx: Context, stat: ast.Statement)
	assert_id(stat)

	if stat.kind == "type" then
		stat_type(ctx, stat)
	elseif stat.kind == "event" then
		stat_event(ctx, stat)
	elseif stat.kind == "scope" then
		block(ctx, stat.body, (stat.name :: ast.Identifier).value)
	elseif stat.kind == "option" then
		stat_option(ctx, stat)
	elseif stat.kind == "import" then
		stat_import(ctx, stat)
	elseif stat.kind == "function" then
		stat_function(ctx, stat)
	end

	local name = stat.name
	if name == nil then
		return
	end

	local existing = symbols.search(ctx.symbols, { name.value })
	if existing ~= nil then
		report.shadow(name, existing.name :: ast.Identifier)
	end

	if stat.kind ~= "scope" then
		symbols.set(ctx.symbols, name.value, stat)
	end
end

function block(ctx: Context, block: ast.Block, name: string?)
	assert_id(block)

	--> inner symbols
	local parent = ctx.symbols
	if name then
		ctx.symbols = symbols.inner(parent, name)
	end

	for _, stat in block.statements do
		statement(ctx, stat)
	end

	--> restore symbols
	ctx.symbols = parent
end

local function validate(ast: Ast)
	local ctx: Context = {
		symbols = ast.symbols,
	}

	block(ctx, ast.body)
end

return table.freeze({
	validate = validate,
})
