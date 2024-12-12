--!strict

local fs = require("@lune/fs")

local file = require("@util/file")
local lexer = require("@compiler/lexer")
local parser = require("@compiler/parser")
local analysis = require("@compiler/analysis")

local code = file.from_source(fs.readFile("./blink/small.blink"))
local tokens = lexer.tokenize(code)
local ast = parser.parse(tokens)
analysis.analyse(ast)