--!strict
--!native
--!optimize 2

local validator = require("@self/validator")

local ast = require("@ast/types")
local id = require("@compiler/id")
local lexer = require("@compiler/lexer")

local diagnostics = require("@util/diagnostics")
local file = require("@util/file")
local panic = require("@util/panic")
local span = require("@util/span")
local symbols = require("@util/symbols")

local report = require("@self/report")
local strong_exhaustive_match = require("@util/strong_exhaustive_match")

type Token = lexer.Token
type TokenAny = lexer.TokenBase<any>
type TokenKind = lexer.TokenKind

type Context = {
	read tokens: { Token },

	read file: file.File,
	read node_index: number,

	index: number,
	token: Token,
	lookahead: Token,

	attributes: { ast.Attribute },
}

local DUMMY_ID = id.DUMMY_ID
local ROOT_SYMBOLS = ""

local block: (Context, boolean) -> ast.Block
local statement: (Context) -> ast.Statement
local expression: (Context) -> ast.Expression

local function next_node_id(ctx: Context): ast.NodeId
	local index = ctx.node_index
	ctx.node_index += 1
	return id.node_id.create(ctx.file.id, index)
end

local function peek(ctx: Context): Token
	return ctx.token
end

local function peek_kind(ctx: Context): TokenKind
	return peek(ctx).kind
end

local function lookahead(ctx: Context): Token
	return ctx.lookahead
end

local function consume(ctx: Context): Token
	local token = ctx.token
	local index = ctx.index
	local tokens = ctx.tokens

	local size = #tokens
	local next_index = math.min(index + 1, size)
	local lookahead_index = math.min(index + 2, size)

	ctx.index = next_index
	ctx.token = ctx.lookahead
	ctx.lookahead = tokens[lookahead_index]

	return token
end

local function consume_attributes(ctx: Context): { ast.Attribute }
	local attributes = ctx.attributes
	ctx.attributes = {}
	return attributes
end

local function expect<T>(ctx: Context, kind: T & TokenKind): lexer.TokenBase<T>
	local token = peek(ctx)
	if token.kind == kind :: any then
		return consume(ctx) :: any
	end

	return report.expect(token, kind)
end

local function seperated<T>(ctx: Context, t: (Context) -> T, seperator: TokenKind, delimiter: "}" | ")" | "]" | ">"): { T }
	local list: { T } = {}

	while peek_kind(ctx) ~= delimiter do
		table.insert(list, t(ctx))

		--> if the next token isn't the seperator assume the list ended
		if peek_kind(ctx) ~= seperator then
			break
		end

		--> consume the seperator
		consume(ctx)
	end

	return list
end

local function path_segment(ctx: Context): ast.PathSegment
	local word = expect(ctx, "word")
	return {
		kind = "segment",
		span = word.span,
		value = span.value(word.span),
	}
end

--- Parses word + dot as identifier (foo.bar)
local function path(ctx: Context): ast.Path
	local segments: { ast.PathSegment } = {}
	local path_span: span.Span?

	while true do
		local segment = path_segment(ctx)
		table.insert(segments, segment)
		path_span = if path_span then span.merge(path_span, segment.span) else segment.span

		--> end of path
		if peek_kind(ctx) ~= "." then
			break
		end

		--> consume dot
		expect(ctx, ".")
	end

	return {
		id = next_node_id(ctx),
		kind = "path",
		span = path_span :: vector,
		segments = segments,
	}
end

local function identifier(ctx: Context): ast.Identifier
	local word = expect(ctx, "word")
	return {
		id = next_node_id(ctx),
		span = word.span,
		kind = "identifier",
		value = span.value(word.span),
	}
end

--- Parses anything as an identifier
local function any_identifier(ctx: Context): ast.Identifier
	local token = consume(ctx)
	return {
		id = next_node_id(ctx),
		span = token.span,
		kind = "identifier",
		value = span.value(token.span),
	}
end

