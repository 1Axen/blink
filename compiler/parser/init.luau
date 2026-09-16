--!strict
--!native
--!optimize 2

local ast = require("@ast")
local id = require("@compiler/id")
local lexer = require("@compiler/lexer")

local file = require("@util/file")
local panic = require("@util/panic")
local span = require("@util/span")

local assert_panic = require("@util/assert_panic")
local report = require("@compiler/report")

type Token = lexer.Token
type TokenAny = lexer.TokenBase<any>
type TokenKind = lexer.TokenKind
type TokenBase<T> = lexer.TokenBase<T>

type Context = {
	read tokens: { Token },

	read file: file.File,
	node_index: number,

	index: number,
	token: Token,
	lookahead: Token,

	attributes: { ast.Attribute },
}

local block: (Context, boolean) -> ast.Block
local statement: (Context) -> ast.Statement
local expression: (Context) -> ast.Expression

const function coerce<T>(x: T | ""): T
	return x
end

local function next_node_id(ctx: Context): ast.NodeId
	local index = ctx.node_index
	ctx.node_index += 1
	return id.create(ctx.file.id, index) :: ast.NodeId
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

const function consume_if_kind<T>(ctx: Context, kind: T & TokenKind): TokenBase<T>?
	if peek_kind(ctx) ~= kind then
		return nil
	end

	return consume(ctx)
end

local function consume_attributes(ctx: Context): { ast.Attribute }
	local attributes = ctx.attributes
	ctx.attributes = {}
	return attributes
end

local function expect<T>(ctx: Context, kind: T & TokenKind): TokenBase<T>
	local token = consume(ctx)
	if token.kind == kind then
		return token
	end

	return report.expect_token(token, kind)
end

const function expect_one_of<T>(ctx: Context, ...: T & TokenKind): TokenBase<T>
	const kinds = { ... }
	const token = consume(ctx)
	for _, kind in kinds do
		if kind == token.kind then
			return token
		end
	end

	return report.expect_token_one_of(token, kinds)
end

type OpenerCloserPairs = {
	["{"]: "}",
	["["]: "]",
	["("]: ")",
	["<"]: ">",
}

local function list<O, T, C>(
	ctx: Context,
	opener: O & keyof<OpenerCloserPairs>,
	value: (Context) -> T,
	separator: TokenKind,
	closer: C & index<OpenerCloserPairs, O>
): (TokenBase<O>, { T }, TokenBase<C>)
	const opener_token = expect(ctx, opener)

	const values: { T } = {}
	while peek_kind(ctx) ~= closer do
		table.insert(values, value(ctx))

		--> if the next token isn't the seperator assume the list ended
		if not consume_if_kind(ctx, separator) then
			break
		end
	end

	const closer_token = consume(ctx)
	if closer_token.kind ~= closer then
		report.expect_to_close(closer_token, opener_token :: Token, closer :: TokenKind)
	end

	return opener_token, values, closer_token
end

local function identifier(ctx: Context): ast.Identifier
	local token = expect_one_of(
		ctx,
		"as",
		"map",
		"word",
		"type",
		"from",
		"true",
		"false",
		"scope",
		"union",
		"event",
		"struct",
		"export",
		"import",
		"option",
		"function"
	)
	return {
		id = next_node_id(ctx),
		span = token.span,
		kind = "identifier",
		value = span.value(token.span),
	}
end

local function as_identifier(ctx: Context, token: Token): ast.Identifier
	return {
		id = next_node_id(ctx),
		span = token.span,
		kind = "identifier",
		value = span.value(token.span),
	}
end

