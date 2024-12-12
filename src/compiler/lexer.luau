--!strict
--!native
--!optimize 2

local file = require("@util/file")
local span = require("@util/span")

type Span = span.Span
type File = file.File

export type TokenBase<Kind, Value = nil> = {
    kind: Kind,
    span: span.Span,
    value: Value
}

export type Token = 
    --> trivia
    | TokenBase<"attribute", string>

    --> words
    | TokenBase<"word", string>
    | TokenBase<"as">
    | TokenBase<"set">
    | TokenBase<"map">
    | TokenBase<"enum">
    | TokenBase<"type">
    | TokenBase<"scope">
    | TokenBase<"event">
    | TokenBase<"struct">
    | TokenBase<"option">
    | TokenBase<"export">
    | TokenBase<"import">
    | TokenBase<"function">

    --> literals
    | TokenBase<"true">
    | TokenBase<"false">
    | TokenBase<"number", string>
    | TokenBase<"string", string>

    --> symbols
    | TokenBase<".">
    | TokenBase<"=">
    | TokenBase<":">
    | TokenBase<",">
    | TokenBase<"&">
    | TokenBase<"?">
    | TokenBase<"..">

    --> delimiters
    | TokenBase<"{">
    | TokenBase<"<">
    | TokenBase<"(">
    | TokenBase<"[">
    | TokenBase<"}">
    | TokenBase<">">
    | TokenBase<")">
    | TokenBase<"]">

    | TokenBase<"error", string>
    | TokenBase<"eof">

local DOT = string.byte(".")
local QOUTE = string.byte("\"")
local NEW_LINE = string.byte("\n")
local UNDERSCORE = string.byte("_")

local function is_whitespace(byte: number): boolean
    return byte == string.byte(" ") 
        or byte == string.byte("\t")
        or byte == NEW_LINE
        or byte == string.byte("\r")
        or byte == string.byte("\v")
        or byte == string.byte("\f")
end

local function is_letter(byte: number): boolean
    return (string.byte("a") <= byte and byte <= string.byte("z"))
        or (string.byte("A") <= byte and byte <= string.byte("Z"))
end

local function is_digit(byte: number): boolean
    return string.byte("0") <= byte and byte <= string.byte("9")
end

local function tokenize(input: File): {Token}
    local id = file.id(input)
    local length = file.length(input)
    local content = file.content(input)

    --> lexer state
    local position = 0

    local function peek(): number
        if position == length then
            return 0
        end
    
        return buffer.readu8(content, position)
    end

    local function lookahead(): number
        if position >= (length - 1) then
            return 0
        end

        return buffer.readu8(content, position + 1)
    end
    
    local function advance()
        position = math.min(position + 1, length)
    end

    local function advance_peek(): number
        advance()
        return peek()
    end
    
    local function to_string(start_position: number)
        return buffer.readstring(content, start_position, position - start_position)
    end
    
    local function last_position()
        return (position - 1)
    end

    local tokens: {Token} = table.create(64) :: any
    
    local function next_token(): Token?
        local first = peek()
        local start = position

        --> eof
        if first == 0 then
            return {
                kind = "eof",
                span = span.create(start, start, id)
            }
        end

        --> whitespace is lost when lexed, lossy lexer :(
        if is_whitespace(first) then
            --> keep clearing whitespace
            local char = first
            repeat
                char = advance_peek()
            until not (is_whitespace(char))

            return
        --> word, can't start with numeral
        elseif is_letter(first) or first == UNDERSCORE then
            --> consume full word
            local char = first
            repeat
                char = advance_peek()
            until not (is_letter(char) or is_digit(char) or char == UNDERSCORE)
            
            local finish = last_position()
            local value = to_string(start)
            local value_span = span.create(start, finish, id)
            
            if 
                value == "set"
                or value == "as"
                or value == "map"
                or value == "type"
                or value == "enum"
                or value == "true"
                or value == "false"
                or value == "event"
                or value == "scope"
                or value == "struct"
                or value == "option"
                or value == "export"
                or value == "import"
                or value == "function"
            then
                return {kind = value :: any, span = value_span}
            end

            return {
                kind = "word",
                span = value_span,
                value = value
            }
        elseif is_digit(first) or first == string.byte("-") then
            local char = first
            local decimal = false

            if char == string.byte("-") then
                char = advance_peek()
            end

            repeat
                if char == DOT then
                    if is_digit(lookahead()) == false then
                        break
                    end

                    decimal = true
                end

                char = advance_peek()
            until not (is_digit(char) or char == UNDERSCORE or (char == DOT and decimal == false))

            local finish = last_position()
            local value = to_string(start)

            return {
                kind = "number",
                span = span.create(start, finish, id),
                value = value
            }
        elseif first == QOUTE then
            local char = advance_peek()
            while char ~= 0 and char ~= QOUTE do
                char = advance_peek()
            end

            advance()

            local finish = last_position()
            local value = to_string(start)
            
            return {
                kind = "string",
                span = span.create(start, finish, id),
                value = value
            }
        end

        advance()
        
        local value_span = span.create(start, start, id)
        if first == string.byte("{") then
            return { kind = "{", span = value_span }
        elseif first == string.byte("<") then
            return { kind = "<", span = value_span }
        elseif first == string.byte("(") then
            return { kind = "(", span = value_span }
        elseif first == string.byte("[") then
            return { kind = "[", span = value_span }
        elseif first == string.byte("}") then
            return { kind = "}", span = value_span }
        elseif first == string.byte(">") then
            return { kind = ">", span = value_span }
        elseif first == string.byte(")") then
            return { kind = ")", span = value_span }
        elseif first == string.byte("]") then
            return { kind = "]", span = value_span }
        elseif first == string.byte(":") then
            return { kind = ":", span = value_span }
        elseif first == string.byte(",") then
            return { kind = ",", span = value_span }
        elseif first == string.byte("?") then
            return { kind = "?", span = value_span }
        elseif first == string.byte("=") then
            return { kind = "=", span = value_span }
        elseif first == string.byte(".") then
            if peek() == string.byte(".") then
                advance()
                return { kind = "..", span = span.create(start, last_position(), id) }
            end

            return { kind = ".", span = value_span }
        elseif first == string.byte("&") then
            return { kind = "&", span = value_span }
        end

        return {
            kind = "error",
            span = value_span,
            value = to_string(start)
        }
    end

    while true do
        local token = next_token()
        if token == nil then
            continue
        end

        table.insert(tokens, token)
          
        --> end of file
        if token.kind == "eof" then
            break
        end
    end

    return tokens
end

return table.freeze({
    tokenize = tokenize
})