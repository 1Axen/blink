--!strict
--!native
--!optimize 2

local validator = require("./validator")

local id = require("@compiler/id")
local lexer = require("@compiler/lexer")
local ast = require("@compiler/structures/ast")

local span = require("@util/span")
local panic = require("@util/panic")
local symbols = require("@util/symbols")
local diagnostics = require("@util/diagnostics")

local report = require("./report")

type Token = lexer.Token
type TokenAny = lexer.TokenBase<any>
type TokenKind = lexer.TokenKind

type Parser = {
    read tokens: {Token},

    read module: number,
    read node_index: number,

    index: number,
    token: Token,
    lookahead: Token,

    attributes: {ast.Attribute}
}

local DUMMY_ID = id.node_id.create(2^8 - 1, 2^22 - 1)
local ROOT_SYMBOLS = ""

local block: (Parser, boolean) -> ast.Block;
local statement: (Parser) -> ast.Statement;
local expression: (Parser) -> ast.Expression;

local function next_node_id(parser: Parser): ast.NodeId
    local index = parser.node_index
    parser.node_index += 1
    return id.node_id.create(parser.module, index)
end

local function peek(parser: Parser): Token
    return parser.token
end

local function peek_kind(parser: Parser): TokenKind
    return peek(parser).kind
end

local function lookahead(parser: Parser): Token
    return parser.lookahead
end

local function consume(parser: Parser): Token
    local token = parser.token
    local index = parser.index
    local tokens = parser.tokens

    local size = #tokens
    local next_index = math.min(index + 1, size)
    local lookahead_index = math.min(index + 2, size)

    parser.index = next_index
    parser.token = parser.lookahead
    parser.lookahead = tokens[lookahead_index]

    return token
end

local function consume_attributes(parser: Parser): {ast.Attribute}
    local attributes = parser.attributes
    parser.attributes = {}
    return attributes
end

local function expect<T>(parser: Parser, kind: T & TokenKind): lexer.TokenBase<T>
    local token = peek(parser)
    if token.kind == kind :: any then
        return consume(parser) :: any
    end

    return report.expect(token, kind)
end

local function seperated<T>(parser: Parser, t: (Parser) -> T, seperator: TokenKind, delimiter: "}" | ")" | "]" | ">"): {T}
    local list: {T} = {}
    
    while peek_kind(parser) ~= delimiter do
        table.insert(list, t(parser))

        --> if the next token isn't the seperator assume the list ended
        if peek_kind(parser) ~= seperator then
            break
        end

        --> consume the seperator
        consume(parser)
    end

    return list
end

local function path_segment(parser: Parser): ast.PathSegment
    local word = expect(parser, "word")
    return {
        kind = "segment",
        span = word.span,
        value = span.value(word.span)
    }
end

--- Parses word + dot as identifier (foo.bar)
local function path(parser: Parser): ast.Path
    local segments: {ast.PathSegment} = {}
    local path_span: span.Span?

    while true do
        local segment = path_segment(parser)
        table.insert(segments, segment)
        path_span = if path_span then span.merge(path_span, segment.span) else segment.span

        --> end of path
        if peek_kind(parser) ~= "." then
            break
        end

        --> consume dot
        expect(parser, ".")
    end

    return {
        kind = "path",
        span = path_span :: vector,
        segments = segments
    }
end

local function identifier(parser: Parser): ast.Identifier
    local word = expect(parser, "word")
    return {
        span = word.span,
        kind = "identifier",
        value = span.value(word.span)
    }
end

--- Parses anything as an identifier
local function any_identifier(parser: Parser): ast.Identifier
    local token = consume(parser)
    return {
        span = token.span,
        kind = "identifier",
        value = span.value(token.span)
    }
end

--- Also parses escapes like "option", "type" etc. as identifiers
local function escaped_identifier(parser: Parser): ast.Identifier
    local token = peek(parser)
    if token.kind ~= "word" and token.kind ~= "string" then
        return report.expect_one_of(token, {"word", "string"})
    end

    --> consume identifier
    consume(parser)

    return {
        span = token.span,
        kind = "identifier",
        value = span.value(token.span)
    }
end