--- Parses word + dot as identifier (foo.bar)
local function path(ctx: Context): ast.Path
	local segments: { ast.Identifier } = {}
	while true do
		table.insert(segments, identifier(ctx))

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
		span = span.merge(segments[1].span, segments[#segments].span),
		segments = segments,
	}
end

type Shape<T> = {
	read opener: Token,
	read closer: Token,
	read fields: TransformShapeLayout<T>,
}

type ShapeLayout = { [string]: { expr: (ctx: Context) -> any, optional: boolean } }

type function TransformShapeLayout(layout: type)
	const properties = {}
	for key, field in layout:properties() do
		const value = assert(field.read)
		const expr_func = assert(value:readproperty(types.singleton("expr")))
		const expr_type = assert(assert(expr_func:returns().head)[1])
		properties[key] = expr_type
	end

	return types.newtable(properties)
end

local function shape<T>(ctx: Context, layout: T & ShapeLayout): Shape<T>
	--> key - required
	local all_keys: { string } = {}
	local parsed_keys: { [string]: report.Entry } = {}
	local required_keys: { string } = {}

	for key, value in layout :: ShapeLayout do
		if value.optional == false then
			table.insert(required_keys, key)
		end

		table.insert(all_keys, key)
	end

	local opener = expect(ctx, "{")
	local fields: { [string]: any } = {}
	while peek_kind(ctx) ~= "}" do
		local name = identifier(ctx)
		local key = name.value

		local previous = parsed_keys[key]
		if previous ~= nil then
			return report.duplicate_entry(previous, name)
		end

		local field = layout[key]
		if field == nil then
			report.expect_string_one_of(name.span, key, all_keys)
		end

		local _assign = expect(ctx, ":")
		local value = field.expr(ctx)

		fields[key] = value
		parsed_keys[key] = name

		local index = table.find(required_keys, key)
		if index then
			table.remove(required_keys, index)
		end

		--> no comma, must be the end of the shape
		if not consume_if_kind(ctx, ",") then
			break
		end
	end

	local closer = consume(ctx)
	if closer.kind ~= "}" then
		return report.expect_to_close(closer, opener, "}")
	end

	if #required_keys ~= 0 then
		return report.missing_entries(span.merge(opener.span, closer.span), required_keys)
	end

	return table.freeze({
		opener = opener,
		closer = closer,
		fields = fields :: any,
	})
end

local function generic(ctx: Context): ast.GenericDef
	local node_id = next_node_id(ctx)
	local name = identifier(ctx)
	local node_span = name.span

	return {
		id = node_id,
		kind = "generic",
		span = node_span,
		name = name,
	}
end

local function generics(ctx: Context): ast.GenericsDef
	const opener, values, closer = list(ctx, "<", generic, ",", coerce(">"))
	return {
		kind = "generics",
		span = span.merge(opener.span, closer.span),
		values = values,
	}
end

local function expr_nil(ctx: Context): ast.ExprNil
	local token = expect(ctx, "nil")
	return {
		id = next_node_id(ctx),
		span = token.span,
		kind = "nil",
		value = nil,
	}
end

local function expr_boolean(ctx: Context): ast.ExprBoolean
	local token = consume(ctx)
	if token.kind == "true" then
		return {
			id = next_node_id(ctx),
			span = token.span,
			kind = "boolean",
			value = true,
		}
	elseif token.kind == "false" then
		return {
			id = next_node_id(ctx),
			span = token.span,
			kind = "boolean",
			value = false,
		}
	end

	return report.expect_token_one_of(token, { "true", "false" })
end

local function expr_number(ctx: Context): ast.ExprNumber
	local number = expect(ctx, "number")
	local value = span.value(number.span)
	local literal = tonumber(value)

	if literal == nil then
		return panic(`Unable to cast "{value}" to number`)
	end

	return {
		id = next_node_id(ctx),
		span = number.span,
		kind = "number",
		value = literal,
	}
end

local function expr_string(ctx: Context): ast.ExprString
	local str = expect(ctx, "string")
	local value = span.value(str.span)
	-- strip quotes
	value = string.sub(value, 2, #value - 1)

	return {
		id = next_node_id(ctx),
		span = str.span,
		kind = "string",
		value = value,
	}
end

local function string_or_identifier(ctx: Context): ast.Identifier | ast.ExprString
	if peek_kind(ctx) == "string" then
		return expr_string(ctx)
	end

	return identifier(ctx)
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

	return report.expect_token_one_of(token, { "string", "number", "true", "false" })
end

local function expr_range(ctx: Context): ast.Range
	local node_id = next_node_id(ctx)

	local min: ast.ExprNumber
	local max: ast.ExprNumber

	local first = peek(ctx)
	local last: lexer.Token = first
	if first.kind == "number" then
		min = expr_number(ctx)

		if peek_kind(ctx) == ".." then
			last = expect(ctx, "..")
			if peek_kind(ctx) == "number" then
				max = expr_number(ctx)
			end
		else
			-- exact range
			max = min
		end
	elseif first.kind == ".." then
		last = expect(ctx, "..")
		max = expr_number(ctx)
	else
		return report.expect_token_one_of(first, { "..", "number" })
	end

	local upper_bound = (max or last) :: ast.ExprNumber

	return {
		id = node_id,
		span = span.merge(first.span, upper_bound.span),
		kind = "range",
		max = max,
		min = min,
	}
end

local function expr_reference(ctx: Context): ast.ExprReference
	local node_id = next_node_id(ctx)
	local path = path(ctx)
	local node_span = path.span

	--> generics
	local generics: ast.GenericsArgs?
	if peek_kind(ctx) == "<" then
		local opener, values, closer = list(ctx, "<", expression, ",", coerce(">"))
		node_span = span.merge(node_span, closer.span)
		generics = {
			span = span.merge(opener.span, closer.span),
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
		id = node_id,
		span = node_span,
		kind = "reference",
		path = path,
		range = range,
		generics = generics,
	}
end

local function expr_field(ctx: Context): ast.ExprField
	local node_id = next_node_id(ctx)
	local name = string_or_identifier(ctx)
	expect(ctx, ":")
	local value = expression(ctx)

	return {
		id = node_id,
		span = span.merge(name.span, value.span),
		kind = "field",
		name = name,
		value = value,
	}
end

local function expr_struct(ctx: Context): ast.ExprStruct
	local node_id = next_node_id(ctx)
	local keyword = expect(ctx, "struct")
	local _opener, fields, closer = list(ctx, "{", expr_field, ",", coerce("}"))

	return {
		id = node_id,
		span = span.merge(keyword.span, closer.span),
		kind = "struct",
		fields = fields,
	}
end

--- Bit annoying but needed for tagged enum variants
local function expr_inlined_struct(ctx: Context): ast.ExprStruct
	local node_id = next_node_id(ctx)
	local opener, fields, closer = list(ctx, "{", expr_field, ",", coerce("}"))

	return {
		id = node_id,
		span = span.merge(opener.span, closer.span),
		kind = "struct",
		fields = fields,
	}
end

local function expr_map(ctx: Context): ast.ExprMap
	local node_id = next_node_id(ctx)
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
		id = node_id,
		span = span.merge(keyword.span, value.span),
		kind = "map",
		index = index,
		value = value,
		range = range,
	}
end

local function expr_discriminated_union_variant(ctx: Context): ast.ExprDiscriminatedUnionVariant
	local node_id = next_node_id(ctx)

	--> variant name
	local key
	local token = peek(ctx)

	if token.kind == "nil" then
		key = expr_nil(ctx)
	elseif token.kind == "true" or token.kind == "false" then
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
		id = node_id,
		span = span.merge(key.span, value.span),
		kind = "variant",

		key = key,
		value = value,
	}
