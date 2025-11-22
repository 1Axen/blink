--!strict
--!native
--!optimize 2

local build = require("@self/build")
local hir = require("@hir")
local lookup = require("@self/lookup")
local optimize = require("@self/optimize")
local types = require("@self/types")

export type ConstantValue = types.ConstantValue
export type Constant<T = ConstantValue> = types.Constant<T>
export type ParameterId<T> = types.ParameterId<T>
export type RegisterId<T> = types.RegisterId<T>
export type Id<T> = types.Id<T>
export type ProjCall<T> = types.ProjCall<T>
export type ProjField<T> = types.ProjField<T>
export type ProjIndex<T> = types.ProjIndex<T>
export type ProjNamecall<T> = types.ProjNamecall<T>
export type Projection<T> = types.Projection<T>
export type BinaryAdd<T> = types.BinaryAdd<T>
export type BinarySub<T> = types.BinarySub<T>
export type BinaryMul<T> = types.BinaryMul<T>
export type BinaryDiv<T> = types.BinaryDiv<T>
export type BinaryMod<T> = types.BinaryMod<T>
export type BinaryPow<T> = types.BinaryPow<T>
export type BinaryIDiv<T> = types.BinaryIDiv<T>
export type BinaryOp<T> = types.BinaryOp<T>
export type UnaryLen<T> = types.UnaryLen<T>
export type UnaryOp<T> = types.UnaryOp<T>
export type CtrlAdvance<T> = types.CtrlAdvance<T>
export type CtrlAllocate<T> = types.CtrlAllocate<T>
export type Control<T> = types.Control<T>
export type Global<T> = types.Global<T>
export type Condition<T> = types.Condition<T>
export type Ternary<T> = types.Ternary<T>
export type Map<T> = types.Map<T>
export type Array<T> = types.Array<T>
export type Struct<T> = types.Struct<T>
export type Structure<T> = types.Structure<T>
export type LValue<T> = types.LValue<T>
export type RValue<T> = types.RValue<T>
export type StatCall = types.StatCall
export type StatRemark = types.StatRemark
export type StatAssign = types.StatAssign
export type StatLocalAssign = types.StatLocalAssign
export type StatMultiAssign = types.StatMultiAssign
export type StatFunction = types.StatFunction
export type Statement = types.Statement
export type LoopNumeric = types.LoopNumeric
export type LoopGeneric = types.LoopGeneric
export type Loop = types.Loop
export type TermIf = types.TermIf
export type TermIfChain = types.TermIfChain
export type TermNone = types.TermNone
export type TermGoto = types.TermGoto
export type TermLoop = types.TermLoop
export type TermCall = types.TermCall
export type TermWhile = types.TermWhile
export type TermReturn = types.TermReturn
export type Terminator = types.Terminator
export type BasicBlock = types.BasicBlock
export type Return = types.Return
export type Parameter = types.Parameter
export type FnBody = types.FnBody
export type AnonymousFn = types.AnonymousFn
export type Fn = types.Fn
export type FnId = types.FnId
export type FnSet = types.FnSet
export type TypeExport = types.TypeExport
export type EventExport = types.EventExport
export type FunctionExport = types.FunctionExport
export type ScopeExport = types.ScopeExport
export type Export = types.Export
export type Lir = types.Lir

local function lir_from_hir(hir: hir.Hir): Lir
	local lir = build.from_hir(hir)
	optimize.lir(lir)
	return lir
end

return table.freeze({
	from_hir = lir_from_hir,
	fn_from_id = lookup.fn_from_id,
})