local function structure(parser: Parser, fields: {[string]: {expr: (parser: Parser) -> any, optional: boolean}}, open: lexer.TokenBase<any>): {[string]: any}
    --> key - required
    local all_keys: {string} = {}
    local parsed_keys: {[string]: report.Entry} = {}
    local required_keys: {string} = {}

    for key, value in fields do
        if value.optional == false then
            table.insert(required_keys, key)
        end

        table.insert(all_keys, key)
    end

    local result: {[string]: ast.Expression} = {}

    while true do
        local name = any_identifier(parser)
        local key = name.value

        local previous = parsed_keys[key]
        if previous ~= nil then
            return report.duplicate_entry_early(previous, name)
        end

        local field = fields[key]
        if field == nil then
            report.expect_one_of_ident(name.span, key, all_keys)
        end

        local _assign = expect(parser, ":")
        local value = field.expr(parser)

        result[key] = value
        parsed_keys[key] = name

        local index = table.find(required_keys, key)
        if index then
            table.remove(required_keys, index)
        end

        --> assume end of structure
        if peek_kind(parser) ~= "," then
            break
        end

        expect(parser, ",")
    end

    local close = peek(parser)
    if #required_keys ~= 0 then
        return report.missing_entries(
            span.merge(open.span, close.span), 
            required_keys
        )
    end

    return result
end

local function generic(parser: Parser): ast.GenericDef
    local name = identifier(parser)
    local node_span = name.span

    return {
        id = DUMMY_ID,
        kind = "generic",
        span = node_span,
        name = name,
    }
end

local function generics(parser: Parser): ast.GenericsDef
    local open = expect(parser, "<")
    local values: {ast.GenericDef} = seperated(parser, generic, ",", ">")
    local close = expect(parser, ">")

    return {
        kind = "generics",
        span = span.merge(open.span, close.span),
        values = values
    }
end

local function expr_boolean(parser: Parser): ast.ExprBoolean
    local token = consume(parser)
    if token.kind == "true" then
        return {
            id = DUMMY_ID,
            span = token.span,
            kind = "boolean",
            value = true
        }
    elseif token.kind == "false" then
        return {
            id = DUMMY_ID,
            span = token.span,
            kind = "boolean",
            value = false
        }
    end

    return report.expect_one_of(token, {"true", "false"})
end

local function expr_number(parser: Parser): ast.ExprNumber
    local number = expect(parser, "number")
    local value = span.value(number.span)
    local literal = tonumber(value)

    if literal == nil then
        return panic(`Unable to cast "{value}" to number`)
    end

    return {
        id = DUMMY_ID,
        span = number.span,
        kind = "number",
        value = literal
    }
end

local function expr_string(parser: Parser): ast.ExprString
    local str = expect(parser, "string")
    return {
        id = DUMMY_ID,
        span = str.span,
        kind = "string",
        value = span.value(str.span)
    }
end

local function expr_literal(parser: Parser): ast.ExprLiteral
    local token = peek(parser)
    if token.kind == "string" then
        return expr_string(parser)
    elseif token.kind == "number" then
        return expr_number(parser)
    elseif token.kind == "true" or token.kind == "false" then
        return expr_boolean(parser)
    end

    return report.expect_one_of(token, {"string", "number", "true", "false"})
end

local function expr_range(parser: Parser, delimiter: "(" | "["): ast.Range
    local min: ast.ExprNumber?
    local max: ast.ExprNumber?

    local open = expect(parser, delimiter)
    local first = peek(parser)

    if first.kind == "number" then
        min = expr_number(parser)

        local second = peek(parser)
        if second.kind == ".." then
            expect(parser, "..")
            max = expr_number(parser)
        end
    elseif first.kind == ".." then
        expect(parser, "..")
        max = expr_number(parser)
    else
        report.expect_one_of(first, {"..", "number"})
    end

    local close = expect(parser, delimiter == "(" and ")" or "]" :: any)
    return {
        span = span.merge(open.span, close.span),
        kind = "range",
        max = max,
        min = min
    }
end

local function expr_reference(parser: Parser): ast.ExprReference
    local path = path(parser)
    local node_span = path.span
    
    --> generics
    local generics: ast.GenericsArgs?
    if peek_kind(parser) == "<" then
        local open = expect(parser, "<")
        local values = seperated(parser, expression, ",", ">")

        local close = expect(parser, ">")
        node_span = span.merge(path.span, close.span)
        generics = {
            span = span.merge(open.span, close.span),
            kind = "generics",
            values = values
        }
    end

    --> range
    local range: ast.Range?
    if peek_kind(parser) == "(" then
        range = expr_range(parser, "(")
        node_span = span.merge(node_span, range.span)
    end

    return {
        id = DUMMY_ID,
        span = node_span,
        kind = "reference",
        path = path,
        range = range,
        generics = generics
    }
end