local function structure(
	ctx: Context,
	fields: { [string]: { expr: (ctx: Context) -> any, optional: boolean } },
	open: lexer.TokenBase<any>
): { [string]: any }
	--> key - required
	local all_keys: { string } = {}
	local parsed_keys: { [string]: report.Entry } = {}
	local required_keys: { string } = {}

	for key, value in fields do
		if value.optional == false then
			table.insert(required_keys, key)
		end

		table.insert(all_keys, key)
	end

	local result: { [string]: ast.Expression } = {}

	while true do
		local name = any_identifier(ctx)
		local key = name.value

		local previous = parsed_keys[key]
		if previous ~= nil then
			return report.duplicate_entry_early(previous, name)
		end

		local field = fields[key]
		if field == nil then
			report.expect_one_of_ident(name.span, key, all_keys)
		end

		local _assign = expect(ctx, ":")
		local value = field.expr(ctx)

		result[key] = value
		parsed_keys[key] = name

		local index = table.find(required_keys, key)
		if index then
			table.remove(required_keys, index)
		end

		--> assume end of structure
		if peek_kind(ctx) ~= "," then
			break
		end

		expect(ctx, ",")
	end

	local close = peek(ctx)
	if #required_keys ~= 0 then
		return report.missing_entries(span.merge(open.span, close.span), required_keys)
	end

	return result
end

local function generic(ctx: Context): ast.GenericDef
	local name = identifier(ctx)
	local node_span = name.span

	return {
		id = next_node_id(ctx),
		kind = "generic",
		span = node_span,
		name = name,
	}
end

local function generics(ctx: Context): ast.GenericsDef
	local open = expect(ctx, "<")
	local values: { ast.GenericDef } = seperated(ctx, generic, ",", ">")
	local close = expect(ctx, ">")

	return {
		kind = "generics",
		span = span.merge(open.span, close.span),
		values = values,
	}
end

local function expr_boolean(ctx: Context): ast.ExprBoolean
	local token = consume(ctx)
	if token.kind == "true" then
		return {
			id = DUMMY_ID,
			span = token.span,
			kind = "boolean",
			value = true,
		}
	elseif token.kind == "false" then
		return {
			id = DUMMY_ID,
			span = token.span,
			kind = "boolean",
			value = false,
		}
	end

	return report.expect_one_of(token, { "true", "false" })
end

local function expr_number(ctx: Context): ast.ExprNumber
	local number = expect(ctx, "number")
	local value = span.value(number.span)
	local literal = tonumber(value)

	if literal == nil then
		return panic(`Unable to cast "{value}" to number`)
	end

	return {
		id = DUMMY_ID,
		span = number.span,
		kind = "number",
		value = literal,
	}
end

local function expr_string(ctx: Context): ast.ExprString
	local str = expect(ctx, "string")
	return {
		id = DUMMY_ID,
		span = str.span,
		kind = "string",
		value = span.value(str.span),
	}
end

local function string_or_identifier(ctx: Context): ast.Identifier | ast.ExprString
	local token = peek(ctx)
	local kind = token.kind
	if kind ~= "word" and kind ~= "string" then
		return report.expect_one_of(token, { "word", "string" })
	end

	if kind == "string" then
		return expr_string(ctx)
	elseif kind == "word" then
		return identifier(ctx)
	else
		return strong_exhaustive_match(kind)
	end
end

local function expr_literal(ctx: Context): ast.ExprLiteral
	local token = peek(ctx)
	if token.kind == "string" then
		return expr_string(ctx)
	elseif token.kind == "number" then
		return expr_number(ctx)
	elseif token.kind == "true" or token.kind == "false" then
		return expr_boolean(ctx)
	end

	return report.expect_one_of(token, { "string", "number", "true", "false" })
end

local function expr_range(ctx: Context): ast.Range
	local min: ast.ExprNumber
	local max: ast.ExprNumber

	local first = peek(ctx)
	if first.kind == "number" then
		min = expr_number(ctx)

		local second = peek(ctx)
		if second.kind == ".." then
			expect(ctx, "..")
			max = expr_number(ctx)
		else
			-- exact range
			max = min
		end
	elseif first.kind == ".." then
		expect(ctx, "..")
		max = expr_number(ctx)
	else
		return report.expect_one_of(first, { "..", "number" })
	end

	return {
		id = next_node_id(ctx),
		span = span.merge((min or max).span, (max or min).span),
		kind = "range",
		max = max,
		min = min,
	}
