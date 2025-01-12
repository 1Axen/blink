--!strict
--!native
--!optimize 2

local ty = require("@compiler/structures/ty")
local hir = require("@compiler/structures/hir")
local lir = require("@compiler/structures/lir")

local fn = require("./builders/fn")
local loop = require("./builders/loop")
local unary = require("./builders/unary")
local binary = require("./builders/binary")
local control = require("./builders/control")
local library = require("./builders/library")
local constant = require("./builders/constant")
local condition = require("./builders/condition")
local projection = require("./builders/projection")

local panic = require("@util/panic")

type Lir = lir.Lir
type Hir = hir.Hir

type Ty = ty.Ty

type Fn = lir.Fn
type FnId = lir.FnId

type Context = {
    read hir: Hir,
    read lir: Lir,

    fn_id: number,
}

local READ_PREFIX = "read_"
local WRITE_PREFIX = "write_"

local TYPE_PREFIX = "type_"
local EVENT_PREFIX = "event_"
local FUNCTION_PREFIX = "function_"

local function fn_id(ctx: Context, fn: Fn): FnId
    local current = ctx.fn_id
    ctx.fn_id = (current + 1)
    return current :: any
end

local function returnn(ty: Ty): lir.Return
    return {
        kind = "return",
        ty = ty
    }
end

local function argument(ty: Ty, name: string?): lir.Argument
    return {
        kind = "argument",
        ty = ty,
        name = name
    }
end

local function decl_type(ctx: Context, decl: hir.Type): lir.Type
    
end

local function decl_event(ctx: Context, decl: hir.Event): lir.Event
    
end

local function decl_function(ctx: Context, decl: hir.Function): lir.Function
    
end

local function build_lir(hir: hir.Hir): lir.Lir
    local lir: Lir = {
        fns = {},
        types = {},
        events = {},
        functions = {}
    }

    local ctx: Context = {
        lir = lir,
        hir = hir,
        fn_id = 0
    }

    for decl_id, decl in hir.decls do
        if decl.kind == "type" then
            lir.types[decl_id] = decl_type(ctx, decl)
            continue
        elseif decl.kind == "event" then
            lir.events[decl_id] = decl_event(ctx, decl)
            continue
        elseif decl.kind == "function" then
            lir.functions[decl_id] = decl_function(ctx, decl)
            continue
        end

        panic(`Unhandled declaration kind "{decl.kind}"`)
    end

    return lir
end

return table.freeze({
    lir = build_lir
})