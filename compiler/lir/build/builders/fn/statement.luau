--!strict

local types = require("@lir/types")

type Call = types.StatCall
type Assign = types.StatAssign
type Remark = types.StatRemark
type LocalAssign = types.StatLocalAssign
type MultiAssign = types.StatMultiAssign

type Readable = types.Readable<any>
type Writeable = types.Writeable<any>
type Register = types.RegisterId<any>

type RValue = types.RValue<any>
type LValue = types.LValue<any>

local function stat_call(call: index<Call, "call">): Call
	return {
		type = "statement",
		kind = "call",
		call = call,
	}
end

local function stat_assign(into: Writeable, value: Readable?): Assign
	return {
		type = "statement",
		kind = "assign",
		into = into :: LValue,
		value = value :: RValue,
	}
end

local function stat_remark(text: string): Remark
	return {
		type = "statement",
		kind = "remark",
		text = text,
	}
end

local function stat_multi_assign(into: { read Writeable }, value: Readable): MultiAssign
	return {
		type = "statement",
		kind = "multi_assign",
		into = into :: { LValue },
		value = value :: RValue,
	}
end

local function stat_local_assign(into: Register, value: Readable?): LocalAssign
	return {
		type = "statement",
		kind = "local_assign",
		into = into,
		value = value :: RValue?,
	}
end

return table.freeze({
	call = stat_call,
	remark = stat_remark,
	assign = stat_assign,
	multi_assign = stat_multi_assign,
	local_assign = stat_local_assign,
})
