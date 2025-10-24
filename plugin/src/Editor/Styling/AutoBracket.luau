local Hook = {}

local Brackets = {
	["("] = ")",
    ["{"] = "}",
    ["["] = "]",
    ["<"] = ">",
}

local ClosingBrackets = {
    [")"] = true,
    ["}"] = true,
    ["]"] = true,
    [">"] = true,
}

local IgnoredCharacters = {
    ["\n"] = true,
    [""] = true,
    [")"] = true,
    ["}"] = true,
    ["]"] = true,
    [">"] = true,
}

local function OnGain(Text: string, Cursor: number): (string, number)
    local Next = string.sub(Text, Cursor, Cursor)
	local Previous = string.sub(Text, Cursor - 1, Cursor - 1)

    local ClosingBracket = Brackets[Previous]
    if ClosingBracket and IgnoredCharacters[Next] then
        Text = string.sub(Text, 1, Cursor - 1) .. ClosingBracket .. string.sub(Text, Cursor)
        return Text, Cursor
    end

	return Text, Cursor
end

local function OnRemove(Text: string, PreviousText: string, Cursor: number): (string, number)
    local Next = string.sub(Text, Cursor, Cursor)
    local Previous = string.sub(PreviousText, Cursor, Cursor)
    if Brackets[Previous] and ClosingBrackets[Next] then
        Text = string.sub(Text, 1, Cursor - 1) .. string.sub(Text, Cursor + 1)
        return Text, Cursor
    end

    return Text, Cursor
end

function Hook.OnSourceChanged(Text: string, PreviousText: string, Cursor: number, Gain: number): (string, number)
    if Gain >= 1 then
        return OnGain(Text, Cursor)
    elseif Gain <= -1 then
        return OnRemove(Text, PreviousText, Cursor)
    end

    return Text, Cursor
end

return Hook