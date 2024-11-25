--!strict

local fs = require("@lune/fs")
local serde = require("@lune/serde")
local lexer = require("../src/compiler/lexer")
local parser = require("../src/compiler/parser")

local code = fs.readFile("./blink/small.blink")
local input = buffer.fromstring(code)

local tokens = lexer.tokenize(input)
local ast = parser.parse(input, tokens)

local function clean(tbl, cache)
    for key, value in tbl do
        if cache[value] then
            continue
        end

        if type(value) == "table" then
            cache[value] = true
            clean(value, cache)
        end

        if key == "span" then
            tbl[key] = nil
        end
    end
end

clean(ast, {})
fs.writeFile("./out/ast.json", serde.encode("json", ast, true))