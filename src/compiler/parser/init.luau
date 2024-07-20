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

local span = require("../../util/span")
local lexer = require("../lexer")

export type Nodes = 
    "Block"
    | "Type" | "Event" | "Option" | "Function" | "Namespace" | "Import"
    | "Primitive" | "Set" | "Enum" | "Interface"
    | "Keyword" | "Identifier" | "Number" | "String" | "Boolean"
    | "Assignment" | "Open" | "Close"

export type Node = {
    type: string,
    span: span.Span,
    nodes: {Node},
}

type Parser = {
    code: string,
    index: number,
    tokens: {lexer.Token},

    get: () -> lexer.Token,
    next: () -> lexer.Token?,
}

local function statement(parser: Parser): Node?
    
end

local function parse(code: string, tokens: {lexer.Token}): Node
    local body: Node = {
        type = "Block",
        span = span.create(code, 1, #code),
        nodes = {}
    }

    local parser = {
        code = code,
        index = 1,
        tokens = tokens
    } 

    parser.get = function()
        return parser.tokens[parser.index]
    end

    parser.next = function()
        local token = parser.tokens[parser.index]
        parser.index += 1
        return token
    end

    while true do
        local token = parser.get()
        if token.type == "EndOfFile" then
            break
        end

        local stamement_node = statement(parser)
        if not stamement_node then
            break
        end

        table.insert(body.nodes, stamement_node)
    end

    return body
end

return {
    parse = parse
}