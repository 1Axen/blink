--!strict

local stdio = require("@lune/stdio")

local function Style(text: any, style: stdio.Style): string
	return `{stdio.style(style)}{text}{stdio.style("reset")}`
end

local function Color(text: any, color: stdio.Color): string
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
 
local function ShouldntWrap(value: any): boolean
	if type(value) ~= "string" then 
		return false 
	end

	if #value == 0 then 
		return false 
	end

	if string.find(value, "[^%d%a_]") then
		return false 
	end

	if tonumber(string.sub(value, 1, 1)) then 
		return false 
	end

	if KEYWORDS[value] then 
		return false 
	end

	return true
end

 
local Cache
local INDENT = string.rep(" ", 3)

local function Noop()
	
end
 
local function Format(Value: any, Filter: ((Value: any) -> boolean)?, Depth: number?): string
	local Depth = Depth or 0
	local Filter = (Filter or Noop) :: (Value: any) -> boolean

	if Depth == 0 then
		Cache = {}
	end

	if Filter(Value) == false then
		return ""
	end

	local Type = type(Value)
	if Type == "string" then
		return Color(`"{Value}"`, "green")
	elseif Type == "number" then
		if Value == math.huge then return Color("math.huge", "cyan") end
		if Value == -math.huge then return Color("-math.huge", "cyan") end
		return Color(Value, "cyan")
	elseif Type == "boolean" then
		return Color(Value, "yellow")
	elseif Type == "table" then
		local Address = string.match(tostring(Value), "0x[%w]+")
		if Cache[Value] then 
			return `{Color("{CACHED}" , "red")} {Style(Address, "dim")}`
		end

		local Tabs = string.rep(INDENT, Depth)
		local Newline = ("\n" .. INDENT .. Tabs)
		local Text = Style(`\{ ({Address})`, "dim") .. Newline

		Cache[Value] = true

		local First = true
		for Key, Value in Value do
			if Filter(Key) == false then
				continue
			end

			local KeyText = ShouldntWrap(Key) and Key or `["{Format(Key, Filter, Depth + 1)}"]`
			
			if not First then
				Text ..= Style(",", "dim") .. Newline
			end

			First = false
			Text ..= `{KeyText} = {Format(Value, Filter, Depth + 1)}`
		end

		Text ..= "\n" .. Tabs .. Style("}", "dim")
		return Text
	end

	return `<{Type}>`
end
 
return Format