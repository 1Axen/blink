local stdio = require("@lune/stdio")

local function Style(text: string, style: stdio.Style): string
	return `{stdio.style(style)}{text}{stdio.style("reset")}`
end

local function Color(text: string, color: stdio.Color): string
	return `{stdio.color(color)}{text}{stdio.color("reset")}`
end

local KEYWORDS = {
	["and"] = true, 
	["break"] = true, 
	["do"] = true, 
	["else"] = true,
	["elseif"] = true, 
	["end"] = true, 
	["false"] = true, 
	["for"] = true, 
	["function"] = true,
	["if"] = true, 
	["in"] = true, 
	["local"] = true, 
	["nil"] = true, 
	["not"] = true, 
	["or"] = true,
	["repeat"] = true, 
	["return"] = true, 
	["then"] = true, 
	["true"] = true, 
	["until"] = true, 
	["while"] = true
}
 
local function ShouldWrap(value: any): boolean
	if type(value) ~= "string" then 
		return false 
	end
	-- must be nonempty
	if #value == 0 then 
		return false 
	end

	-- can only contain a-z, A-Z, 0-9 and underscore
	if string.find(value, "[^%d%a_]") then
		return false 
	end

	-- cannot begin with digit
	if tonumber(string.sub(value, 1, 1)) then 
		return false 
	end

	-- cannot be keyword
	if KEYWORDS[value] then 
		return false 
	end

	return true
end

 
local Cache
local INDENT = string.rep(" ", 3)
 
local function Format(Value: any, Depth: number?)
	local Depth = Depth or 0
	local Tabs = string.rep(INDENT, Depth)

	if Depth == 0 then
		Cache = {}
	end

	if type(Value) == "string" then
		return Color(string.format("%q", Value), "green")
	elseif type(Value) == "number" then
		if Value == math.huge then return Color("math.huge", "cyan") end
		if Value == -math.huge then return Color("-math.huge", "cyan") end
		return Color(tostring(Value), "cyan")
	elseif type(Value) == "boolean" then
		return Color(tostring(Value), "yellow")
	elseif type(Value) == "table" then
		if Cache[Value] then 
			return Color("{CACHED}" , "red")
		end

		local Hex = string.match(tostring(Value), "0x[%w]+")
		local Text = Style(`\{ ({Hex})`, "dim") .. ("\n" .. INDENT .. Tabs)
		local IsArray = true

		Cache[Value] = true

		for key in Value do
			if type(key) ~= "number" then
				IsArray = false
				break
			end
		end

		if IsArray then
			for Index = 1, #Value do
				if Index ~= 1 then
					Text ..= Style(",", "dim") .. ("\n" .. INDENT .. Tabs)
				end

				Text ..= Format(Value[Index], Depth + 1)
			end
		else
			local First = true
			for Key, Value in Value do
				if 
					Key == "Scope" 
					or Key == "Scopes" 
					or Key == "Symbols" 
					or Key == "Tokens" 
					or Key == "Primitive"
				then
					continue
				end

				local KeyString = ShouldWrap(Key) and Key or ("[" .. Format(Key, Depth + 1) .. "]")
				local ValueString = Format(Value, Depth + 1)

				if not First then
					Text ..= Style(",", "dim") .. ("\n" .. INDENT .. Tabs)
				end

				First = false
				Text ..= string.format("%s = %s", KeyString, ValueString)
			end
		end

		Text ..= "\n" .. Tabs .. Style("}", "dim")
		return Text
	end

	return "<" .. type(Value) .. ">"
end
 
return Format