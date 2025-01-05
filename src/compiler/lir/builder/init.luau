--!strict

local fn = require("./fn")
local loop = require("./loop")
local control = require("./control")
local library = require("./library")
local constant = require("./constant")
local condition = require("./condition")
local projection = require("./projection")

local unary = require("./operation/unary")
local binary = require("./operation/binary")

return table.freeze({
    fn = fn,
    loop = loop,
    control = control,
    library = library,
    constant = constant,
    condition = condition,
    operation = {
        unary = unary,
        binary = binary,
    },
    projection = projection
})