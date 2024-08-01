local Parser = require("../Parser")

type Scope = Parser.Scope

local function GetScopePrefix(ReferenceScope: Scope?, Dots: boolean?): string
	local Prefix = ""
	local WorkingScope: Scope? = ReferenceScope or Scope
	while (WorkingScope and WorkingScope.Identifier.Value ~= "") do
		Prefix = `{WorkingScope.Identifier.Value}{Dots and "." or "_"}` .. Prefix
		WorkingScope = WorkingScope.Parent
	end

	return Prefix
end

local function GetScopeIndent(): number
	return math.max(#string.split(GetScopePrefix(nil, true), "."), 1)
end

local function GetTypesPath(Identifier: string, Write: boolean): string
	return `Types.{GetScopePrefix()}{Write and "Write" or "Read"}{Identifier}`
end

local function GetExportName(Identifier: string): string
	return `{GetScopePrefix()}{Identifier}`
end

local function GenerateEnumLiterals(Variants: { string }): string
	local Literals = {}
	for Index, EnumItem in Variants do
		table.insert(Literals, `"{EnumItem}"`)
	end
	return `{table.concat(Literals, " | ")}`
end

return {
    GetTypesPath = GetTypesPath,
    GetExportName = GetExportName,
    GetScopePrefix = GetScopePrefix,
    GetScopeIndent = GetScopeIndent,
    GenerateEnumLiterals = GenerateEnumLiterals,
}