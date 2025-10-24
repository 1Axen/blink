local Utility = require("../Utility")

local Hook = {}
local IndentKeywords = {
	"{\n",
}

local function ShouldAutoIndent(Text: string, Cursor: number): boolean
	for Index, Keyword in IndentKeywords do
		local Position = (Cursor - #Keyword)
		if Position <= 0 then
			continue
		end

		local Previous = string.sub(Text, Position, Cursor - 1)
		if Previous == Keyword then
			return true
		end
	end

	return false
end

local function GetLineIndentation(Line: string): number
	return #(string.match(Line, "^\t*") :: string)
end

function Hook.OnSourceChanged(Text: string, PreviousText: string, Cursor: number, Gain: number): (string, number)
	if Gain ~= 1 then
		return Text, Cursor
	end

	local CanIndent = false
	local AdditionalIndent = 0
	local Line, Lines = Utility.GetCurrentLine(Text, Cursor)

	local Current = Lines[Line]
	local Previous = Lines[Line - 1]
	local JustReached = (Previous and Current == "")

	if ShouldAutoIndent(Text, Cursor) then
		CanIndent = true
		AdditionalIndent = 1
	elseif JustReached then
		if GetLineIndentation(Previous) > 0 then
			CanIndent = true
		end
	end

	if not CanIndent then
		return Text, Cursor
	end

	--> Update text and cursor
	local NextCharacter = string.sub(Text, Cursor, Cursor)
	if string.gsub(NextCharacter, "%c", "") == "" then
		NextCharacter = nil
	end

	local Indentation = GetLineIndentation(Previous) + AdditionalIndent
	Text = string.sub(Text, 1, Cursor - 1)
		.. string.rep("\t", Indentation)
		.. (NextCharacter and `\n{string.rep("\t", Indentation - 1)}` or "")
		.. string.sub(Text, Cursor)

	return Text, Cursor + Indentation
end

return Hook
