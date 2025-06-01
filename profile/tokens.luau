--!strict

local file = require("@util/file")
local fs = require("@lune/fs")
local lexer = require("@compiler/lexer")
local serde = require("@lune/serde")

local source = fs.readFile("./blink/small.blink")
local input = file.from_source("small", source)
local tokens = lexer.tokenize(input)

fs.writeFile("./out/tokens.json", serde.encode("json", tokens, true))
