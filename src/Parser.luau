--!strict
--!native
--!optimize 2

local Lexer = require("./Lexer")
local Error = require("./Modules/Error")
local Table = require("./Modules/Table")

type NumberRange = {Min: number, Max: number}
type Declarations = "TypeReference" | "TypeDeclaration" | "EnumDeclaration" | "StructDeclaration" | "EventDeclaration" | "FunctionDeclaration"

type Node<Type, Value> = {
    Type: Type,
    Value: Value
}

export type Body = Node<"Body", {Declaration}>
export type Declaration = Node<Declarations, {
    Identifier: string,
    Optional: boolean,
    [any]: any,
}>

export type TypeReference = Node<"TypeReference", {
    Identifier: string,
    Reference: string,
    
    Array: boolean,
    Range: NumberRange?,
    Optional: boolean,
}>

export type TypeDeclaration = Node<"TypeDeclaration", {
    Identifier: string,
    Primitive: string,

    Array: boolean,
    Range: NumberRange?,
    Optional: boolean,
}>

export type EnumDeclaration = Node<"EnumDeclaration", {
    Identifier: string,
    Enums: {string},
    Optional: boolean,
}>

export type StructDeclaration = Node<"StructDeclaration", {
    Identifier: string,
    Fields: {Declaration},
    Optional: boolean,
}>

export type EventDeclaration = Node<"EventDeclaration", {
    Identifier: string,
    Optional: boolean,
    From: "Client" | "Server",
    Type: "Reliable" | "Unreliable",
    Call: "SingleSync" | "ManySync" | "SingleAsync" | "ManyAsync",
    Data: Declaration
}>

export type FunctionDeclaration = Node<"FunctionDeclaration", {
    Identifier: string,
    Optional: boolean,
    Yield: "Future" | "Promise" | "Coroutine",
    Data: Declaration,
    Return: Declaration
}>

export type Options = {
    ClientOutput: string?,
    ServerOutput: string?,
    FutureLibrary: string?,
    PromiseLibrary: string?,
    ManualReplication: boolean?,
}

export type Parser = {
    Source: string,
    Lexer: Lexer.Lexer,

    Types: {[string]: Declaration},
    LookAhead: Lexer.Token?,

    Parse: (self: Parser, Source: string) -> (Body, Options),
    Consume: (self: Parser, Type: Lexer.Types) -> Lexer.Token,
    GetSafeLookAhead: (self: Parser) -> Lexer.Token,

    --> Parsable types
    Body: (self: Parser) -> Body,
    Options: (self: Parser) -> Options,

    Declaration: (self: Parser) -> Declaration,
    Declarations: (self: Parser) -> {Declaration},

    TypeDeclaration: (self: Parser, Identifier: Lexer.Token) -> TypeDeclaration,
    EnumDeclaration: (self: Parser, Identifier: Lexer.Token) -> EnumDeclaration,
    StructDeclaration: (self: Parser, Identifier: Lexer.Token) -> StructDeclaration,
    EventDeclaration: (self: Parser, Identifier: Lexer.Token) -> EventDeclaration,
    FunctionDeclaration: (self: Parser, Identifier: Lexer.Token) -> FunctionDeclaration,

    GetTypeAttributes: (self: Parser, Primitive: Lexer.Token?) -> (boolean, NumberRange?),
    GetDeclarationFromToken: (self: Parser, Token: Lexer.Token, Identifier: Lexer.Token) -> Declaration,
}

local Attributes = {
    Range = true,
    Array = true
}

local RangePrimitives = {
    u8 = true,
    u16 = true,
    u32 = true,
    i8 = true,
    i16 = true,
    i32 = true,
    f32 = true,
    f64 = true,
    string = true,
    vector = true,
    buffer = true,
}

local OptionsTypes: {[string]: Lexer.Types} = {
    ClientOutput = "String",
    ServerOutput = "String",
    FutureLibrary = "String",
    PromiseLibrary = "String",
    ManualReplication = "Boolean",
}

local ReservedMembers = {
	StepReplication = true
}

local EventStructure: {{Key: string, Type: Lexer.Types, Values: {string}}} = {
    {Key = "From", Type = "Identifier", Values = {"Client", "Server"}},
    {Key = "Type", Type = "Identifier", Values = {"Reliable", "Unreliable"}},
    {Key = "Call", Type = "Identifier", Values = {"SingleSync", "ManySync", "SingleAsync", "ManyAsync"}},
    {Key = "Data", Type = "Identifier", Values = {}}
}

local FunctionStructure: {{Key: string, Type: Lexer.Types, Values: {string}}} = {
    {Key = "Yield", Type = "Identifier", Values = {"Future", "Promise", "Coroutine"}},
    {Key = "Data", Type = "Identifier", Values = {}},
    {Key = "Return", Type = "Identifier", Values = {}}
}