end

local function expr_reference(ctx: Context): ast.ExprReference
	local path = path(ctx)
	local node_span = path.span

	--> generics
	local generics: ast.GenericsArgs?
	if peek_kind(ctx) == "<" then
		local open = expect(ctx, "<")
		local values = seperated(ctx, expression, ",", ">")

		local close = expect(ctx, ">")
		node_span = span.merge(path.span, close.span)
		generics = {
			span = span.merge(open.span, close.span),
			kind = "generics",
			values = values,
		}
	end

	--> range
	local range: ast.Range?
	if peek_kind(ctx) == "(" then
		expect(ctx, "(")
		range = expr_range(ctx)

		local close = expect(ctx, ")")
		node_span = span.merge(node_span, close.span)
	end

	return {
		id = DUMMY_ID,
		span = node_span,
		kind = "reference",
		path = path,
		range = range,
		generics = generics,
	}
end

local function expr_field(ctx: Context): ast.ExprField
	local name = string_or_identifier(ctx)
	expect(ctx, ":")
	local value = expression(ctx)

	return {
		id = DUMMY_ID,
		span = span.merge(name.span, value.span),
		kind = "field",
		name = name,
		value = value,
	}
end

local function expr_struct(ctx: Context): ast.ExprStruct
	local keyword = expect(ctx, "struct")
	expect(ctx, "{")

	local fields = seperated(ctx, expr_field, ",", "}")
	local close = expect(ctx, "}")

	return {
		id = DUMMY_ID,
		span = span.merge(keyword.span, close.span),
		kind = "struct",
		fields = fields,
	}
end

--- Bit annoying but needed for tagged enum variants
local function expr_inlined_struct(ctx: Context): ast.ExprStruct
	local open = expect(ctx, "{")
	local fields = seperated(ctx, expr_field, ",", "}")
	local close = expect(ctx, "}")

	return {
		id = DUMMY_ID,
		span = span.merge(open.span, close.span),
		kind = "struct",
		fields = fields,
	}
end

local function expr_map(ctx: Context): ast.ExprMap
	local keyword = expect(ctx, "map")

	--> open "{" delim
	expect(ctx, "{")

	--> index
	expect(ctx, "[")
	local index = expression(ctx)
	expect(ctx, "]")

	--> value
	expect(ctx, ":")
	local value = expression(ctx)

	--> close delim
	expect(ctx, "}")

	local range: ast.Range?
	if peek_kind(ctx) == "(" then
		expect(ctx, "(")
		range = expr_range(ctx)
		expect(ctx, ")")
	end

	return {
		id = DUMMY_ID,
		span = span.merge(keyword.span, value.span),
		kind = "map",
		index = index,
		value = value,
		range = range,
	}
end

local function expr_set(ctx: Context): ast.ExprSet
	local keyword = expect(ctx, "set")
	expect(ctx, "{")

	local values = seperated(ctx, string_or_identifier, ",", "}")
	local close = expect(ctx, "}")

	return {
		id = DUMMY_ID,
		span = span.merge(keyword.span, close.span),
		kind = "set",
		values = values,
	}
end

local function expr_enum_tag_variant(ctx: Context): ast.ExprTaggedEnumVariant
	--> variant name
	local key
	local token = peek(ctx)

	if token.kind == "true" or token.kind == "false" then
		key = expr_boolean(ctx)
	elseif token.kind == "string" then
		key = expr_string(ctx)
	elseif token.kind == "number" then
		key = expr_number(ctx)
	else
		key = identifier(ctx)
	end

	--> struct
	local value = expr_inlined_struct(ctx)

	return {
		id = DUMMY_ID,
		span = span.merge(key.span, value.span),
		kind = "variant",

		key = key,
		value = value,
	}
end