local function expr_field(parser: Parser): ast.ExprField
    local name = escaped_identifier(parser)
    expect(parser, ":")
    local value = expression(parser)

    return {
        id = DUMMY_ID,
        span = span.merge(name.span, value.span),
        kind = "field",
        name = name,
        value = value
    }
end

local function expr_struct(parser: Parser): ast.ExprStruct
    local keyword = expect(parser, "struct")
    expect(parser, "{")

    local fields = seperated(parser, expr_field, ",", "}")
    local close = expect(parser, "}")

    return {
        id = DUMMY_ID,
        span = span.merge(keyword.span, close.span),
        kind = "struct",
        fields = fields
    }
end

--- Bit annoying but needed for tagged enum variants
local function expr_inlined_struct(parser: Parser): ast.ExprStruct
    local open = expect(parser, "{")
    local fields = seperated(parser, expr_field, ",", "}")
    local close = expect(parser, "}")

    return {
        id = DUMMY_ID,
        span = span.merge(open.span, close.span),
        kind = "struct",
        fields = fields
    }
end

local function expr_map(parser: Parser): ast.ExprMap
    local keyword = expect(parser, "map")
    
    --> open "{" delim
    expect(parser, "{")

    --> index
    expect(parser, "[")
    local index = expression(parser)
    expect(parser, "]")

    --> value
    expect(parser, ":")
    local value = expression(parser)

    --> close delim
    expect(parser, "}")

    local range: ast.Range?;
    if peek_kind(parser) == "(" then
        range = expr_range(parser, "(")
    end

    return {
        id = DUMMY_ID,
        span = span.merge(keyword.span, value.span),
        kind = "map",
        index = index,
        value = value,
        range = range
    }
end

local function expr_set(parser: Parser): ast.ExprSet
    local keyword = expect(parser, "set")
    expect(parser, "{")

    local values = seperated(parser, escaped_identifier, ",", "}")
    local close = expect(parser, "}")

    return {
        id = DUMMY_ID,
        span = span.merge(keyword.span, close.span),
        kind = "set",
        values = values
    }
end

local function expr_enum_tag_variant(parser: Parser): ast.ExprTaggedEnumVariant
    --> variant name
    local key;
    local token = peek(parser)
    
    if token.kind == "true" or token.kind == "false" then
        key = expr_boolean(parser)
    elseif token.kind == "string" then
        key = expr_string(parser)
    elseif token.kind == "number" then
        key = expr_number(parser)
    else
        key = escaped_identifier(parser)
    end

    --> struct
    local value = expr_inlined_struct(parser)

    return {
        id = DUMMY_ID,
        span = span.merge(key.span, value.span),
        kind = "variant",

        key = key,
        value = value
    }
end

local function expr_enum(parser: Parser): ast.ExprEnum | ast.ExprTaggedEnum
    local keyword = expect(parser, "enum")
    
    local function unit(): ast.ExprEnum
        expect(parser, "{")

        local variants = seperated(parser, escaped_identifier, ",", "}")
        local close = expect(parser, "}")

        return {
            id = DUMMY_ID,
            span = span.merge(keyword.span, close.span),
            kind = "enum",

            variants = variants
        }
    end

    local function tagged(): ast.ExprTaggedEnum
        local tag = expr_string(parser)
        expect(parser, "{")

        local variants = seperated(parser, expr_enum_tag_variant, ",", "}")
        local close = expect(parser, "}")

        return {
            id = DUMMY_ID,
            span = span.merge(keyword.span, close.span),
            kind = "tag_enum",
            
            tag = tag,
            variants = variants
        }
    end

    local tag = peek(parser)
    if tag.kind == "string" then
        return tagged()
    end

    return unit()
end

local function expr_pack_parameter(parser: Parser): ast.ExprPackParameter
    local name: ast.Identifier?
    local following = lookahead(parser)
    if following.kind == ":" then
        name = any_identifier(parser)
        local _ = expect(parser, ":")
    end

    local value = expression(parser)
    local full_span = name and span.merge(name.span, value.span) or value.span

    return {
        id = DUMMY_ID,
        span = full_span,
        kind = "parameter",

        name = name,
        value = value
    }
end

local function expr_pack(parser: Parser): ast.ExprPack
    local open = expect(parser, "(")
    local values = seperated(parser, expr_pack_parameter, ",", ")")
    local close = expect(parser, ")")

    return {
        id = DUMMY_ID,
        span = span.merge(open.span, close.span),
        kind = "pack",

        values = values
    }
