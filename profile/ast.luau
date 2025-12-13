--!strict

local fs = require("@std/fs")
local json = require("@std/json")

local file = require("@util/file")
local lexer = require("@compiler/lexer")
local parser = require("@compiler/parser")

local input = file.from_source("small.blink", fs.readfiletostring("./blink/small.blink"))

local tokens = lexer.tokenize(input)
local ast = parser.parse(input, tokens)

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
fs.writestringtofile("./out/ast.json", json.serialize(ast.body :: any, true))
