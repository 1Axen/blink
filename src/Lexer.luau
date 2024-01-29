--!native
--!optimize 2

local Error = require("./Modules/Error")

export type Types = 
    "Comma" | "OpenBrackets" | "CloseBrackets" | "OpenCurlyBrackets" | "CloseCurlyBrackets" | "OpenSquareBrackets" | "CloseSquareBrackets" --> Structs & enums
    | "String" | "Boolean" | "Number"   --> Literals
    | "Array" | "Range" | "Optional" | "Class"    --> Attributes
    | "Assign" | "Keyword" | "Primitive" | "Identifier" --> Reserved
    | "Unknown" 

export type Keywords = "type" | "enum" | "struct" | "event" | "function"

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
    boolean = true,
    string = true,
    vector = true,
    buffer = true,
    Color3 = true,
    CFrame = true,
    Instance = true,
}

local Keywords = {
    type = true,
    enum = true,
    struct = true,

    event = true,
    ["function"] = true,

    scope = true,
    option = true,
}

local Booleans = {
    ["true"] = true,
    ["false"] = true
}

local Number = "[%+%-]?%d+"

local Matches = {
    --> Simple patterns
    {"^%s+", nil},     
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
        local Start, End = string.find(Slice, Pattern)
        if not Start or not End then
            return nil, 0, 0
        end

        local Matched = string.sub(Slice, Start, End)

        Start = self.Cursor
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
            Type, Matched = Type(Matched)
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