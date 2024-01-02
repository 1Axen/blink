local fs = require("@lune/fs")
local luau = require("@lune/luau")

local Bytecode = fs.readFile("./Bytecode.txt")
luau.load(Bytecode)()