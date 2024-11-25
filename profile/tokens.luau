--!strict

local fs = require("@lune/fs")
local serde = require("@lune/serde")
local lexer = require("../src/compiler/lexer")

local code = fs.readFile("./blink/small.blink")
local input = buffer.fromstring(code)
local tokens = lexer.tokenize(input)

fs.writeFile("./out/tokens.json", serde.encode("json", tokens, true))