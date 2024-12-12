--!strict
--!native
--!optimize 2

local ast = require("./ast")

local lexer = require("@compiler/lexer")
local codes = require("@compiler/config/codes")
local primitives = require("@compiler/config/primitives")

local span = require("@util/span")
local diagnostics = require("@util/diagnostics")

type Token = lexer.Token
type TokenAny = lexer.TokenBase<any, any>

type Parser = {
    tokens: {Token},

    index: number,
    token: Token,
    lookahead: Token
}

local block: (Parser, boolean) -> ast.Block;
local statement: (Parser) -> ast.Statement;
local expression: (Parser) -> ast.Expression;

local function report_expect(parser: Parser, token: Token, kind: typeof((({} :: any) :: Token).kind)): never
    return diagnostics.report.create("Error")
        .with_code(codes.parser.UnexpectedToken)
        .with_message(`Expected "{kind}", got "{token.kind}" instead`)
        .with_label(diagnostics.label.create(token.span)
            .with_message("Here")
            .with_color(diagnostics.style.color.red)
        )
        .finish()
    .error()
end

local function report_expect_one_of(parser: Parser, token: Token, kinds: {typeof((({} :: any) :: Token).kind)}): never
    return diagnostics.report.create("Error")
        .with_code(codes.parser.UnexpectedToken)
        .with_message(`Expected one of "{table.concat(kinds, "\", \"")}", got "{token.kind}" instead`)
        .with_label(diagnostics.label.create(token.span)
            .with_message("Here")
            .with_color(diagnostics.style.color.red)
        )
        .finish()
    .error()
end

local function report_expect_one_of_ident(parser: Parser, span: span.Span, got: string, expected: {string}): never
    return diagnostics.report.create("Error")
        .with_code(codes.parser.UnexpectedToken)
        .with_message(`Expected one of "{table.concat(expected, "\", \"")}", got "{got}" instead`)
        .with_label(diagnostics.label.create(span)
            .with_message("Here")
            .with_color(diagnostics.style.color.red)
        )
        .finish()
    .error()
end

local function peek(parser: Parser): Token
    return parser.token
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

local function expect<T>(parser: Parser, kind: T & typeof((({} :: any) :: Token).kind)): lexer.TokenBase<T, any>
    local token = peek(parser)
    if token.kind == kind :: any then
        return consume(parser) :: any
    end

    return report_expect(parser, token, kind)
end

local function seperated<T>(parser: Parser, t: (Parser) -> T, seperator: typeof((({} :: any) :: Token).kind), delimiter: "}" | ")" | "]" | ">"): {T}
    local list: {T} = {}

    while peek(parser).kind ~= delimiter do
        table.insert(list, t(parser))

        --> if the next token isn't the seperator assume the list ended
        if peek(parser).kind ~= seperator then
            break
        end

        --> consume the seperator
        consume(parser)
    end

    return list
end

local function identifier(parser: Parser): ast.Identifier
    local token = expect(parser, "word")
    return {
        span = token.span,
        kind = "identifier",
        value = token.value
    }
end

--- Parses anything as an identifier
local function any_identifier(parser: Parser): ast.Identifier
    local token = consume(parser)
    return {
        span = token.span,
        kind = "identifier",
        value = token.value or token.kind
    }
end

--- Parses word + dot as identifier (foo.bar)
local function path_identifier(parser: Parser): ast.Identifier
    local first = expect(parser, "word")
    local last: TokenAny = first

    while true do
        local current = peek(parser)
        local following = lookahead(parser)

        if 
            current.kind ~= "." 
            or following.kind ~= "word" 
        then
            break
        end

        --> consume dot & word
        consume(parser)
        last = consume(parser)
    end

    --> get full identifier
    local full_span = span.merge(first.span, last.span)
    local full_value = span.value(full_span)

    return {
        kind = "identifier",
        span = full_span,
        value = full_value
    }
end

--- Also parses escapes like "option", "type" etc. as identifiers
local function escaped_identifier(parser: Parser): ast.Identifier
    local token = peek(parser)
    if token.kind ~= "word" and token.kind ~= "string" then
        return report_expect_one_of(parser, token, {"word", "string"})
    end

    --> consume identifier
    consume(parser)

    return {
        span = token.span,
        kind = "identifier",
        value = token.value
    }
end

