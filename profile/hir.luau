--!strict

local fs = require("@lune/fs")
local serde = require("@lune/serde")

local file = require("@util/file")
local builder = require("@util/builder")

local hir = require("@compiler/hir")
local lexer = require("@compiler/lexer")
local parser = require("@compiler/parser")

local fmt_hir = require("@format/hir")

local input = file.from_source(fs.readFile("./blink/small.blink"))

local tokens = lexer.tokenize(input)
local ast = parser.parse(file.id(input), tokens)
local hir = hir.from_files({[input.id] = ast})

local function clean(t: any): any
    local replaced = {}
    for key, value in t do
        local str_key = tostring(key)
        replaced[str_key] = value
    end

    return replaced
end

local format_builder = builder.create()
fmt_hir(hir, format_builder)
print(builder.to_string(format_builder))

hir.tys = clean(hir.tys)
hir.decls = clean(hir.decls)
hir.scopes = clean(hir.scopes)

fs.writeFile("./out/hir.json", serde.encode("json", hir, true))