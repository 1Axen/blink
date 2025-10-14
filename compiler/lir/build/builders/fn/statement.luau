--!strict

local lir = require("@lir/types")

type Call = lir.StatCall
type Assign = lir.StatAssign
type Remark = lir.StatRemark
type LocalAssign = lir.StatLocalAssign
type MultiAssign = lir.StatMultiAssign

type LValue = lir.LValue<any>
type RValue = lir.RValue<any>
type Register = lir.RegisterId<any>

local function stat_call(call: index<Call, "call">): Call
	return {
		type = "statement",
		kind = "call",
		call = call,
	}
end

local function stat_assign(into: LValue, value: RValue?): Assign
	return {
		type = "statement",
		kind = "assign",
		into = into,
		value = value,
	}
end

local function stat_remark(text: string): Remark
	return {
		type = "statement",
		kind = "remark",
		text = text,
	}
end

local function stat_multi_assign(into: { LValue }, value: RValue): MultiAssign
	return {
		type = "statement",
		kind = "multi_assign",
		into = into,
		value = value,
	}
end

local function stat_local_assign(into: Register, value: RValue?): LocalAssign
	return {
		type = "statement",
		kind = "local_assign",
		into = into,
		value = value,
	}
end

return table.freeze({
	call = stat_call,
	remark = stat_remark,
	assign = stat_assign,
	multi_assign = stat_multi_assign,
	local_assign = stat_local_assign,
})
