--!strict

local lir = require("@compiler/structures/lir")

local loop = require("./loop")
local terminator = require("./terminator")

type Terminator = lir.Terminator
type BasicBlock = lir.BasicBlock

local function create(scope: number?, term: Terminator?): BasicBlock
    return {
        kind = "block",
        scope = scope or 0,
        statements = {},
        terminator = term or terminator.none() :: Terminator
    }
end

return table.freeze({
    create = create,
})