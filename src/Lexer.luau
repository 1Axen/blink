--!native
--!optimize 2

local Error = require("./Modules/Error")
local Settings = require("./Settings")

export type Types = 
    "Comma" | "OpenParentheses" | "CloseParentheses" | "OpenBraces" | "CloseBraces" | "OpenBrackets" | "CloseBrackets" | "Merge" --> Structs & enums
    | "String" | "Boolean" | "Number"   --> Literals
    | "Array" | "Range" | "Optional" | "Class" | "Component" | "OpenChevrons" | "CloseChevrons"  --> Attributes
    | "Assign" | "FieldAssign" | "Keyword" | "Primitive" | "Identifier" --> Reserved
    | "Import" | "As" --> Imports
    | "Whitespace" | "Comment" | "Unknown" | "EndOfFile"

export type Keywords = "type" | "enum" | "struct" | "event" | "function"

export type Token = {
    Type: Types,
    Value: string,

    Start: number,
    End: number,
}

export type Mode = "Parsing" | "Highlighting"

local DOTS = "%.%."
local NUMBER = "%-?%d*%.?%d+"

local Keywords = Settings.Keywords
local Primitives = Settings.Primtives

local Booleans = {
    ["true"] = true,
    ["false"] = true
}

local TOKENS = {
    --> Simple patterns
    {"^%s+", "Whitespace"},     
    {"^=", "Assign"},
    {"^:", "FieldAssign"},
    {"^{", "OpenBraces"},
    {"^}", "CloseBraces"},
    {"^<", "OpenChevrons"},
    {"^>", "CloseChevrons"},
    {"^,", "Comma"},
    {"^%.%.", "Merge"},

    --> Comments
    {"^%-%-%[(=*)%[.-%]%1%]", "Comment"},
    {"^%-%-%[%[.-.*", "Comment"},
    {"^%-%-.-\n", "Comment"},
    {"^%-%-.-.*", "Comment"},

    --> Attribute patterns
    {"^?", "Optional"},
    {`^%(%a+%)`, "Class"},
    {`^%[]`, "Array"},
    {`^%({NUMBER}%)`, "Range"},
    {`^%({NUMBER}{DOTS}%)`, "Range"},
    {`^%({DOTS}{NUMBER}%)`, "Range"},
    {`^%({NUMBER}{DOTS}{NUMBER}%)`, "Range"},
    {`^%[{NUMBER}%]`, "Array"},
    {`^%[{NUMBER}{DOTS}%]`, "Array"},
    {`^%[{NUMBER}{DOTS}%]`, "Array"},
    {`^%[{NUMBER}{DOTS}{NUMBER}%]`, "Array"},

    {"^%(", "OpenParentheses"},
    {"^%)", "CloseParentheses"},
    {"^%[", "OpenBrackets"},
    {"^%]", "CloseBrackets"},

    --> String patterns
    {"^\"\"", function(Toke: string)
        return "String", ""
    end},

    {[[^(['"]).-[^\](\*)%2%1]], function(Token: string)
        return "String", string.sub(Token, 2, #Token - 1)
    end},

    {"^(['\"]).-.*", function(Token: string)
        return "String", string.sub(Token, 2)
    end},

    --> Complex patterns
    {"^[%w_]+%.[%w_%.]+", "Identifier"},
    {"^[%a_][%w_]*", function(Token: string)
        if Token == "import" then
            return "Import", Token
        elseif Token == "as" then
            return "As", Token
        elseif Keywords[Token] then
            return "Keyword", Token
        elseif Primitives[Token] then
            return "Primitive", Token
        elseif Booleans[Token] then
            return "Boolean", (Token == "true")
        end

        return "Identifier", Token
    end},   
}

local SKIPPED_TOKENS = {
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

function Lexer.GetNextToken(self: Lexer, DontAdvanceCursor: boolean?, StartAt: number?): Token
    if self.Cursor > self.Size then
        return {
            Type = "EndOfFile",
            Value = "",
            Start = #self.Source,
            End = #self.Source
        }
    end

    local Source = self.Source
    local Position = StartAt or self.Cursor
    local IsHighlighting = (self.Mode == "Highlighting")

    local function Match(Pattern: string): (string?, number, number)
        local Start, End = string.find(Source, Pattern, Position)
        if not Start or not End then
            return nil, Position, Position
        end

        local Text = string.sub(Source, Start, End)
        return Text, Position, math.min(Position + #Text, self.Size)
    end

    for Index, Token in TOKENS do
        local Pattern = Token[1]
        local Type: (Types | (Text: string) -> Types)? = Token[2]

        local Text, Start, End = Match(Pattern)

        --> Couldn't match this pattern, continue.
        if not Text then
            continue
        end

        if (not DontAdvanceCursor or (SKIPPED_TOKENS[Type] and not IsHighlighting)) then
            Position += #Text
            self.Cursor = Position
        end

        --> Whitespace matched, skip token.
        --> We don't want to skip whitespaces in highlighting mode.
        if SKIPPED_TOKENS[Type] and not IsHighlighting then
            return self:GetNextToken(DontAdvanceCursor)
        end

        if type(Type) == "function" then
            --> Only overwrite the type when highlighting
            local TrueType, TrueText = Type(Text)

            Type = TrueType
            Text = IsHighlighting and Text or TrueText
        end

        return {
            Type = Type,
            Value = Text,
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
    local Symbol = string.sub(self.Source, Position, Position)
    if DontAdvanceCursor ~= true then
        self.Cursor += 1
    end

    return {
        Type = "Unknown",
        Value = Symbol,
        Start = Position,
        End = Position,
    }
end

return Lexer