end

local function expr_pack_single(parser: Parser): ast.ExprPack
    local value = expression(parser)
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
        values = {parameter}
    }
end

local function expr_array(parser: Parser, of: ast.Expression): ast.ExprArray
    local range = expr_range(parser, "[")
    return {
        id = DUMMY_ID,
        span = span.merge(of.span, range.span),
        kind = "array",

        range = range,
        value = of,
    }
end

local function expr_union(parser: Parser, left: ast.Expression, right: ast.Expression): ast.ExprUnion
    return {
        id = DUMMY_ID,
        span = span.merge(left.span, right.span),
        kind = "union",
        left = left,
        right = right
    }
end

local function expr_optional(parser: Parser, of: ast.Expression): ast.ExprOptional
    local optional = expect(parser, "?")
    return {
        id = DUMMY_ID,
        span = span.merge(of.span, optional.span),
        kind = "optional",
        value = of
    }
end 

--- Parses a single expression or a pack of expressions
local function expr_pack_or_single(parser: Parser): ast.ExprPack
    local token = peek(parser)
    if token.kind == "(" then
        return expr_pack(parser)
    end

    return expr_pack_single(parser)
end

local function attribute(parser: Parser): ast.Attribute
    local at = expect(parser, "@")
    local name = any_identifier(parser)
    local node_span = span.merge(at.span, name.span)

    local args: {ast.ExprLiteral} = {}
    if peek_kind(parser) == "(" then
        local _open = expect(parser, "(")
        args = seperated(parser, expr_literal, ",", ")")

        local close = expect(parser, ")")
        node_span = span.merge(node_span, close.span)
    end

    return {
        kind = "attribute",
        span = node_span,
        name = name,
        args = args
    }
end

local function stat_type(parser: Parser): ast.StatType
    local attributes = consume_attributes(parser)

    local keyword = expect(parser, "type")
    local name = identifier(parser)

    local generics = 
        if peek_kind(parser) == "<" 
        then generics(parser) 
        else nil

    local _assign = expect(parser, "=")
    local value = expression(parser)

    return {
        id = DUMMY_ID,
        span = span.merge(keyword.span, value.span),
        kind = "type",
        attributes = attributes,

        name = name,
        value = value,
        generics = generics,

        export = false
    }
end

local function stat_event(parser: Parser): ast.StatEvent
    local attributes = consume_attributes(parser)

    local keyword = expect(parser, "event")
    local name = identifier(parser)
    local open = expect(parser, "{")

    local event_structure = structure(parser, {
        from = {expr = identifier, optional = false},
        type = {expr = identifier, optional = false},
        call = {expr = identifier, optional = false},
        poll = {expr = expr_boolean, optional = true},
        data = {expr = expr_pack_or_single, optional = true},
    }, open)

    local close = expect(parser, "}")

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
        data = event_structure.data
    }
end

local function stat_scope(parser: Parser): ast.StatScope
    local keyword = expect(parser, "scope")
    local name = identifier(parser)

    local _open = expect(parser, "{")
    local scope_block = block(parser, true)
    local close = expect(parser, "}")

    return {
        id = DUMMY_ID,
        span = span.merge(keyword.span, close.span),
        kind = "scope",

        name = name,
        body = scope_block
    }
end

local function stat_option(parser: Parser): ast.StatOption
    local keyword = expect(parser, "option")
    local name = identifier(parser)

    local _assign = expect(parser, "=")
    local value = expression(parser)
    local stat_span = span.merge(keyword.span, value.span)

    return {
        id = DUMMY_ID,
        span = stat_span,
        kind = "option",

        name = name,
        value = value,
    }
end

local function stat_function(parser: Parser): ast.StatFunction
    local attributes = consume_attributes(parser)

    local keyword = expect(parser, "function")
    local name = identifier(parser)
    local open = expect(parser, "{")

    local function_structure = structure(parser, {
        yield = {expr = identifier, optional = false},
        data = {expr = expr_pack_or_single, optional = true},
        ["return"] = {expr = expr_pack_or_single, optional = true},
    }, open)

    local close = expect(parser, "}")

    return {
        id = DUMMY_ID,
        span = span.merge(keyword.span, close.span),
        kind = "function",
        attributes = attributes,

        name = name,
        yield = function_structure.yield,
        data = function_structure.data,
        ret = function_structure["return"]
    }
end

