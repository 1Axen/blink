--!strict
--!native

-- Copyright (c) 2024 Axen

-- Permission is hereby granted, free of charge, to any person obtaining a copy
-- of this software and associated documentation files (the "Software"), to deal
-- in the Software without restriction, including without limitation the rights
-- to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
-- copies of the Software, and to permit persons to whom the Software is
-- furnished to do so, subject to the following conditions:

-- The above copyright notice and this permission notice shall be included in all
-- copies or substantial portions of the Software.

-- THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
-- IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
-- FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
-- AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
-- LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
-- OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
-- SOFTWARE.

local span = require("../util/span")
local location = require("../util/location")

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
    | TokenBase<"function">

    --> literals
    | TokenBase<"number", string>
    | TokenBase<"string", string>

    --> symbols
    | TokenBase<"=">
    | TokenBase<":">
    | TokenBase<",">
    | TokenBase<"..">
    | TokenBase<"?">

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

--> returns the numerical code of character
local function code(character: string): number
    return string.byte(character)
end

local QOUTE = code("\"")
local NEW_LINE = code("\n")
local UNDERSCORE = code("_")

local SYMBOLS = {
    [code("{")] = true,
    [code("<")] = true,
    [code("(")] = true,
    [code("}")] = true,
    [code(">")] = true,
    [code(")")] = true,
    [code(":")] = true,
    [code(",")] = true,
    [code("?")] = true,
    [code("=")] = true,
}

local function is_whitespace(byte: number): boolean
    return byte == code(" ") 
        or byte == code("\t")
        or byte == NEW_LINE
        or byte == code("\r")
        or byte == code("\v")
        or byte == code("\f")
end

local function is_letter(byte: number): boolean
    return (string.byte("a") <= byte and byte <= string.byte("z"))
        or (string.byte("A") <= byte and byte <= string.byte("Z"))
end

local function is_numeral(byte: number): boolean
    return string.byte("0") <= byte 
        and byte <= string.byte("9")
end

local function tokenize(input: buffer): {Token}
    --> lexer state
    local line = 1
    local position = 0
    local character = 0
    local length = buffer.len(input)

    local function peek(): number
        if position == length then
            return 0
        end
    
        return buffer.readu8(input, position)
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
        return buffer.readstring(input, start_position, position - start_position)
    end
    
    local function to_location()
        return location.create(position, line, character)
    end

    local tokens: {Token} = table.create(64) :: any
    
    local function next_token(): Token?
        local first = peek()
        local start = to_location()
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
            until not (is_letter(char) or is_numeral(char) or char == UNDERSCORE)
            
            local finish = to_location()
            local value = to_string(start_position)
            local value_span = span.create(start, finish)

            if value == "map" then
                return {kind = value, span = value_span}
            elseif value == "set" then
                return {kind = value, span = value_span}
            elseif value == "enum" then
                return {kind = value, span = value_span}
            elseif value == "type" then
                return {kind = value, span = value_span}
            elseif value == "event" then
                return {kind = value, span = value_span}
            elseif value == "struct" then
                return {kind = value, span = value_span}
            elseif value == "scope" then
                return {kind = value, span = value_span}
            elseif value == "option" then
                return {kind = value, span = value_span}
            elseif value == "function" then
                return {kind = value, span = value_span}
            end

            return {
                kind = "word",
                span = value_span,
                value = value
            }
        elseif is_numeral(first) then
            local char = first
            repeat
                char = advance_peek()
            until not (is_numeral(char) or char == UNDERSCORE)

            local finish = to_location()
            local value = to_string(start_position)

            return {
                kind = "number",
                span = span.create(start, finish),
                value = value
            }
        elseif first == QOUTE then
            local char = first
            repeat
                char = advance_peek()
            until (char == QOUTE)

            local finish = to_location()
            local value = to_string(start_position)
            
            return {
                kind = "string",
                span = span.create(start, finish),
                value = value
            }
        end

        if SYMBOLS[first] then
            return { kind = string.char(first) :: any, span = span.create(start, start) }
        elseif first == code(".") and peek() == code(".") then
            advance()
            return { kind = "..", span = span.create(start, to_location()) }
        end

        return {
            kind = "error",
            span = span.create(start, start),
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