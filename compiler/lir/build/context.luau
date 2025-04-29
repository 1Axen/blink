local ty = require("@ty/types")
local hir = require("@hir/types")
local lir = require("@lir/types")

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

local function next_id(ctx: Context): FnId
    local current = ctx.fn_id
    ctx.fn_id += 1
    return current :: any
end

return table.freeze({
    create = create,
    next_id = next_id
})