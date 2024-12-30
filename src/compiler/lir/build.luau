--!strict
--!native
--!optimize 2

local hir = require("@compiler/structures/hir")
local lir = require("@compiler/structures/lir")

type Lir = lir.Lir

local function ty_u8()
    
end

local function decl_type()
    
end

local function build_lir(hir: hir.Hir): lir.Lir
    
end

return table.freeze({
    lir = build_lir
})