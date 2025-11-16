--!strict

local file = require("@util/file")
local fs = require("@lute/fs")
local json = require("@std/json")
local lexer = require("@compiler/lexer")

local source = fs.readfiletostring("./blink/small.blink")
local input = file.from_source("small", source)
local tokens = lexer.tokenize(input)

fs.writestringtofile("./out/tokens.json", json.serialize(tokens :: any, true))