local function expr_enum(ctx: Context): ast.ExprEnum | ast.ExprTaggedEnum
	local keyword = expect(ctx, "enum")

	local function unit(): ast.ExprEnum
		expect(ctx, "{")

		local variants = seperated(ctx, string_or_identifier, ",", "}")
		local close = expect(ctx, "}")

		return {
			id = DUMMY_ID,
			span = span.merge(keyword.span, close.span),
			kind = "enum",
			variants = variants,
		}
	end

	local function tagged(): ast.ExprTaggedEnum
		local tag = expr_string(ctx)
		expect(ctx, "{")

		local variants = seperated(ctx, expr_enum_tag_variant, ",", "}")
		local close = expect(ctx, "}")

		return {
			id = DUMMY_ID,
			span = span.merge(keyword.span, close.span),
			kind = "tagged_enum",

			tag = tag,
			variants = variants,
		}
	end

	local tag = peek(ctx)
	if tag.kind == "string" then
		return tagged()
	end

	return unit()
end

local function expr_pack_parameter(ctx: Context): ast.ExprPackParameter
	local name: ast.Identifier?
	local following = lookahead(ctx)
	if following.kind == ":" then
		name = any_identifier(ctx)
		local _ = expect(ctx, ":")
	end

	local value = expression(ctx)
	local full_span = name and span.merge(name.span, value.span) or value.span

	return {
		id = DUMMY_ID,
		span = full_span,
		kind = "parameter",

		name = name,
		value = value,
	}
end

local function expr_pack(ctx: Context): ast.ExprPack
	local open = expect(ctx, "(")
	local values = seperated(ctx, expr_pack_parameter, ",", ")")
	local close = expect(ctx, ")")

	return {
		id = DUMMY_ID,
		span = span.merge(open.span, close.span),
		kind = "pack",

		values = values,
	}
end

local function expr_pack_single(ctx: Context): ast.ExprPack
	local value = expression(ctx)
	local parameter: ast.ExprPackParameter = {
		id = DUMMY_ID,
		span = value.span,
		kind = "parameter",
		name = nil,
		value = value,
	}

	return {
		id = DUMMY_ID,
		span = value.span,
		kind = "pack",
		values = { parameter },
	}
end

local function expr_array(ctx: Context, of: ast.Expression): ast.ExprArray
	local range: ast.Range

	local open = expect(ctx, "[")
	local node_span = open.span

	local lookahead_kind = peek_kind(ctx)
	if lookahead_kind == ".." or lookahead_kind == "number" then
		range = expr_range(ctx, "[")
	end

	local close = expect(ctx, "]")
	node_span = span.merge(node_span, close.span)

	return {
		id = DUMMY_ID,
		span = node_span,
		kind = "array",

		range = range,
		value = of,
	}
end

local function expr_union(ctx: Context, left: ast.Expression, right: ast.Expression): ast.ExprUnion
	return {
		id = DUMMY_ID,
		span = span.merge(left.span, right.span),
		kind = "union",
		left = left,
		right = right,
	}
end

local function expr_optional(ctx: Context, of: ast.Expression): ast.ExprOptional
	local optional = expect(ctx, "?")
	return {
		id = DUMMY_ID,
		span = span.merge(of.span, optional.span),
		kind = "optional",
		value = of,
	}
end

--- Parses a single expression or a pack of expressions
local function expr_pack_or_single(ctx: Context): ast.ExprPack
	local token = peek(ctx)
	if token.kind == "(" then
		return expr_pack(ctx)
	end

	return expr_pack_single(ctx)
end

local function attribute(ctx: Context): ast.Attribute
	local at = expect(ctx, "@")
	local name = any_identifier(ctx)
	local node_span = span.merge(at.span, name.span)

	local args: { ast.ExprLiteral } = {}
	if peek_kind(ctx) == "(" then
		local _open = expect(ctx, "(")
		args = seperated(ctx, expr_literal, ",", ")")

		local close = expect(ctx, ")")
		node_span = span.merge(node_span, close.span)
	end

	return {
		kind = "attribute",
		span = node_span,
		name = name,
		args = args,
	}
