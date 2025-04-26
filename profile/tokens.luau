--!strict

local fs = require("@lune/fs")
local serde = require("@lune/serde")
local file = require("@util/file")
local lexer = require("@compiler/lexer")

local source = fs.readFile("./blink/small.blink")
local input = file.from_source("small", source)
local tokens = lexer.tokenize(input)

fs.writeFile("./out/tokens.json", serde.encode("json", tokens, true))