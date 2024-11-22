--!strict
--!optimize 2

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
    | TokenBase<".">
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

    local function to_span(start: Location)
        return span.create(start, to_location())
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
            until not (is_letter(char) or is_digit(char) or char == UNDERSCORE)
            
            local finish = to_location()
            local value = to_string(start_position)
            local value_span = span.create(start, finish)
            
            if 
                value == "set"
                or value == "map"
                or value == "type"
                or value == "enum"
                or value == "event"
                or value == "scope"
                or value == "struct"
                or value == "option"
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
                    decimal = true
                end

                char = advance_peek()
            until not (is_digit(char) or char == UNDERSCORE or (char == DOT and decimal == false))

            local finish = to_location()
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

            local finish = to_location()
            local value = to_string(start_position)
            
            return {
                kind = "string",
                span = span.create(start, finish),
                value = value
            }
        elseif first == DOT then
            local char = advance_peek()
            if char == DOT then
                advance()
                return { kind = "..", span = to_span(start) }
            end

            return { kind = ".", span = span.create(start, start) }
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