end

local function expr_discriminated_union(ctx: Context): ast.ExprDiscriminatedUnion
	local keyword = expect(ctx, "union")
	local node_id = next_node_id(ctx)
	local tag = expr_string(ctx)
	local _opener, variants, closer = list(ctx, "{", expr_discriminated_union_variant, ",", coerce("}"))

	return {
		id = node_id,
		span = span.merge(keyword.span, closer.span),
		kind = "discriminated_union",

		tag = tag,
		variants = variants,
	}
end

local function expr_pack_parameter(ctx: Context): ast.ExprPackParameter
	local node_id = next_node_id(ctx)

	local name: ast.Identifier?
	local following = lookahead(ctx)
	if following.kind == ":" then
		name = identifier(ctx)
		local _ = expect(ctx, ":")
	end

	local value = expression(ctx)
	local full_span = name and span.merge(name.span, value.span) or value.span

	return {
		id = node_id,
		span = full_span,
		kind = "parameter",

		name = name,
		value = value,
	}
end

local function expr_pack(ctx: Context): ast.ExprPack
	local node_id = next_node_id(ctx)
	local opener, values, closer = list(ctx, "(", expr_pack_parameter, ",", coerce(")"))

	return {
		id = node_id,
		span = span.merge(opener.span, closer.span),
		kind = "pack",

		values = values,
	}