end

local function stat_type(ctx: Context): ast.StatType
	local attributes = consume_attributes(ctx)

	local keyword = expect(ctx, "type")
	local name = identifier(ctx)

	local generics = if peek_kind(ctx) == "<" then generics(ctx) else nil

	local _assign = expect(ctx, "=")
	local value = expression(ctx)

	return {
		id = DUMMY_ID,
		span = span.merge(keyword.span, value.span),
		kind = "type",
		attributes = attributes,

		name = name,
		value = value,
		generics = generics,

		export = false,
	}
end

local function stat_event(ctx: Context): ast.StatEvent
	local attributes = consume_attributes(ctx)

	local keyword = expect(ctx, "event")
	local name = identifier(ctx)
	local open = expect(ctx, "{")

	local event_structure = structure(ctx, {
		from = { expr = identifier, optional = false },
		type = { expr = identifier, optional = false },
		call = { expr = identifier, optional = false },
		poll = { expr = expr_boolean, optional = true },
		data = { expr = expr_pack_or_single, optional = true },
	}, open)

	local close = expect(ctx, "}")

	return {
		id = DUMMY_ID,
		span = span.merge(keyword.span, close.span),
		kind = "event",
		attributes = attributes,

		name = name,
		from = event_structure.from,
		type = event_structure.type,
		call = event_structure.call,
		poll = event_structure.poll,
		data = event_structure.data,
	}
end

local function stat_scope(ctx: Context): ast.StatScope
	local keyword = expect(ctx, "scope")
	local name = identifier(ctx)

	local _open = expect(ctx, "{")
	local scope_block = block(ctx, true)
	local close = expect(ctx, "}")

	return {
		id = DUMMY_ID,
		span = span.merge(keyword.span, close.span),
		kind = "scope",

		name = name,
		body = scope_block,
	}
end

local function stat_option(ctx: Context): ast.StatOption
	local keyword = expect(ctx, "option")
	local name = identifier(ctx)

	local _assign = expect(ctx, "=")
	local value = expression(ctx)
	local stat_span = span.merge(keyword.span, value.span)

	return {
		id = DUMMY_ID,
		span = stat_span,
		kind = "option",

		name = name,
		value = value,
	}
end

local function stat_function(ctx: Context): ast.StatFunction
	local attributes = consume_attributes(ctx)

	local keyword = expect(ctx, "function")
	local name = identifier(ctx)
	local open = expect(ctx, "{")

	local function_structure = structure(ctx, {
		yield = { expr = identifier, optional = false },
		data = { expr = expr_pack_or_single, optional = true },
		["return"] = { expr = expr_pack_or_single, optional = true },
	}, open)

	local close = expect(ctx, "}")

	return {
		id = DUMMY_ID,
		span = span.merge(keyword.span, close.span),
		kind = "function",
		attributes = attributes,

		name = name,
		yield = function_structure.yield,
		data = function_structure.data,
		ret = function_structure["return"],
	}
end

local function stat_import(ctx: Context): ast.StatImport
	local keyword = expect(ctx, "import")

	local path = expr_string(ctx)
	local full_span = span.merge(keyword.span, path.span)

	local name: ast.Identifier?
	local token = peek(ctx)
	if token.kind == "as" then
		expect(ctx, "as")
		name = identifier(ctx)
		full_span = span.merge(full_span, name.span)
	end

	return {
		id = DUMMY_ID,
		span = full_span,
		kind = "import",
		name = name,
		path = path,
	}
end

local function try_wrap_in_optional(ctx: Context, expr: ast.Expression): ast.Expression
	local token = peek(ctx)
	if token.kind ~= "?" then
		return expr
	end

	local node_id = next_node_id(ctx)
	expr = expr_optional(ctx, expr)
	expr.id = node_id

	return expr
end

