--!strict
--!native
--!optimize 2

local span = require("@util/span")
local location = require("@util/location")

type Span = span.Span
type Location = location.Location

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
    | TokenBase<"set">
    | TokenBase<"map">
    | TokenBase<"enum">
    | TokenBase<"type">
    | TokenBase<"scope">
    | TokenBase<"event">
    | TokenBase<"struct">
    | TokenBase<"option">
    | TokenBase<"export">
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

local function tokenize(text: buffer): {Token}
    --> lexer state
    local line = 1
    local position = 0
    local character = 0

    local length = buffer.len(text)

    local function peek(): number
        if position == length then
            return 0
        end
    
        return buffer.readu8(text, position)
    end

    local function lookahead(): number
        if position >= (length - 1) then
            return 0
        end

        return buffer.readu8(text, position + 1)
    end
    
    local function advance()
        position = math.min(position + 1, length)
        character += 1
    end

    local function advance_peek(): number
        advance()
        return peek()
    end
    
    local function newline()
        line += 1
        character = -1
    end
    
    local function to_string(start_position: number)
        return buffer.readstring(text, start_position, position - start_position)
    end
    
    local function last_location()
        return location.create(position - 1, line, character - 1)
    end

    local function current_location()
        return location.create(position, line, character)
    end

    local tokens: {Token} = table.create(64) :: any
    
    local function next_token(): Token?
        local first = peek()
        local start = current_location()
        local start_position = position

        --> eof
        if first == 0 then
            return {
                kind = "eof",
                span = span.create(start, start)
            }
        end

        --> whitespace is lost when lexed, lossy lexer :(
        if is_whitespace(first) then
            --> keep clearing whitespace
            local char = first
            repeat
                if char == NEW_LINE then
                    newline()
                end

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
            
            local finish = last_location()
            local value = to_string(start_position)
            local value_span = span.create(start, finish)
            
            if 
                value == "set"
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

            local finish = last_location()
            local value = to_string(start_position)

            return {
                kind = "number",
                span = span.create(start, finish),
                value = value
            }
        elseif first == QOUTE then
            local char = advance_peek()
            while char ~= 0 and char ~= QOUTE do
                char = advance_peek()
            end

            advance()

            local finish = last_location()
            local value = to_string(start_position)
            
            return {
                kind = "string",
                span = span.create(start, finish),
                value = value
            }
        end

        advance()
        
        local value_span = span.create(start, start)
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
                return { kind = "..", span = span.create(start, last_location()) }
            end

            return { kind = ".", span = value_span }
        elseif first == string.byte("&") then
            return { kind = "&", span = value_span }
        end

        return {
            kind = "error",
            span = value_span,
            value = to_string(start_position)
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