local function stat_import(parser: Parser): ast.StatImport
    local keyword = expect(parser, "import")
    local path = expr_string(parser)

    local name: ast.Identifier = {
        span = path.span,
        kind = "identifier",
        value = path.value
    }

    local token = peek(parser)
    if token.kind == "as" then
        expect(parser, "as")
        name = identifier(parser)
    end

    return {
        id = DUMMY_ID,
        span = name and span.merge(keyword.span, name.span) or span.merge(keyword.span, path.span),
        kind = "import",
        
        name = name,
        path = path
    }
end

local function try_wrap_in_optional(parser: Parser, expr: ast.Expression): ast.Expression
    local token = peek(parser)
    if token.kind ~= "?" then
        return expr
    end

    local node_id = next_node_id(parser)
    expr = expr_optional(parser, expr)
    expr.id = node_id

    return expr
end

function expression(parser: Parser): ast.Expression
    local token = peek(parser)
    local expr: ast.Expression
    local node_id = next_node_id(parser)
    
    if token.kind == "word" then
        expr = expr_reference(parser)
    elseif token.kind == "map" then
        expr = expr_map(parser)
    elseif token.kind == "set" then
        expr = expr_set(parser)
    elseif token.kind == "enum" then
        expr = expr_enum(parser)
    elseif token.kind == "struct" then
        expr = expr_struct(parser)
    elseif token.kind == "number" then
        expr = expr_number(parser)
    elseif token.kind == "string" then
        expr = expr_string(parser)
    elseif token.kind == "true" or token.kind == "false" then
        expr = expr_boolean(parser)
    end
    
    if expr == nil then
        return report.expect_one_of(token, {"word", "string", "number", "true", "false"})
    end

    -- assign node id
    expr.id = node_id

    while peek_kind(parser) == "[" do
        --> array
        local array_node_id = next_node_id(parser)
        expr = expr_array(parser, expr)
        expr.id = array_node_id

        --> optional
        expr = try_wrap_in_optional(parser, expr)
    end

    --> optional
    expr = try_wrap_in_optional(parser, expr)

    --> merge
    if peek_kind(parser) == "&" then
        consume(parser)

        -- reserve node id
        local union_node_id = next_node_id(parser)
        
        local right = expression(parser)
        expr = expr_union(parser, expr, right)
        expr.id = union_node_id
    end

    return expr
end

function statement(parser: Parser): ast.Statement
    local stat: ast.Statement?
    local token = peek(parser)
    local node_id = next_node_id(parser)

    if token.kind == "type" then
        stat = stat_type(parser)
    elseif token.kind == "import" then
        stat = stat_import(parser)
    elseif token.kind == "scope" then
        stat = stat_scope(parser)
    elseif token.kind == "event" then
        stat = stat_event(parser)
    elseif token.kind == "option" then
        stat = stat_option(parser)
    elseif token.kind == "function" then
        stat = stat_function(parser)
    end

    if stat == nil then
        return report.expect_one_of(token, { "type", "scope", "event", "struct", "function" })
    end

    --TODO: Remove
    assert(stat, "luau type solver issue")

    -- assign node id
    stat.id = node_id

    -- validate attributes
	if #parser.attributes > 0 then
        return report.invalid_attribute_placement(stat)
	end

    --TODO: Remove cast
    return stat :: ast.Statement
end

function block(parser: Parser, is_scope: boolean?): ast.Block
    local node_id = next_node_id(parser)
    local statements: {ast.Statement} = {}

    while true do
        local token = peek(parser)
        if token.kind == "eof" then
            break
        end

        --> end of scope
        if is_scope and token.kind == "}" then
            break
        end

        --> attributes
        if token.kind == "@" then
            table.insert(parser.attributes, attribute(parser))
            continue
        end
        
        table.insert(statements, statement(parser))
    end

    return {
        id = node_id,
        kind = "block",
        statements = statements
    }
end

--- Returns an AST constructed from `tokens`, errors if invalid syntax is encountered
local function parse(file_id: number, tokens: {lexer.Token}): ast.Ast
    assert(#tokens > 0, "Tokens are empty")
    assert(tokens[#tokens] and tokens[#tokens].kind == "eof", "Final token should be eof")

    local parser: Parser = {
        tokens = tokens,

        module = file_id,
        node_index = 0,

        index = 1,
        token = tokens[1],
        lookahead = tokens[2] or tokens[1],

        attributes = {},
    }

    local ast: ast.Ast = {
        kind = "ast",
        body = block(parser),
        symbols = symbols.create(ROOT_SYMBOLS) :: symbols.Symbols<ast.Statement>
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
    parse = parse
})