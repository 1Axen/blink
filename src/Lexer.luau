--[[
    Axen @ 2023
    Lexer class
--]]

local Error = require("./Modules/Error")

export type Types = "Text" | "Next" | "Open" | "Close" | "OpenEnum" | "CloseEnum" | "Array" | "Range" | "Number" | "Assign" | "Optional" | "Keyword" | "Primitive" | "Identifier" | "Unknown"
export type Keywords = "type" | "enum" | "struct" | "packet"

export type Token = {
    Type: Types,
    Value: string,

    Start: number,
    End: number,
}

export type Lexer = {
    Size: number,
    Source: string,
    Cursor: number,

    Initialize: (self: Lexer, Source: string) -> (),
    GetNextToken: (self: Lexer) -> Token?,
}

local Primitives = {
    u8 = true,
    u16 = true,
    u32 = true,
    i8 = true,
    i16 = true,
    i32 = true,
    f32 = true,
    f64 = true,
    bool = true,
    string = true,
    vector = true,
    buffer = true,
}

local Keywords = {
    type = true,
    enum = true,
    struct = true,
    packet = true
}

local Number = "[%+%-]?%d+"

local Matches = {
    --> Simple patterns
    {"^%s+", nil},     
    {"^=", "Assign"},
    {"^{", "Open"},
    {"^}", "Close"},
    {"^,", "Next"},

    --> Attribute patterns
    {"^?", "Optional"},
    {`^%({Number}..{Number}%)`, "Range"},
    {`^%[{Number}]`, "Array"},
    {`^%[{Number}..{Number}]`, "Array"},

    {"^%(", "OpenEnum"},
    {"^%)", "CloseEnum"},

    --> Complex patterns
    {"^[%a_][%w_]*", function(Token: string)
        if Keywords[Token] then
            return "Keyword"
        elseif Primitives[Token] then
            return "Primitive"
        end

        return "Identifier"
    end}
}

local Lexer = {}
Lexer.__index = Lexer

function Lexer.new(): Lexer
    return setmetatable({
        Size = 0,
        Source = "",

        Line = 1,
        Cursor = 1
    } :: any, Lexer)
end

function Lexer.Initialize(self: Lexer, Source: string)
    self.Size = #Source
    self.Source = Source
    self.Cursor = 1
end

function Lexer.GetNextToken(self: Lexer): Token?
    if self.Cursor > self.Size then
        return
    end

    local Slice = string.sub(self.Source, self.Cursor)

    local function Match(Pattern: string): (string?, number, number)
        local Matched = string.match(Slice, Pattern)
        if not Matched then
            return nil, 0, 0
        end

        local Start = self.Cursor
        self.Cursor += #Matched

        return Matched, Start, math.min(self.Cursor, self.Size)
    end

    for Index, Token in Matches do
        local Pattern = Token[1]
        local Type: (Types | (Token: string) -> Types)? = Token[2]

        local Matched, Start, End = Match(Pattern)

        --> Couldn't match this pattern, continue.
        if not Matched then
            continue
        end

        --> Whitespace matched, skip token.
        if not Type then
            return self:GetNextToken()
        end

        if type(Type) == "function" then
            Type = Type(Matched)
        end
        
        return {
            Type = Type,
            Value = Matched,

            Start = Start,
            End = End,
        }
    end

    Error.ThrowTokenError(self.Source, {
        Type = "Unknown",
        Value = string.sub(Slice, 1, 1),

        Start = self.Cursor,
        End = self.Cursor
    }, `Unexpected token: "{string.sub(Slice, 1, 1)}"`)

    return
end

return Lexer