local Number = "[%+%-]?%d+"

local NumberRange = {
    new = function(Min: number, Max: number?): NumberRange
        return {
            Min = Min,
            Max = Max or Min
        }
    end
}

local function GetAttributeRange(Token: Lexer.Token, Array: boolean, Source: string): NumberRange
    local Lower, Upper;
    if Array then
        Lower, Upper = string.match(Token.Value, `^%[({Number})..({Number})]`)
        Lower = Lower or string.match(Token.Value, `^%[({Number})]`)

        if not Upper then
            local Size = tonumber(Lower) or -1
            if Size < 0 then
                Error.ThrowTokenError(Source, Token, "Invalid array size, array cannot be smaller than 1 element")
            end

            return NumberRange.new(Size) :: NumberRange
        end
    else
        Lower, Upper = string.match(Token.Value, `^%(({Number})..({Number})%)`)
        if not Upper then
            Lower = string.match(Token.Value, `^%(({Number})%)`)
        end
    end

    if not Lower then
        error(`Unexpected error while trying to parse range.`)
    end

    local Min = tonumber(Lower) or 0
    local Max;

    if Min < 0 then
        Error.ThrowTokenError(Source, Token, "Invalid range bounds, range cannot be negative")
    end

    if Upper then
        Max = tonumber(Upper) or 0
        if Min >= Max then
            Error.ThrowTokenError(Source, Token, "Invalid range bounds, max must be greater than min")
        end
    end

    return NumberRange.new(Min, Max)
end

local Parser = {}
Parser.__index = Parser

function Parser.new(): Parser
    return setmetatable({
        Source = "",
        Types = {},
        Lexer = Lexer.new()
    } :: any, Parser)
end

function Parser.Parse(self: Parser, Source: string): (Body, Options)
    self.Source = Source
    table.clear(self.Types)
    self.Lexer:Initialize(Source)

    --> Prime the lexer
    self.LookAhead = self.Lexer:GetNextToken()

    --> Parse options
    local Options = self:Options()

    --> Parse source body
    local Body = self:Body()

    return Body, Options
end

function Parser.Consume(self: Parser, Type: string): Lexer.Token
    local Token = self.LookAhead
    if not Token then
        error(`Unexpected end of file, expected: "{Type}".`) 
    end

    if Token.Type ~= Type then
        Error.ThrowTokenError(self.Source, Token, `Unexpected token: "{Token.Type}", expected: "{Type}"`)
    end

    --> Advance tokenizer
    self.LookAhead = self.Lexer:GetNextToken()

    return Token
end

function Parser.GetSafeLookAhead(self: Parser): Lexer.Token
    if self.LookAhead then
        return self.LookAhead
    end

    return {
        Type = "Unknown",
        Value = "\0",
        Start = #self.Source + 1,
        End = #self.Source + 1,
    }
end

function Parser.Body(self: Parser): Body
    return {
        Type = "Body",
        Value = self:Declarations()
    }
end

function Parser.Options(self: Parser): Options
    local Options: Options = {}
    local function ParseOption()
        local LookAhead = self:GetSafeLookAhead()
        if LookAhead.Value ~= "option" then
            return
        end

        self:Consume("Keyword")
        local Key = self:Consume("Identifier")
        self:Consume("Assign")

        local Type: Lexer.Types = OptionsTypes[Key.Value]
        if not Type then
            Error.ThrowTokenError(self.Source, Key, `Unexpected option: "{Key.Value}", expected one of: "ClientOutput" or "ServerOutput" or "ManualReplicationLoop".`)
            return 
        end

        local Value = self:Consume(Type)
        Options[Key.Value] = Value.Value

        ParseOption()
    end

    ParseOption()
    return Options
end

function Parser.Declarations(self: Parser): {Declaration}
    local Declarations = {self:Declaration()}
    while (self.LookAhead) do
        table.insert(Declarations, self:Declaration())
    end

    return Declarations
end

function Parser.Declaration(self: Parser): Declaration
    local Keyword = self:Consume("Keyword")
    local Identifier = self:Consume("Identifier")
    self:Consume("Assign")

    if self.Types[Identifier.Value] then
        Error.ThrowTokenError(self.Source, Identifier, `Duplicate type declared`)
    end

    local Declaration: Declaration?;
    if Keyword.Value == "type" then
        Declaration = self:TypeDeclaration(Identifier)
    elseif Keyword.Value == "enum" then
        Declaration = self:EnumDeclaration(Identifier)
    elseif Keyword.Value == "struct" then
        Declaration = self:StructDeclaration(Identifier)
    elseif Keyword.Value == "event" then
        Declaration = self:EventDeclaration(Identifier)
    elseif Keyword.Value == "function" then
        Declaration = self:FunctionDeclaration(Identifier)
    end
    
    if not Declaration then
        error(`{Keyword.Value} has no declaration handler.`)
    end

    if Keyword.Value ~= "event" and Keyword.Value ~= "function" then
        if self:GetSafeLookAhead().Type == "Optional" then
            self:Consume("Optional")
            Declaration.Value.Optional = true
        end
        
        self.Types[Identifier.Value] = Declaration
    end

    return Declaration
