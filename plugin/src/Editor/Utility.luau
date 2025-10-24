local Utility = {}

export type Range = {
	Text: string,
	Index: number,
	Start: number,
	End: number,
}

local DEFAULT_RANGE = {
	Text = "",
	Index = 0,
	Start = 0,
	End = 0,
}

local function Split(String: string): { Range }
	local Cursor = 1
	local Ranges: { Range } = {}

	while Cursor <= #String do
		--> Ignore whitespaces
		local Start, End = string.find(String, "^[%s%.]+", Cursor)
		if Start and End then
			Cursor = (End + 1)
			continue
		end

		--> Match words
		Start, End = string.find(String, "^[%w%p]+", Cursor)

		if Start then
			local Text = string.sub(String, Start, End)
			table.insert(Ranges, {
				Text = Text,
				Index = #Ranges + 1,
				Start = Start,
				End = End,
			})

			Cursor = (End + 1)
			continue
		end

		break
	end

	return Ranges
end

function Utility.GetCurrentLine(Source: string, Cursor: number): (number, { string })
	local Line = 0
	local Position = 0
	local Slices = string.split(Source, "\n")

	for Index, Slice in Slices do
		Position += (#Slice + 1)
		if Cursor <= Position then
			Line = Index
			break
		end
	end

	return Line, Slices
end

function Utility.GetLineRangeAtPosition(Source: string, Cursor: number): Range
	local Range: Range
	local Position = 0
	local Slices = string.split(Source, "\n")

	for Index, Slice in Slices do
		local Start = Position
		Position += (#Slice + 1)
		if Cursor <= Position then
			Range = {
				Text = Slice,
				Index = 1,
				Start = (Start + 1),
				End = (Position - 1),
			}

			break
		end
	end

	return Range
end

function Utility.GetWordRangeAtPosition(Source: string, Position: number): Range
	local Ranges = Split(Source)

	for _, Range in Ranges do
		if Range.Start <= Position and Range.End >= Position then
			return Range
		end
	end

	return DEFAULT_RANGE
end

function Utility.GetWordRangeBeforePosition(Source: string, Position: number): Range
	local Ranges = Split(Source)

	for Index, Range in Ranges do
		if Range.Start >= Position then
			return Ranges[Index - 1] or DEFAULT_RANGE
		end
	end

	return DEFAULT_RANGE
end

return Utility