local function structure(parser: Parser, fields: {[string]: {expr: (parser: Parser) -> any, optional: boolean}}, open: lexer.TokenBase<any, any>): {[string]: any}
    --> key - required
    local all_keys: {string} = {}
    local parsed_keys: {[string]: span.Span} = {}
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

        if parsed_keys[key] then
            return diagnostics.report.create("Error")
                .with_code(codes.parser.DuplicateEntry)
                .with_message(`Duplicate entry "{key}" in struct`)
                .with_label(diagnostics.label.create(parsed_keys[key])
                    .with_color(diagnostics.style.color.cyan)
                    .with_message("Previously found here")
                )
                .with_label(diagnostics.label.create(name.span)
                    .with_color(diagnostics.style.color.red)
                    .with_message("Duplicate entry here")
                )
                .finish()
                .error()
        end

        local field = fields[key]
        if field == nil then
            report_expect_one_of_ident(parser, name.span, key, all_keys)
        end

        local _assign = expect(parser, ":")
        local value = field.expr(parser)

        result[key] = value
        parsed_keys[key] = name.span

        local index = table.find(required_keys, key)
        if index then
            table.remove(required_keys, index)
        end

        --> assume end of structure
        if peek(parser).kind ~= "," then
            break
        end

        expect(parser, ",")
    end

    local close = peek(parser)
    if #required_keys ~= 0 then
        local struct_span = span.merge(open.span, close.span)
        return diagnostics.report.create("Error")
            .with_code(codes.parser.MissingEntry)
            .with_message(`Expected struct to contain "{table.concat(required_keys, "\", ")}"`)
            .with_label(diagnostics.label.create(struct_span)
                .with_color(diagnostics.style.color.red)
                .with_message("Add missing keys in struct")
            )
            .finish()
            .error()
    end

    return result
end

local function generic(parser: Parser): ast.Generic
    local name = identifier(parser)
    local node_span = name.span

    local default: ast.Expression?;
    if peek(parser).kind == "=" then
        local _assign = expect(parser, "=")
        local expr = expression(parser)

        default = expr
        node_span = span.merge(name.span, expr.span)
    end

    return {
        kind = "generic",
        span = node_span,
        name = name,
        optional = default,
    }
end

local function generics(parser: Parser): ast.Generics
    local open = expect(parser, "<")
    local values: {ast.Generic} = seperated(parser, generic, ",", ">")
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
            span = token.span,
            kind = "boolean",
            value = true
        }
    elseif token.kind == "false" then
        return {
            span = token.span,
            kind = "boolean",
            value = false
        }
    end

    return report_expect_one_of(parser, token, {"true", "false"})
end

local function expr_number(parser: Parser): ast.ExprNumber
    local token = expect(parser, "number")
    return {
        span = token.span,
        kind = "number",
        value = tonumber(token.value) :: number
    }
end

local function expr_string(parser: Parser): ast.ExprString
    local token = expect(parser, "string")
    return {
        span = token.span,
        kind = "string",
        value = token.value
    }
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
        report_expect_one_of(parser, first, {"..", "number"})
    end

    local close = expect(parser, delimiter == "(" and ")" or "]" :: any)
    return {
        span = span.merge(open.span, close.span),
        kind = "range",

        max = max,
        min = min
    }
end

local function expr_primitive(parser: Parser): ast.ExprPrimitive
    local name = identifier(parser)
    local node_span = name.span

    --> generics
    local generics = {}
    if peek(parser).kind == "<" then
        local _open = expect(parser, "<")
        generics = seperated(parser, expression, ",", ">")

        local close = expect(parser, ">")
        node_span = span.merge(name.span, close.span)
    end
    
    --> range
    local range: ast.Range?
    if peek(parser).kind == "(" then
        range = expr_range(parser, "(")
    end

    return {
        span = node_span,
        kind = "primitive",

        name = name,
        range = range,
        generics = generics
    }
end

local function expr_reference(parser: Parser): ast.ExprReference
    local name = path_identifier(parser)
    local node_span = name.span
    
    --> generics
    local generics = {}
    if peek(parser).kind == "<" then
        local _open = expect(parser, "<")
        generics = seperated(parser, expression, ",", ">")

        local close = expect(parser, ">")
        node_span = span.merge(name.span, close.span)
    end

    return {
        span = node_span,
        kind = "reference",
        name = name,
        generics = generics
    }
end

local function expr_field(parser: Parser): ast.ExprField
    local name = escaped_identifier(parser)
    expect(parser, ":")
    local value = expression(parser)

    return {
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
        span = span.merge(open.span, close.span),
        kind = "struct",
        fields = fields
    }
end

local function expr_map(parser: Parser): ast.ExprMap
    local keyword = expect(parser, "map")
    
    --> open "{" delim
    expect(parser, "{")

    --> indexer
    expect(parser, "[")
    local indexer = expression(parser)
    expect(parser, "]")

    --> value
    expect(parser, ":")
    local value = expression(parser)

    --> close delim
    expect(parser, "}")

    return {
        span = span.merge(keyword.span, value.span),
        kind = "map",
        index = indexer,
        value = value
    }
end

local function expr_set(parser: Parser): ast.ExprSet
    local keyword = expect(parser, "set")
    expect(parser, "{")

    local values = seperated(parser, escaped_identifier, ",", "}")
    local close = expect(parser, "}")

    return {
        span = span.merge(keyword.span, close.span),
        kind = "set",
        values = values
    }
end

