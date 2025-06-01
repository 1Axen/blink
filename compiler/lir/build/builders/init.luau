local fn = require("@self/fn")
local ty = require("@self/ty")
local loop = require("@self/loop")
local unary = require("@self/unary")
local binary = require("@self/binary")
local globals = require("@self/globals")
local ternary = require("@self/ternary")
local control = require("@self/control")
local library = require("@self/library")
local constant = require("@self/constant")
local condition = require("@self/condition")
local structure = require("@self/structure")
local projection = require("@self/projection")

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