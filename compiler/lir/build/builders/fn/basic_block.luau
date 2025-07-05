--!strict

local lir = require("@lir/types")
local terminator = require("./terminator")

type Terminator = lir.Terminator
type BasicBlock = lir.BasicBlock

local function create(scope: number?, term: Terminator?): BasicBlock
	return {
		type = "block",
		scope = scope or 0,
		statements = {},
		terminator = term or terminator.none() :: Terminator,
	}
end

return table.freeze({
	create = create,
})