end

function Parser.TypeDeclaration(self: Parser, Identifier: Lexer.Token): TypeDeclaration
    local LookAhead = self:GetSafeLookAhead()

    local Primitive: Lexer.Token;
    local Declaration: TypeDeclaration; 

    if LookAhead.Type == "Identifier" then
        local Reference = self.Types[LookAhead.Value]
        if not Reference then
            Error.ThrowTokenError(self.Source, LookAhead, "Unknown type referenced")
        elseif Reference.Type ~= "TypeDeclaration" then
            Error.ThrowTokenError(self.Source, LookAhead, "Primitives can only reference other primitives")
        end

        self:Consume("Identifier")
        Declaration = Table.DeepClone(Reference)
        Declaration.Value.Identifier = Identifier.Value
    else
        Primitive = self:Consume("Primitive")
        Declaration = {
            Type = "TypeDeclaration",
            Value = {
                Identifier = Identifier.Value,
                Primitive = Primitive.Value,
                Array = false,
                Optional = false
            }
        }
    end

    --> Attempt to read type attributes [Primitive][Range/Array][Optional] [u8(0..1)?]
    local Array, Range = self:GetTypeAttributes(Primitive)
    Declaration.Value.Array = Array
    Declaration.Value.Range = Range

    return Declaration
end

function Parser.EnumDeclaration(self: Parser, Identifier: Lexer.Token): EnumDeclaration
    self:Consume("OpenCurlyBrackets")

    local Enums: {string} = {}
    while (self.LookAhead) do
        --> Allows trailing commas in struct definitions
        if self.LookAhead.Type == "CloseCurlyBrackets" then
            self:Consume("CloseCurlyBrackets")
            break
        end

        local Token = self:Consume("Identifier")
        if string.match(Token.Value, Number) then
            Error.ThrowTokenError(self.Source, Token, `Enums can only contain letters`)
        end

        table.insert(Enums, Token.Value)

        local LookAhead = self:GetSafeLookAhead().Type
        if LookAhead == "Comma" then
            self:Consume("Comma")
        elseif LookAhead == "CloseCurlyBrackets" then
            self:Consume("CloseCurlyBrackets")
            break
        end
    end

    return {
        Type = "EnumDeclaration",
        Value = {
            Identifier = Identifier.Value,
            Enums = Enums,
            Optional = false
        }
    }
end

function Parser.StructDeclaration(self: Parser, Identifier: Lexer.Token): StructDeclaration
    self:Consume("OpenBrackets")

    local Keys: {[string]: boolean} = {}
    local Fields = {}

    while (self.LookAhead) do
        --> Allows trailing commas in struct definitions
        if self:GetSafeLookAhead().Type == "CloseBrackets" then
            self:Consume("CloseBrackets")
            break
        end

        local Key = self:Consume("Identifier")
        self:Consume("Assign")

        if Keys[Key.Value] then
            Error.ThrowTokenError(self.Source, Key, `Duplicate key`)
        end

        local Declaration: Declaration = self:GetDeclarationFromToken(self:GetSafeLookAhead(), Key)
        if self:GetSafeLookAhead().Type == "Optional" then
            self:Consume("Optional")
            Declaration.Value.Optional = true
        end
        
        Keys[Key.Value] = true
        table.insert(Fields, Declaration)

        if self:GetSafeLookAhead().Type == "CloseBrackets" then
            self:Consume("CloseBrackets")
            break
        end

        self:Consume("Comma")
    end

    return {
        Type = "StructDeclaration",
        Value = {
            Identifier = Identifier.Value,
            Fields = Fields,
            Optional = false,
        }
    }
end

