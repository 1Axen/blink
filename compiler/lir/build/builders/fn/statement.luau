--!strict

local types = require("@lir/types")

type Call = types.StatCall
type Assign = types.StatAssign
type Remark = types.StatRemark
type LocalAssign = types.StatLocalAssign
type MultiAssign = types.StatMultiAssign

type LValue = types.LValue<any>
type RValue = types.RValue<any>
type Register = types.RegisterId<any>

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
