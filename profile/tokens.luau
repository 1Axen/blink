--!strict

local fs = require("@lune/fs")
local serde = require("@lune/serde")
local lexer = require("../src/compiler/lexer")

local code = fs.readFile("./blink/small.blink")
local input = buffer.fromstring(code)
local tokens = lexer.tokenize(input)

--> remove buffers
local function sanitize(tbl: {[any]: any}, visited:{ [{ [any]: any }]: true })
    if visited[tbl] then
        return tbl
    end

    visited[tbl] = true

    if table.isfrozen(tbl) then
        tbl = table.clone(tbl)
        visited[tbl] = true
    end

    for key, value in tbl do
        if type(value) == "buffer" then
            tbl[key] = "buffer"
        elseif type(value) == "table" then
            tbl[key] = sanitize(value, visited)
        end
    end

    return tbl
end

sanitize(tokens, {})
fs.writeFile("./tokens.json", serde.encode("json", tokens, true))

local fs = require("@lune/fs")
local input = buffer.fromstring(fs.readFile("./blink/small.blink"))
print(`"{buffer.readstring(input, 48, 1)}"`)