local fs = require("@lune/fs") 
local luau = require("@lune/luau")

local Source = fs.readFile("./Bundled.luau")
Source = ("--!native\n\n" .. Source)
fs.removeFile("./Bundled.luau")
fs.writeFile("../DeclareNet/Bytecode.txt", 
    luau.compile(Source, {
        optimizationLevel = 2
    })
)