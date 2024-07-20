local fs = require("@lune/fs")

local span = require("../src/util/span")
local style = require("../src/util/style")
local diagnostics = require("../src/util/diagnostics")

local code = [[def five = match() in {
    () => 5,
    () => "5",
}
    
def six =
    five
    + 1]]


diagnostics.report.create("Error", "test.error", code)
    .with_code(3)
    .with_message("Incompatible types")
    .with_label(
        diagnostics.label.create(span.create(code, 35, 35))
            .with_message("This is of type Nat")
            .with_color(style.color.purple)
    )
    .with_label(
        diagnostics.label.create(span.create(code, 48, 50))
            .with_message("This is of type Str")
            .with_color(style.color.green)
    )
    .with_label(
        diagnostics.label.create(span.create(code, 11, 53))
            .with_message("The values are outputs of this expression")
            .with_color(style.color.cyan)
    )
    .with_note("Outputs of expressions must coerce to the same type")
    .finish()
    .print();
