local ty = require("@structures/ty")
local hir = require("@structures/hir")
local lir = require("@structures/lir")

type Lir = lir.Lir
type Hir = hir.Hir

type TyId = ty.TyId
type FnId = lir.FnId

export type Context = {
    read hir: Hir,
    read lir: Lir,
    read tys: {[TyId]: {
        read: FnId,
        write: FnId
    }},

    fn_id: number,
}

local function create(hir: Hir, lir: Lir): Context
    return {
        hir = hir,
        lir = lir,
        tys = {},
        fn_id = 0
    }
end

local function next_id(ctx: Context): number
    local current = ctx.fn_id
    ctx.fn_id += 1
    return current
end

return table.freeze({
    create = create,
    next_id = next_id
})