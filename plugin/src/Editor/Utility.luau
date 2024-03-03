local Utility = {}

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

return Utility