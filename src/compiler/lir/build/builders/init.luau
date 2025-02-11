local fn = require("./fn")
local ty = require("./ty")
local loop = require("./loop")
local unary = require("./unary")
local binary = require("./binary")
local ternary = require("./ternary")
local control = require("./control")
local wrapper = require("./wrapper")
local library = require("./library")
local constant = require("./constant")
local condition = require("./condition")
local projection = require("./projection")

export type Builder = fn.Builder

return table.freeze({
    fn = fn,
    ty = ty,
    loop = loop,
    unary = unary,
    binary = binary,
    ternary = ternary,
    wrapper = wrapper,
    control = control,
    library = library,
    constant = constant,
    condition = condition,
    projection = projection
})