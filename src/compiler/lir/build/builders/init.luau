local fn = require("./fn")
local ty = require("./ty")
local loop = require("./loop")
local unary = require("./unary")
local binary = require("./binary")
local globals = require("./globals")
local ternary = require("./ternary")
local control = require("./control")
local library = require("./library")
local constant = require("./constant")
local condition = require("./condition")
local structure = require("./structure")
local projection = require("./projection")

export type Builder = fn.Builder

return table.freeze({
    fn = fn,
    ty = ty,
    loop = loop,
    unary = unary,
    binary = binary,
    globals = globals,
    ternary = ternary,
    control = control,
    library = library,
    constant = constant,
    structure = structure,
    condition = condition,
    projection = projection
})