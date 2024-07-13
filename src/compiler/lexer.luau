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
    | "Unknown" | "EndOfFile"

export type Delimiter = 
    "Brace" | "Arrow" | "Round" | "Square"

export type Symbol = 
    "Equal" | "Colon" | "Comma" | "DotDot" | "Question"

export type Token = {
    type: Types,
    data: any,
    span: span.Span
}

type Matcher = {
    type: Types,
    pattern: string,
    transformer: ((text: string) -> any)?,
}

local SYMBOLS: {[string]: Symbol} = {
    ["="] = "Equal",
    [":"] = "Colon",
    [","] = "Comma",
    ["?"] = "Question",
}

local DELIMITERS: {[string]: Delimiter} = {
    ["{"] = "Brace",
    ["}"] = "Brace",
    ["<"] = "Arrow",
    [">"] = "Arrow",
    ["("] = "Round",
    [")"] = "Round",
    ["["] = "Square",
    ["]"] = "Square",
}

local WHITESPACE = "^%s+"

local TOKEN_MATCHERS: {Matcher} = {
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
        pattern = "^[{%[%(<]",
        transformer = function(text: string): Delimiter
            return DELIMITERS[text]
        end
    },
    {
        type = "Close",
        pattern = "^[}%]%)>]",
        transformer = function(text: string): Delimiter
            return DELIMITERS[text]
        end
    },
    {
        type = "Symbol",
        pattern = "^%.%.",
        transformer = function(text: string): Symbol
            return "DotDot"
        end
    },
    {
        type = "Symbol",
        pattern = "^[?:=,]",
        transformer = function(text: string): Symbol
            return SYMBOLS[text]
        end
    },

    {
        type = "Unknown",
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

        for _, matcher in TOKEN_MATCHERS do
            local start, finish = string.find(code, matcher.pattern, index)
            if not start or not finish then
                continue
            end

            local token_span = span.create(code, start, finish)

            local text = token_span.text
            local data = if matcher.transformer then matcher.transformer(text) else text

            index += #text
            table.insert(tokens, {
                type = matcher.type,
                data = data,
                span = token_span
            })

            break
        end
    end

    table.insert(tokens, {
        type = "EndOfFile",
        span = span.create(code, length + 1, length + 1)
    })

    return tokens
end

return lexer