function Parser.EventDeclaration(self: Parser, Identifier: Lexer.Token): EventDeclaration
    self:Consume("OpenBrackets")

    if ReservedMembers[Identifier.Value] then
        Error.ThrowTokenError(self.Source, Identifier, `"{Identifier.Value}" is reserved and cannot be used as an event identifier`)
    end

    local Event: EventDeclaration = {
        Type = "EventDeclaration",
        Value = {
            Identifier = Identifier.Value,
            From = "Client",
            Type = "Reliable",
            Call = "SingleSync",
            Data = nil :: any,
            Optional = false
        }
    }

    for Index, Entry in EventStructure do
        local Key = self:Consume("Identifier")
        if Key.Value ~= Entry.Key then
            Error.ThrowTokenError(self.Source, Key, `Unexpected key: {Key.Value}, expected: "{Entry.Key}"`)
        end

        local Value: unknown;
        local Assign = self:Consume("Assign")
        
        if Entry.Key ~= "Data" then
            local Token = self:Consume(Entry.Type)
            if not table.find(Entry.Values, Token.Value) then
                Error.ThrowTokenError(self.Source, Token, `Unexpected value: {Token.Value}, expected one of "{table.concat(Entry.Values, "\" or \"")}"`)
            end

            Value = Token.Value
        else
            local Token = self.LookAhead
            if not Token then
                Error.ThrowTokenError(self.Source, Assign, "Expected value after assignment")
                break
            end

            Value = self:GetDeclarationFromToken(Token, Identifier)
        end

        Event.Value[Entry.Key] = Value 

        if Index ~= #EventStructure then
            self:Consume("Comma")
        end
    end

    self:Consume("CloseBrackets")

    return Event
end

function Parser.FunctionDeclaration(self: Parser, Identifier: Lexer.Token): FunctionDeclaration
    self:Consume("OpenBrackets")

    if ReservedMembers[Identifier.Value] then
        Error.ThrowTokenError(self.Source, Identifier, `"{Identifier.Value}" is reserved and cannot be used as a function identifier`)
    end

    local Function: FunctionDeclaration = {
        Type = "FunctionDeclaration",
        Value = {
            Identifier = Identifier.Value,
            Optional = false,
            Yield = "Coroutine",
            Data = nil :: any,
            Return = nil :: any
        }
    }

    for Index, Entry in FunctionStructure do
        local Key = self:Consume("Identifier")
        if Key.Value ~= Entry.Key then
            Error.ThrowTokenError(self.Source, Key, `Unexpected key: {Key.Value}, expected: "{Entry.Key}"`)
        end

        local Value: unknown;
        local Assign = self:Consume("Assign")
        
        if Entry.Key ~= "Data" and Entry.Key ~= "Return" then
            local Token = self:Consume(Entry.Type)
            if not table.find(Entry.Values, Token.Value) then
                Error.ThrowTokenError(self.Source, Token, `Unexpected value: {Token.Value}, expected one of "{table.concat(Entry.Values, "\" or \"")}"`)
            end

            Value = Token.Value
        else
            local Token = self.LookAhead
            if not Token then
                Error.ThrowTokenError(self.Source, Assign, "Expected value after assignment")
                break
            end

            Value = self:GetDeclarationFromToken(Token, Identifier)
        end

        Function.Value[Entry.Key] = Value 

        if Index ~= #FunctionStructure then
            self:Consume("Comma")
        end
    end

    self:Consume("CloseBrackets")

    return Function
end

function Parser.GetTypeAttributes(self: Parser, Primitive: Lexer.Token?): (boolean, NumberRange?)
    local LookAhead = self.LookAhead
    if not LookAhead then 
        return false
    end

    local Array, Range;
    local Type: Lexer.Types = LookAhead.Type

    if not Attributes[Type] then
        return false
    end
    
    if Type == "Range" then
        if not Primitive then
            Error.ThrowTokenError(self.Source, LookAhead, `"References do not support ranges`)
        elseif not RangePrimitives[Primitive.Value] then
            Error.ThrowTokenError(self.Source, LookAhead, `"{Primitive.Value}" does not support ranges`)
        end
    end

    self:Consume(Type)
    Array = (Type == "Array")
    Range = GetAttributeRange(LookAhead, Array, self.Source)

    return Array, Range
end

function Parser.GetDeclarationFromToken(self: Parser, Token: Lexer.Token, Identifier: Lexer.Token): Declaration
    if Token.Type == "OpenBrackets" then
        return self:StructDeclaration(Identifier)
    elseif Token.Type == "OpenCurlyBrackets" then
        return self:EnumDeclaration(Identifier)
    elseif Token.Type == "Primitive" then
        return self:TypeDeclaration(Identifier)
    elseif Token.Type == "Identifier" then
        local Type = self:Consume("Identifier")
        local Declaration = self.Types[Type.Value]
        if not Declaration then
            Error.ThrowTokenError(self.Source, Type, "Unknown type referenced")
        end

        local Array, Range = self:GetTypeAttributes()
        local Reference: TypeReference = {
            Type = "TypeReference",
            Value = {
                Identifier = Identifier.Value,
                Reference = Type.Value,

                Array = Array,
                Range = Range,
                Optional = false
            }
        }
        
        return Reference
    end

    Error.ThrowTokenError(self.Source, Token, "Unknown type referenced")
    error("Never")
end

return Parser