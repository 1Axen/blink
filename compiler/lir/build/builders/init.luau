local binary = require("@self/binary")
local condition = require("@self/condition")
local constant = require("@self/constant")
local control = require("@self/control")
local fn = require("@self/fn")
local globals = require("@self/globals")
local library = require("@self/library")
local loop = require("@self/loop")
local projection = require("@self/projection")
local structure = require("@self/structure")
local ternary = require("@self/ternary")
local ty = require("@self/ty")
local unary = require("@self/unary")

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
	projection = projection,
})