end

local function expr_pack_single(ctx: Context): ast.ExprPack
	local pack_node_id = next_node_id(ctx)

	local node_id = next_node_id(ctx)
	local value = expression(ctx)
	local parameter: ast.ExprPackParameter = {
		id = node_id,
		span = value.span,
		kind = "parameter",
		name = nil,
		value = value,
	}

	return {
		id = pack_node_id,
		span = value.span,
		kind = "pack",
		values = { parameter },
	}
end

local function expr_array(ctx: Context, of: ast.Expression): ast.ExprArray
	local node_id = next_node_id(ctx)
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
		id = node_id,
		span = node_span,
		kind = "array",

		range = range,
		value = of,
	}
end

local function expr_union(ctx: Context, first: ast.Expression): ast.ExprUnion
	expect(ctx, "|")

	local node_id = next_node_id(ctx)
	local components = { first }

	while true do
		table.insert(components, expression(ctx))
		if peek_kind(ctx) ~= "|" then
			break
		end

		consume(ctx)
	end

	local last = components[#components]

	return {
		id = node_id,
		span = span.merge(first.span, last.span),
		kind = "union",
		components = components,
	}
end

local function expr_optional(ctx: Context, of: ast.Expression): ast.ExprOptional
	local optional = expect(ctx, "?")
	return {
		id = next_node_id(ctx),
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
	local name = identifier(ctx)
	local node_span = span.merge(at.span, name.span)

	local args: { ast.ExprLiteral } = {}
	if peek_kind(ctx) == "(" then
		const _opener, values, closer = list(ctx, "(", expr_literal, ",", coerce(")"))
		args = values
		node_span = span.merge(node_span, closer.span)
	end

	return {
		kind = "attribute",
		span = node_span,
		name = name,
		args = args,
	}
end

local function stat_type(ctx: Context): ast.StatType
	local node_id = next_node_id(ctx)
	local attributes = consume_attributes(ctx)

	local keyword = expect(ctx, "type")
	local name = identifier(ctx)

	local generics = if peek_kind(ctx) == "<" then generics(ctx) else nil

	local _assign = expect(ctx, "=")
	local value = expression(ctx)

	return {
		id = node_id,
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
	local node_id = next_node_id(ctx)
	local attributes = consume_attributes(ctx)

	local keyword = expect(ctx, "event")
	local name = identifier(ctx)
	local _assign = expect(ctx, "=")

	local event_structure = shape(ctx, {
		from = { expr = identifier, optional = false },
		type = { expr = identifier, optional = false },
		call = { expr = identifier, optional = false },
		data = { expr = expr_pack_or_single, optional = true },
	})

	local closer = event_structure.closer
	local fields = event_structure.fields

	return {
		id = node_id,
		span = span.merge(keyword.span, closer.span),
		kind = "event",
		attributes = attributes,

		name = name,
		from = fields.from,
		type = fields.type,
		call = fields.call,
		data = fields.data,
	}
end

local function stat_scope(ctx: Context): ast.StatScope
	local node_id = next_node_id(ctx)
	local keyword = expect(ctx, "scope")
	local name = identifier(ctx)

	expect(ctx, "{")
	local scope_block = block(ctx, true)
	local close = expect(ctx, "}")

	return {
		id = node_id,
		span = span.merge(keyword.span, close.span),
		kind = "scope",

		name = name,
		body = scope_block,
	}
end

local function stat_option(ctx: Context): ast.StatOption
	local node_id = next_node_id(ctx)
	local keyword = expect(ctx, "option")
	local name = identifier(ctx)

	local _assign = expect(ctx, "=")
	local value = expr_literal(ctx)
	local stat_span = span.merge(keyword.span, value.span)

	return {
		id = node_id,
		span = stat_span,
		kind = "option",

		name = name,
		value = value,
	}
end

local function stat_function(ctx: Context): ast.StatFunction
	local node_id = next_node_id(ctx)
	local attributes = consume_attributes(ctx)

	local keyword = expect(ctx, "function")
	local name = identifier(ctx)
	local _assign = expect(ctx, "=")

	local function_structure = shape(ctx, {
		data = { expr = expr_pack_or_single, optional = true },
		["return"] = { expr = expr_pack_or_single, optional = true },
	})

	local closer = function_structure.closer
	local fields = function_structure.fields

	return {
		id = node_id,
		span = span.merge(keyword.span, closer.span),
		kind = "function",
		attributes = attributes,

		name = name,
		data = fields.data,
		ret = fields["return"],
	}
end

local function stat_import(ctx: Context): ast.StatImport
	local node_id = next_node_id(ctx)
	local first = expect(ctx, "from")

	local path_string = expr_string(ctx)
	expect(ctx, "import")

	local last: ast.Node | lexer.Token
	local extra: index<ast.StatImport, "extra">
	if peek_kind(ctx) == "*" then
		local star = consume(ctx)
		last = star

		local into_scope: ast.Identifier?
		if peek_kind(ctx) == "as" then
			consume(ctx)
			into_scope = identifier(ctx)
			last = into_scope
		end

		extra = {
			kind = "all",
			star = as_identifier(ctx, star),
			into_scope = into_scope,
		}
	elseif peek_kind(ctx) == "{" then
		consume(ctx)

		local values = {}
		if peek_kind(ctx) ~= "}" then
			while true do
				local name = path(ctx)
				local rename_to: ast.Identifier?
				if peek_kind(ctx) == "as" then
					consume(ctx)
					rename_to = identifier(ctx)
				end

				table.insert(values, { path = name, rename_to = rename_to })

				if peek_kind(ctx) == "," then
					consume(ctx)
					continue
				end

				break
			end
		end

		extra = {
			kind = "destructured",
			values = values,
		}

		last = expect(ctx, "}")
	else
		return report.expect_token_one_of(consume(ctx), { "*", "{" })
	end

	local full_span = span.merge(first.span, last.span)
	return {
		id = node_id,
		span = full_span,
		kind = "import",
		path = path_string,
		extra = extra,
	}
end

local function try_wrap_in_optional(ctx: Context, expr: ast.Expression): ast.Expression
	local token = peek(ctx)
	if token.kind ~= "?" then
		return expr
	end

	return expr_optional(ctx, expr)
end

function expression(ctx: Context): ast.Expression
	local token = peek(ctx)
	local expr: ast.Expression

	if token.kind == "word" then
		expr = expr_reference(ctx)
	elseif token.kind == "map" then
		expr = expr_map(ctx)
	elseif token.kind == "union" then
		expr = expr_discriminated_union(ctx)
	elseif token.kind == "struct" then
		expr = expr_struct(ctx)
	elseif token.kind == "number" then
		expr = expr_number(ctx)
	elseif token.kind == "string" then
		expr = expr_string(ctx)
	elseif token.kind == "true" or token.kind == "false" then
		expr = expr_boolean(ctx)
	elseif token.kind == "nil" then
		expr = expr_nil(ctx)
	end

	if expr == nil then
		return report.expect_token_one_of(token, { "word", "string", "number", "true", "false" })
	end

	while peek_kind(ctx) == "[" do
		expr = expr_array(ctx, expr)
		expr = try_wrap_in_optional(ctx, expr)
	end

	expr = try_wrap_in_optional(ctx, expr)

	--> merge
	while peek_kind(ctx) == "|" do
		expr = expr_union(ctx, expr)
	end

	return expr
end

function statement(ctx: Context): ast.Statement
	local stat: ast.Statement?
	local token = peek(ctx)

	if token.kind == "type" then
		stat = stat_type(ctx)
	elseif token.kind == "from" then
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
		return report.expect_token_one_of(token, { "type", "scope", "event", "struct", "function" })
	end

	-- validate attributes
	if #ctx.attributes > 0 then
		return report.invalid_attribute_placement(stat)
	end

	return stat
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
	assert_panic(#tokens > 0, "Tokens are empty")
	assert_panic(tokens[#tokens] and tokens[#tokens].kind == "eof", "Final token should be eof")

	local ctx: Context = {
		tokens = tokens,

		file = file,
		node_index = 0,

		index = 1,
		token = tokens[1],
		lookahead = tokens[2] or tokens[1],

		attributes = {},
	}

	return {
		kind = "ast",
		body = block(ctx),
	}
end

return table.freeze({
	parse = parse,
})
