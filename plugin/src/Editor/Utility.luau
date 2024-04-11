local Utility = {}

export type Range = {
	Text: string,
	Start: number,
	End: number
}

function Utility.GetCurrentLine(Source: string, Cursor: number): (number, {string})
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
	local Range: Range;
	local Position = 0
    local Slices = string.split(Source, "\n")

	for Index, Slice in Slices do
		local Start = Position
		Position += (#Slice + 1)
		if Cursor <= Position then
			Range = {
				Text = Slice,
				Start = (Start + 1),
				End = (Position - 1)
			}

			break
		end
	end

	return Range
end

function Utility.GetWordRangeAtPosition(Source: string, Cursor: number): Range?
	local Slices = string.split(Source, " ")
	local Position = 0
	
	--> Remove multiple spaces
	local Words = table.create(#Slices)
	local WasSpace = true
	for _, Slice in Slices do
		if Slice == "" and WasSpace then
			Cursor -= 1
			continue
		end

		WasSpace = Slice == ""
		table.insert(Words, Slice)
	end

	for Index, Word in Words do
		local Start = Position
		Position += (#Word + 1)
		if Cursor <= Position then
			return {
				Text = Word,
				Start = (Start + 1),
				End = (Position - 1)
			}
		end
	end

	return nil
end

function Utility.GetWordRangeBeforePosition(Source: string, Position: number): Range
    local Line = Utility.GetLineRangeAtPosition(Source, Position)
    local Word = Utility.GetWordRangeAtPosition(Line.Text, Position - Line.Start)

    if not Word then
        return {
            Text = "",
            Start = 0,
            End = 0
        }
    end

    if Word.Text ~= "" then
        return Word
    end

    local WordStart = math.max(Word.Start - 1, 0)
    local WordBefore = Utility.GetWordRangeAtPosition(Line.Text, WordStart)
    return WordBefore or Word
end

return Utility