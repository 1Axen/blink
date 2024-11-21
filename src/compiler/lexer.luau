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

export type Keywords = "set" | "map" | "type" | "enum" | "event" 
    | "scope" | "struct" | "option" | "function"

export type TokenBase<Kind, Value = nil> = {
    kind: Kind,
    span: span.Span,
    value: Value
}

export type Word = TokenBase<"word", string>
export type Keyword = TokenBase<"keyword", Keywords>
export type Number = TokenBase<"number", string>
export type String = TokenBase<"string", string>
export type Attribute = TokenBase<"attribute", string>
export type Error = TokenBase<"error", string>
export type EndOfFile = TokenBase<"eof">

export type Token = 
    --> words
     Word
    | Keyword
    --> literals
    | Number
    | String
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
    | TokenBase<"}">
    | TokenBase<">">
    | TokenBase<")">
    --> control flow
    | Error
    | EndOfFile

--> returns the numerical code of character
local function code(character: string): number
    return string.byte(character)
end

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

local KEYWORDS: {[Keywords]: true} = {
    set = true,
    map = true,
    enum = true,
    type = true,
    event = true,
    scope = true,
    struct = true,
    option = true,
    ["function"] = true,
}

local function is_whitespace(byte: number): boolean
    return byte == code(" ") 
        or byte == code("\t")
        or byte == code("\n")
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

    local last_line = line
    local last_position = position
    local last_character = character

    local function peek(): number
        if position >= length then
            return 0
        end
    
        return buffer.readu8(input, position)
    end
    
    local function save()
        last_line = line
        last_position = position
        last_character = character
    end

    local function advance()
        save()
        position += 1
        character += 1
    end
    
    local function newline()
        save()
        line += 1
        character = -1
    end
    
    local function to_string(start: Location)
        local start_position = start.position
        return buffer.readstring(input, start_position, position - start_position)
    end
    
    local function to_location()
        return location.create(position, line, character)
    end

    local function to_last_location()
        return location.create(last_position, last_line, last_character)
    end

    local tokens: {Token} = table.create(64) :: any
    
    local function next_token(): Token?
        local byte = peek()
        local start = to_location()

        --> eof
        if byte == 0 then
            return {
                kind = "eof",
                span = span.create(start, start)
            }
        end

        --> first byte is always consumed
        advance()

        --> whitespace is lost when lexed, lossy lexer :(
        if is_whitespace(byte) then
            --> keep clearing whitespace
            local temp = peek()
            while is_whitespace(temp) do
                if temp == code("\n") then
                    newline()
                end

                advance()
                temp = peek()
            end

            return
        --> word, can't start with numeral
        elseif is_letter(byte) or byte == code("_") then
            --> consume full word
            local temp = peek()
            while is_letter(temp) or is_numeral(temp) or temp == code("_") do
                advance()
                temp = peek()
            end
            
            local finish = to_last_location()
            local value = to_string(start)
            local value_span = span.create(start, finish)

            if KEYWORDS[value :: any] == true then
                return {kind = "keyword", span = value_span, value = value :: Keywords}
            end

            return {
                kind = "word",
                span = value_span,
                value = value
            }
        elseif is_numeral(byte) then
            byte = peek()

            while is_numeral(byte) or byte == code("_") do
                advance()
                byte = peek()
            end

            local finish = to_last_location()
            local value = to_string(start)

            return {
                kind = "number",
                span = span.create(start, finish),
                value = value
            }
        elseif byte == code("\"") then
            while peek() ~= code("\"") do
                advance()
            end

            advance()

            local finish = to_last_location()
            local value = to_string(start)
            
            return {
                kind = "string",
                span = span.create(start, finish),
                value = value
            }
        end

        if SYMBOLS[byte] then
            return { kind = string.char(byte) :: any, span = span.create(start, start) }
        elseif byte == code(".") and peek() == code(".") then
            advance()
            return { kind = "..", span = span.create(start, to_last_location()) }
        end

        return {
            kind = "error",
            span = span.create(start, start),
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