local Parser = require("../Parser")

type Scope = Parser.Scope

local function GetScopePrefix(ReferenceScope: Scope?, Dots: boolean?, CurrentScope: Scope): string
	local Prefix = ""
	local WorkingScope: Scope? = ReferenceScope or CurrentScope
	while (WorkingScope and WorkingScope.Name.Value ~= "") do
		Prefix = `{WorkingScope.Name.Value}{Dots and "." or "_"}` .. Prefix
		WorkingScope = WorkingScope.Parent
	end

	return Prefix
end

local function GetScopeIndent(CurrentScope: Scope): number
	return math.max(#string.split(GetScopePrefix(nil, true, CurrentScope), "."), 1)
end

local function GetTypesPath(Name: string, Write: boolean, CurrentScope: Scope): string
	return `{GetScopePrefix(nil, false, CurrentScope)}{Write and "Write" or "Read"}{Name}`
end

local function GetExportName(Name: string, CurrentScope: Scope): string
	return `{GetScopePrefix(nil, false, CurrentScope)}{Name}`
end

local function GenerateEnumLiterals(Variants: { string }): string
	local Literals = {}
	for Index, EnumItem in Variants do
		table.insert(Literals, `"{EnumItem}"`)
	end
	return `{table.concat(Literals, " | ")}`
end

return {
    GetPath = GetTypesPath,
    GetExportName = GetExportName,
    GetScopePrefix = GetScopePrefix,
    GetScopeIndent = GetScopeIndent,
    GenerateEnumLiterals = GenerateEnumLiterals,
}