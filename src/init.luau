local fs = require("@lune/fs")
local stdio = require("@lune/stdio")
local process = require("@lune/process")

local Parser = require("./Parser.luau")
local Generator = require("./Generator.luau")

local SourceParser = Parser.new()

local Arguments = process.args
if #Arguments ~= 1 then
    error(`Expected 1 argument, got {#Arguments} instead.`)
end

local SourcePath = Arguments[1]

stdio.write(stdio.color("cyan"))
print(`Reading source from {SourcePath}.`)
local Source = fs.readFile(SourcePath)

stdio.write(stdio.color("blue"))
print("Parsing source into AST.")
local AbstractSyntaxTree, Options = SourceParser:Parse(Source)

print(Options)

assert(Options.ClientOutput, "A client output path must be defined.")
assert(Options.ServerOutput, "A server output path must be defined.")

print("Parsing AST.")
fs.writeFile(`{Options.ServerOutput}`, Generator("Server", AbstractSyntaxTree, Options))
fs.writeFile(`{Options.ClientOutput}`, Generator("Client", AbstractSyntaxTree, Options))

stdio.write(stdio.color("green"))
print("Network files generated!")
stdio.write(stdio.color("white"))