--!native
--!optimize 2

local Error = require("./Modules/Error")
local Settings = require("./Settings")

export type Types = 
    "Comma" | "OpenParentheses" | "CloseParentheses" | "OpenBraces" | "CloseBraces" | "OpenBrackets" | "CloseBrackets" --> Structs & enums
    | "String" | "Boolean" | "Number"   --> Literals
    | "Array" | "Range" | "Optional" | "Class" | "Component" | "OpenChevrons" | "CloseChevrons"  --> Attributes
    | "Assign" | "FieldAssign" | "Keyword" | "Primitive" | "Identifier" --> Reserved
    | "Whitespace" | "Comment" | "Unknown" | "EndOfFile"

export type Keywords = "type" | "enum" | "struct" | "event" | "function"

export type Token = {
    Type: Types,
    Value: string,

    Start: number,
    End: number,
}

export type Mode = "Parsing" | "Highlighting"

local Keywords = Settings.Keywords
local Primitives = Settings.Primtives

local Booleans = {
    ["true"] = true,
    ["false"] = true
}

local Number = "[%+%-]?%d+"

local Matches = {
    --> Simple patterns
    {"^%s+", "Whitespace"},     
    {"^=", "Assign"},
    {"^:", "FieldAssign"},
    {"^{", "OpenBraces"},
    {"^}", "CloseBraces"},
    {"^<", "OpenChevrons"},
    {"^>", "CloseChevrons"},
    {"^,", "Comma"},

    --> Comments
    {"^%-%-.-\n", "Comment"},
    {"^%-%-.-.*", "Comment"},
    {"^%-%-%[(=*)%[.-%]%1%]", "Comment"},
    {"^%-%-%[%[.-.*", "Comment"},

    --> Attribute patterns
    {"^?", "Optional"},
    {`^%(%a+%)`, "Class"},
    {`^%[]`, "Array"},
    {`^%({Number}%)`, "Range"},
    {`^%({Number}..{Number}%)`, "Range"},
    {`^%[{Number}]`, "Array"},
    {`^%[{Number}..{Number}]`, "Array"},
    --{`^%b<>`, "Component"},

    {"^%(", "OpenParentheses"},
    {"^%)", "CloseParentheses"},
    {"^%[", "OpenBrackets"},
    {"^%]", "CloseBrackets"},

    --> String patterns
    {[[^(['"]).-[^\](\*)%2%1]], function(Token: string)
        return "String", string.sub(Token, 2, #Token - 1)
    end},

    {"^(['\"]).-.*", function(Token: string)
        return "String", string.sub(Token, 2)
    end},

    --> Complex patterns
    {"^[%w_]+%.[%w_%.]+", "Identifier"},
    {"^[%a_][%w_]*", function(Token: string)
        if Keywords[Token] then
            return "Keyword", Token
        elseif Primitives[Token] then
            return "Primitive", Token
        elseif Booleans[Token] then
            return "Boolean", (Token == "true")
        end

        return "Identifier", Token
    end},   
}

local SKIPPED_PATTERNS = {
    Comment = true,
    Whitespace = true
}

local Lexer = {}
Lexer.__index = Lexer

export type Lexer = typeof(setmetatable({} :: {
    Mode: Mode,
    Size: number,
    Source: string,
    Cursor: number,
}, Lexer))

function Lexer.new(Mode: Mode?): Lexer
    return setmetatable({
        Size = 0,
        Mode = Mode or "Parsing",
        Source = "",
        Cursor = 1
    } :: any, Lexer)
end

function Lexer.Initialize(self: Lexer, Source: string)
    self.Size = #Source
    self.Source = Source
    self.Cursor = 1
end

function Lexer.GetNextToken(self: Lexer, DontAdvanceCursor: boolean?, Position: number?): Token
    if self.Cursor > self.Size then
        return {
            Type = "EndOfFile",
            Value = "",
            Start = #self.Source,
            End = #self.Source
        }
    end

    local Slice = string.sub(self.Source, Position or self.Cursor)
    local IsHighlighting = (self.Mode == "Highlighting")

    local function Match(Pattern: string): (string?, number, number)
        local Start, End = string.find(Slice, Pattern)
        if not Start or not End then
            return nil, 0, 0
        end

        local Matched = string.sub(Slice, Start, End)

        Start = Position or self.Cursor
        return Matched, Start, math.min(Start + #Matched, self.Size)
    end

    for Index, Token in Matches do
        local Pattern = Token[1]
        local Type: (Types | (Token: string) -> Types)? = Token[2]

        local Matched, Start, End = Match(Pattern)

        --> Couldn't match this pattern, continue.
        if not Matched then
            continue
        end

        if (DontAdvanceCursor ~= true or (SKIPPED_PATTERNS[Type] and IsHighlighting ~= true)) then
            self.Cursor += #Matched
        end

        --> Whitespace matched, skip token.
        --> We don't want to skip whitespaces in highlighting mode.
        if SKIPPED_PATTERNS[Type] and not IsHighlighting then
            return self:GetNextToken(DontAdvanceCursor)
        end

        if type(Type) == "function" then
            --> Only overwrite the type when highlighting
            local TrueType, TrueMatched = Type(Matched)
            Type = TrueType
            Matched = if (IsHighlighting ~= true) then TrueMatched else Matched
        end

        return {
            Type = Type,
            Value = Matched,

            Start = Start,
            End = End,
        }
    end

    if not IsHighlighting then
        Error.new(Error.LexerUnexpectedToken, self.Source, "Unexpected token")
            :Primary({Start = self.Cursor, End = self.Cursor}, `Unexpected token`)
        :Emit()
    end

    --> Attempt to recover the lexer
    local Cursor = self.Cursor
    local Symbol = string.sub(self.Source, Cursor, Cursor)

    if DontAdvanceCursor ~= true then
        self.Cursor += 1
    end

    return {
        Type = "Unknown",
        Value = Symbol,
        Start = Cursor,
        End = Cursor,
    }
end

return Lexer