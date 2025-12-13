--!strict

local file = require("@util/file")
local fs = require("@std/fs")

local hir = require("@compiler/hir")
local lexer = require("@compiler/lexer")
local parser = require("@compiler/parser")

local fmt_hir = require("@compiler/hir/format")
local input = file.from_source("bench.blink", fs.readfiletostring("./blink/bench.blink"))

local tokens = lexer.tokenize(input)
local ast = parser.parse(input, tokens)
local file_hir = hir.from_files({ [input.id] = ast })

print(fmt_hir(file_hir))
