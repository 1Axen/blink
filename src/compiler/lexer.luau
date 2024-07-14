--!strict

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

export type Types = 
    "Word" | "Number" | "String"
    | "Open" | "Close" | "Symbol"
    | "Error" | "EndOfFile"

export type Delimiter = 
    "Brace" | "Arrow" | "Round"

export type Symbols = 
    "Equal" | "Colon" | "Comma" | "DotDot" | "Question" | "Ampersand"

export type Token<T = unknown> = {
    type: Types,
    data: T,
    span: span.Span
}

export type Word = Token<string>
export type Number = Token<number>
export type String = Token<string>
export type Open = Token<Delimiter>
export type Close = Token<Delimiter>
export type Symbol = Token<Symbols>
export type Error = Token<string>
export type EndOfFile = Token<nil>

type Matcher = {
    type: Types,
    pattern: string,
    transformer: ((text: string) -> any)?,
}

local SYMBOLS: {[string]: Symbols} = {
    ["="] = "Equal",
    [":"] = "Colon",
    [","] = "Comma",
    ["?"] = "Question",
    ["&"] = "Ampersand"
}

local DELIMITERS: {[string]: Delimiter} = {
    ["{"] = "Brace",
    ["}"] = "Brace",
    ["<"] = "Arrow",
    [">"] = "Arrow",
    ["("] = "Round",
    [")"] = "Round",
}

local WHITESPACE = "^%s+"

local LEXEMES: {Matcher} = {
    {
        type = "Word",
        pattern = "^[_%a][_%w]*"
    },
    {
        type = "Number",  
        pattern = "^%d+",
        transformer = tonumber
    },
    {
        type = "String",
        pattern = '^".-"',
        transformer = function(text: string): string
            return string.sub(text, 2, #text - 1)
        end
    },

    {
        type = "Open",
        pattern = "^[{%(<]",
        transformer = function(text: string): Delimiter
            return DELIMITERS[text]
        end
    },
    {
        type = "Close",
        pattern = "^[}%)>]",
        transformer = function(text: string): Delimiter
            return DELIMITERS[text]
        end
    },
    {
        type = "Symbol",
        pattern = "^%.%.",
        transformer = function(text: string): Symbols
            return "DotDot"
        end
    },
    {
        type = "Symbol",
        pattern = "^[?:=,&]",
        transformer = function(text: string): Symbols
            return SYMBOLS[text]
        end
    },

    {
        type = "Error",
        pattern = "^.",
    }   
}

local lexer = {}

function lexer.tokenize(code: string): {Token}
    local index = 1
    local length = #code
    local tokens: {Token} = table.create(64)

    while (index <= length) do
        local _, whitespace_finish = string.find(code, WHITESPACE, index)
        if whitespace_finish then
            index = whitespace_finish + 1
            continue
        end

        for _, lexeme in LEXEMES do
            local start, finish = string.find(code, lexeme.pattern, index)
            if not start or not finish then
                continue
            end

            local token_span = span.create(code, start, finish)
        
            local text = token_span.text
            local transformer = lexeme.transformer
            
            local data = if transformer then transformer(text) else text

            index += #text
            table.insert(tokens, {
                type = lexeme.type,
                data = data,
                span = token_span
            })

            break
        end
    end

    table.insert(tokens, {
        type = "EndOfFile",
        span = span.create(code, index, index)
    })

    return tokens
end

return lexer