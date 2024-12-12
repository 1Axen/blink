--!strict

local fs = require("@lune/fs")

local span = require("../src/util/span")
local style = require("../src/util/style")
local lexer = require("../src/compiler/lexer")
local location = require("../src/util/location")
local diagnostics = require("../src/util/diagnostics")

local code = fs.readFile("./blink/diagnostics.blink")
local input = buffer.fromstring(code)
local tokens = lexer.tokenize(input)

diagnostics.report.create("Error", "diagnostics.blink", input)
    .with_code(1)
    .with_message("A test error")
    .with_label(
        diagnostics.label.create(tokens[1].span)
            .with_color(style.color.purple)
            .with_message("This is a keyword")
    )
    .with_label(
        diagnostics.label.create(tokens[8].span)
            .with_color(style.color.purple)
            .with_message("This is a number")
    )
    .with_label(
        diagnostics.label.create(span.merge(tokens[17].span, tokens[19].span))
            .with_color(style.color.bright_purple)
            .with_message("This is a nested struct")
    )
    .with_label(
        diagnostics.label.create(span.merge(tokens[10].span, tokens[20].span))
            .with_color(style.color.cyan)
            .with_message("This is a struct")
    )
    .with_note("An informative note")
    .finish()
    .print()