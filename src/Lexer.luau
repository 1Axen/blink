--!native
--!optimize 2

local Error = require("./Modules/Error")
local Settings = require("./Settings")

export type Types = 
    "Comma" | "OpenBrackets" | "CloseBrackets" | "OpenCurlyBrackets" | "CloseCurlyBrackets" | "OpenSquareBrackets" | "CloseSquareBrackets" --> Structs & enums
    | "String" | "Boolean" | "Number"   --> Literals
    | "Array" | "Range" | "Optional" | "Class"    --> Attributes
    | "Assign" | "Keyword" | "Primitive" | "Identifier" --> Reserved
    | "Whitespace" | "Unknown" 

export type Keywords = "type" | "enum" | "struct" | "event" | "function"

export type Token = {
    Type: Types,
    Value: string,

    Start: number,
    End: number,
}

export type Lexer = {
    Mode: Mode,
    Size: number,
    Source: string,
    Cursor: number,

    Initialize: (self: Lexer, Source: string) -> (),
    GetNextToken: (self: Lexer, DontAdvanceCursor: boolean?) -> Token?,
}

export type Mode = "Parsing" | "Highlighting"

local Primitives = Settings.Primtives
local Keywords = Settings.Keywords

local Booleans = {
    ["true"] = true,
    ["false"] = true
}

local Number = "[%+%-]?%d+"

local Matches = {
    --> Simple patterns
    {"^%s+", "Whitespace"},     
    {"^=", "Assign"},
    {"^{", "OpenCurlyBrackets"},
    {"^}", "CloseCurlyBrackets"},
    {"^,", "Comma"},

    --> Attribute patterns
    {"^?", "Optional"},
    {`^%(%a+%)`, "Class"},
    {`^%({Number}%)`, "Range"},
    {`^%({Number}..{Number}%)`, "Range"},
    {`^%[{Number}]`, "Array"},
    {`^%[{Number}..{Number}]`, "Array"},

    {"^%(", "OpenBrackets"},
    {"^%)", "CloseBrackets"},
    {"^%[", "OpenSquareBrackets"},
    {"^%]", "CloseSquareBrackets"},

    {[[^(['"]).-[^\](\*)%2%1]], function(Token: string)
        return "String", string.sub(Token, 2, #Token - 1)
    end},

    --> Complex patterns
    {"^%a+%.%a+", "Identifier"},
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

local Lexer = {}
Lexer.__index = Lexer

function Lexer.new(Mode: Mode?): Lexer
    local Mode: Mode = Mode or "Parsing"
    return setmetatable({
        Size = 0,
        Mode = Mode,
        Source = "",
        Cursor = 1
    } :: any, Lexer)
end

function Lexer.Initialize(self: Lexer, Source: string)
    self.Size = #Source
    self.Source = Source
    self.Cursor = 1
end

function Lexer.GetNextToken(self: Lexer, DontAdvanceCursor: boolean?): Token?
    if self.Cursor > self.Size then
        return
    end

    local Slice = string.sub(self.Source, self.Cursor)
    local IsHighlighting = (self.Mode == "Highlighting")

    local function Match(Pattern: string): (string?, number, number)
        local Start, End = string.find(Slice, Pattern)
        if not Start or not End then
            return nil, 0, 0
        end

        local Matched = string.sub(Slice, Start, End)

        Start = self.Cursor
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

        if (DontAdvanceCursor ~= true or Type == "Whitespace") then
            self.Cursor += #Matched
        end
        
        --> Whitespace matched, skip token.
        --> We don't want to skip whitespaces in highlighting mode.
        if (Type == "Whitespace") and not IsHighlighting then
            return self:GetNextToken(DontAdvanceCursor)
        end

        if type(Type) == "function" then
            --> Only overwrite the type when highlighting
            if IsHighlighting then
                Type = Type(Matched)
            else
                Type, Matched = Type(Matched)
            end
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
    else
        --> Attempt to recover the lexer
        local Cursor = self.Cursor
        local Symbol = string.sub(self.Source, Cursor, Cursor)
        self.Cursor += 1

        return {
            Type = "Unknown",
            Value = Symbol,
            Start = Cursor,
            End = Cursor,
        }
    end

    return
end

return Lexer