local function expr_enum_tag_variant(parser: Parser): ast.ExprTaggedEnumVariant
    --> variant name
    local name: ast.ExprBoolean | ast.Identifier
    local token = peek(parser)
    if token.kind == "true" or token.kind == "false" then
        name = expr_boolean(parser)
    else
        name = escaped_identifier(parser)
    end

    --> struct
    local value = expr_inlined_struct(parser)

    return {
        span = span.merge(name.span, value.span),
        kind = "variant",
        name = name,
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
        span = span.merge(open.span, close.span),
        kind = "pack",
        values = values
    }
end

local function expr_array(parser: Parser, previous: ast.Expression): ast.ExprArray
    local range = expr_range(parser, "[")
    return {
        span = span.merge(previous.span, range.span),
        kind = "array",
        range = range,
        value = previous,
    }
end

local function expr_optional(parser: Parser, value: ast.Expression): ast.ExprOptional
    local optional = expect(parser, "?")
    return {
        span = span.merge(value.span, optional.span),
        kind = "optional",
        value = value
    }
end

--- Parses a single expression or a pack of expressions
local function expr_pack_or_single(parser: Parser): ast.Expression | ast.ExprPack
    local token = peek(parser)
    if token.kind == "(" then
        return expr_pack(parser)
    end

    return expression(parser)
end

local function stat_type(parser: Parser): ast.StatType
    local keyword = expect(parser, "type")
    local name = identifier(parser)

    local generics = 
        if peek(parser).kind == "<" 
        then generics(parser) 
        else nil

    local _assign = expect(parser, "=")
    local value = expression(parser)

    return {
        span = span.merge(keyword.span, value.span),
        kind = "type",

        name = name,
        value = value,
        generics = generics,

        export = false
    }
end

local function stat_event(parser: Parser): ast.StatEvent
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
        span = span.merge(keyword.span, close.span),
        kind = "event",

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
        span = span.merge(keyword.span, close.span),
        kind = "scope",
        name = name,
        block = scope_block
    }
end

local function stat_option(parser: Parser): ast.StatOption
    local keyword = expect(parser, "option")
    local name = identifier(parser)

    local _assign = expect(parser, "=")
    local value = expression(parser)
    local stat_span = span.merge(keyword.span, value.span)

    return {
        span = stat_span,
        kind = "option",

        name = name,
        value = value,
    }
end

local function stat_function(parser: Parser): ast.StatFunction
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
        span = span.merge(keyword.span, close.span),
        kind = "function",

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
        span = name and span.merge(keyword.span, name.span) or span.merge(keyword.span, path.span),
        kind = "import",
        
        name = name,
        path = path
    }
end

function expression(parser: Parser): ast.Expression
    local token = peek(parser)
    local expr: ast.Expression?
    
    if token.kind == "word" then
        local word = token.value
        if primitives[word] then
            expr = expr_primitive(parser)
        else
            expr = expr_reference(parser)
        end
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
        return report_expect_one_of(parser, token, {"word", "string", "number", "true", "false"})
    end

    while peek(parser).kind == "[" do
        --> array
        expr = expr_array(parser, expr)

        --> optional
        local current = peek(parser)
        if current.kind == "?" then
            expr = expr_optional(parser, expr)
        end
    end

    --> optional
    do
        local current = peek(parser)
        if current.kind == "?" then
            expr = expr_optional(parser, expr)
        end
    end

    --> merge
    do
        local current = peek(parser)
        if current.kind == "&" then
            --> consume union symbol
            consume(parser)

            --> get left & right side
            local left = expr
            local right = expression(parser)

            --> return a union
            expr = {
                span = span.merge(left.span, right.span),
                kind = "union",
                left = left,
                right = right
            }
        end
    end

    return expr
end

function statement(parser: Parser): ast.Statement
    local token = peek(parser)
    if token.kind == "type" then
        return stat_type(parser)
    elseif token.kind == "import" then
        return stat_import(parser)
    elseif token.kind == "scope" then
        return stat_scope(parser)
    elseif token.kind == "event" then
        return stat_event(parser)
    elseif token.kind == "option" then
        return stat_option(parser)
    elseif token.kind == "function" then
        return stat_function(parser)
    end

	return report_expect_one_of(parser, token, { "type", "scope", "event", "struct", "function" })
end

function block(parser: Parser, is_scope: boolean?): ast.Block
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
        
        table.insert(statements, statement(parser))
    end

    return {
        kind = "block",
        statements = statements
    }
end

--- Returns an AST constructed from `tokens`, errors if invalid syntax is encountered
local function parse(tokens: {lexer.Token}): ast.Ast
    assert(#tokens > 0, "Tokens are empty")
    assert(tokens[#tokens] and tokens[#tokens].kind == "eof", "Final token should be eof")

    local parser: Parser = {
        tokens = tokens,
        
        index = 1,
        token = tokens[1],
        lookahead = tokens[2] or tokens[1],
    }

    return {
        kind = "ast",
        block = block(parser)
    }
end

--TODO: Remove
diagnostics.set_error_fn(function(text: string)
    require("@lune/stdio").ewrite(`{text}\n`)
    return error("something went wrong")
end)

return table.freeze({
    parse = parse
})