function expression(ctx: Context): ast.Expression
	local token = peek(ctx)
	local expr: ast.Expression
	local node_id = next_node_id(ctx)

	if token.kind == "word" then
		expr = expr_reference(ctx)
	elseif token.kind == "map" then
		expr = expr_map(ctx)
	elseif token.kind == "set" then
		expr = expr_set(ctx)
	elseif token.kind == "enum" then
		expr = expr_enum(ctx)
	elseif token.kind == "struct" then
		expr = expr_struct(ctx)
	elseif token.kind == "number" then
		expr = expr_number(ctx)
	elseif token.kind == "string" then
		expr = expr_string(ctx)
	elseif token.kind == "true" or token.kind == "false" then
		expr = expr_boolean(ctx)
	end

	if expr == nil then
		return report.expect_one_of(token, { "word", "string", "number", "true", "false" })
	end

	-- assign node id
	expr.id = node_id

	while peek_kind(ctx) == "[" do
		--> array
		local array_node_id = next_node_id(ctx)
		expr = expr_array(ctx, expr)
		expr.id = array_node_id

		--> optional
		expr = try_wrap_in_optional(ctx, expr)
	end

	--> optional
	expr = try_wrap_in_optional(ctx, expr)

	--> merge
	if peek_kind(ctx) == "&" then
		consume(ctx)

		-- reserve node id
		local union_node_id = next_node_id(ctx)

		local right = expression(ctx)
		expr = expr_union(ctx, expr, right)
		expr.id = union_node_id
	end

	return expr
end

function statement(ctx: Context): ast.Statement
	local stat: ast.Statement?
	local token = peek(ctx)
	local node_id = next_node_id(ctx)

	if token.kind == "type" then
		stat = stat_type(ctx)
	elseif token.kind == "import" then
		stat = stat_import(ctx)
	elseif token.kind == "scope" then
		stat = stat_scope(ctx)
	elseif token.kind == "event" then
		stat = stat_event(ctx)
	elseif token.kind == "option" then
		stat = stat_option(ctx)
	elseif token.kind == "function" then
		stat = stat_function(ctx)
	end

	if stat == nil then
		return report.expect_one_of(token, { "type", "scope", "event", "struct", "function" })
	end

	--TODO: Remove
	assert(stat, "luau type solver issue")

	-- assign node id
	stat.id = node_id

	-- validate attributes
	if #ctx.attributes > 0 then
		return report.invalid_attribute_placement(stat)
	end

	--TODO: Remove cast
	return stat :: ast.Statement
end

function block(ctx: Context, is_scope: boolean?): ast.Block
	local node_id = next_node_id(ctx)
	local statements: { ast.Statement } = {}
	local opening_token = peek(ctx)

	while true do
		local token = peek(ctx)
		if token.kind == "eof" then
			break
		end

		--> end of scope
		if is_scope and token.kind == "}" then
			break
		end

		--> attributes
		if token.kind == "@" then
			table.insert(ctx.attributes, attribute(ctx))
			continue
		end

		table.insert(statements, statement(ctx))
	end

	local closing_token = peek(ctx)
	local block_span = span.merge(opening_token.span, closing_token.span)

	return {
		id = node_id,
		kind = "block",
		span = block_span,
		statements = statements,
	}
end

--- Returns an AST constructed from `tokens`, errors if invalid syntax is encountered
local function parse(file: file.File, tokens: { lexer.Token }): ast.Ast
	assert(#tokens > 0, "Tokens are empty")
	assert(tokens[#tokens] and tokens[#tokens].kind == "eof", "Final token should be eof")

	local ctx: Context = {
		tokens = tokens,

		file = file,
		node_index = 0,

		index = 1,
		token = tokens[1],
		lookahead = tokens[2] or tokens[1],

		attributes = {},
	}

	local ast: ast.Ast = {
		kind = "ast",
		body = block(ctx),
		symbols = symbols.create(ROOT_SYMBOLS) :: symbols.Symbols<ast.Statement>,
	}

	validator.validate(ast)

	return ast
end

--TODO: Remove
diagnostics.set_error_fn(function(text: string)
	require("@lune/stdio").ewrite(`{text}\n`)
	return error("something went wrong")
end)

return table.freeze({
	parse = parse,
})
