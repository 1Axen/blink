--!strict

local lir = require("@structures/lir")
local terminator = require("./terminator")

type Terminator = lir.Terminator
type BasicBlock = lir.BasicBlock

local function create(index: number, scope: number?, term: Terminator?): BasicBlock
    return {
        type = "block",
        index = index,
        scope = scope or 0,
        statements = {},
        terminator = term or terminator.none() :: Terminator
    }
end

return table.freeze({
    create = create,
})