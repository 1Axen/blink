--!strict

local fs = require("@lune/fs")
local serde = require("@lune/serde")

local file = require("@util/file")
local lexer = require("@compiler/lexer")
local parser = require("@compiler/parser")

local input = file.from_source(fs.readFile("./blink/small.blink"))

local tokens = lexer.tokenize(input)
local ast = parser.parse(tokens)

local function clean(tbl: any, cache)
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

clean(ast.body, {})
fs.writeFile("./out/ast.json", serde.encode("json", ast.body, true))