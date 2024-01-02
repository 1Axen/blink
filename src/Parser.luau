--!strict

local Lexer = require("./Lexer")
local Error = require("./Modules/Error")

type NumberRange = {Min: number, Max: number}
type Declarations = "TypeReference" | "TypeDeclaration" | "EnumDeclaration" | "StructDeclaration" | "PacketDeclaration"

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

export type PacketDeclaration = Node<"PacketDeclaration", {
    Identifier: string,
    Optional: boolean,
    From: "Client" | "Server",
    Type: "Reliable" | "Unreliable",
    Data: Declaration
}>

export type Parser = {
    Source: string,
    Lexer: Lexer.Lexer,

    Types: {[string]: Declaration},
    LookAhead: Lexer.Token?,

    Parse: (self: Parser, Source: string) -> Body,
    Consume: (self: Parser, Type: Lexer.Types) -> Lexer.Token,
    GetSafeLookAhead: (self: Parser) -> Lexer.Token,

    --> Parsable types
    Body: (self: Parser) -> Body,

    Declaration: (self: Parser) -> Declaration,
    Declarations: (self: Parser) -> {Declaration},

    TypeDeclaration: (self: Parser, Identifier: Lexer.Token) -> TypeDeclaration,
    EnumDeclaration: (self: Parser, Identifier: Lexer.Token) -> EnumDeclaration,
    StructDeclaration: (self: Parser, Identifier: Lexer.Token) -> StructDeclaration,
    PacketDeclaration: (self: Parser, Identifier: Lexer.Token) -> PacketDeclaration,

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

local PacketStructure: {{Key: string, Type: Lexer.Types, Values: {string}}} = {
    {Key = "From", Type = "Identifier", Values = {"Client", "Server"}},
    {Key = "Type", Type = "Identifier", Values = {"Reliable", "Unreliable"}},
    {Key = "Data", Type = "Identifier", Values = {}}
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

local Parser = {}
Parser.__index = Parser

function Parser.new(): Parser
    return setmetatable({
        Source = "",
        Types = {},
        Lexer = Lexer.new()
    } :: any, Parser)
end

function Parser.Parse(self: Parser, Source: string)
    self.Source = Source
    table.clear(self.Types)
    self.Lexer:Initialize(Source)

    --> Prime the lexer
    self.LookAhead = self.Lexer:GetNextToken()

    --> Start parsing recursively from the body (Program)
    return self:Body()
end

function Parser.Consume(self: Parser, Type: string): Lexer.Token
    local Token = self.LookAhead
    if not Token then
        error(`Unexpected end of input, expected: "{Type}".`) 
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
    elseif Keyword.Value == "packet" then
        Declaration = self:PacketDeclaration(Identifier)
    end
    
    if not Declaration then
        error(`{Keyword.Value} has no declaration handler.`)
    end

    if Keyword.Value ~= "packet" then
        if self:GetSafeLookAhead().Type == "Optional" then
            self:Consume("Optional")
            Declaration.Value.Optional = true
        end
        
        self.Types[Identifier.Value] = Declaration
    end

    return Declaration
end

function Parser.TypeDeclaration(self: Parser, Identifier: Lexer.Token): TypeDeclaration
    local Primitive = self:Consume("Primitive")

    local Range: NumberRange?;
    local Array = false

    local function GetAttributeRange(Token: Lexer.Token): NumberRange
        local Lower, Upper;
        if Array then
            Lower, Upper = string.match(Token.Value, `^%[({Number})..({Number})]`)
            Lower = Lower or string.match(Token.Value, `^%[({Number})]`)

            if not Upper then
                local Size = tonumber(Lower) or -1
                if Size < 0 then
                    Error.ThrowTokenError(self.Source, Token, "Invalid array size, array cannot be smaller than 1 element")
                end

                return NumberRange.new(Size) :: NumberRange
            end
        else
            Lower, Upper = string.match(Token.Value, `^%(({Number})..({Number})%)`)
        end

        if not Lower or not Upper then
            error(`Unexpected error while trying to parse range.`)
        end

        local Min = tonumber(Lower) or 0
        local Max = tonumber(Upper) or 0

        if Min < 0 then
            Error.ThrowTokenError(self.Source, Token, "Invalid range bounds, range cannot be negative")
        end

        if Min >= Max then
            Error.ThrowTokenError(self.Source, Token, "Invalid range bounds, max must be greater than min")
        end

        return NumberRange.new(Min, Max)
    end

    --> Attempt to read type attributes [Primitive][Range/Array][Optional] [u8(0..1)?]
    local Token = self.LookAhead
    if Token then
        local Type: Lexer.Types = Token.Type
        if Attributes[Type] then
            self:Consume(Type)
        end
        
        if Type == "Array" then
            Array = true
            Range = GetAttributeRange(Token)
        elseif Type == "Range" then
            if not RangePrimitives[Primitive.Value] then
                Error.ThrowTokenError(self.Source, Token, `{Primitive.Value} cannot have a range`)
            end

            Range = GetAttributeRange(Token)
        end
    end

    return {
        Type = "TypeDeclaration",
        Value = {
            Identifier = Identifier.Value,
            Primitive = Primitive.Value,

            Array = Array,
            Range = Range,
            Optional = false
        }
    }
end

function Parser.EnumDeclaration(self: Parser, Identifier: Lexer.Token): EnumDeclaration
    self:Consume("OpenEnum")

    local Enums: {string} = {}
    while (self.LookAhead) do
        --> Allows trailing commas in struct definitions
        if self.LookAhead.Type == "CloseEnum" then
            self:Consume("CloseEnum")
            break
        end

        local Token = self:Consume("Identifier")
        if string.match(Token.Value, Number) then
            Error.ThrowTokenError(self.Source, Token, `Enums can only contain letters`)
        end

        table.insert(Enums, Token.Value)

        local Next = self.LookAhead.Type
        if Next == "Next" then
            self:Consume("Next")
        elseif Next == "CloseEnum" then
            self:Consume("CloseEnum")
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
    self:Consume("Open")

    local Keys: {[string]: boolean} = {}
    local Fields = {}

    while (self.LookAhead) do
        --> Allows trailing commas in struct definitions
        if self:GetSafeLookAhead().Type == "Close" then
            self:Consume("Close")
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

        local Next = self:GetSafeLookAhead().Type
        if Next == "Close" then
            self:Consume("Close")
            break
        end

        self:Consume("Next")
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

function Parser.PacketDeclaration(self: Parser, Identifier: Lexer.Token): PacketDeclaration
    self:Consume("Open")

    local Packet: PacketDeclaration = {
        Type = "PacketDeclaration",
        Value = {
            Identifier = Identifier.Value,
            From = "Client",
            Type = "Reliable",
            Data = nil :: any,
            Optional = false
        }
    }

    for Index, Structure in PacketStructure do
        local Key = self:Consume("Identifier")
        if Key.Value ~= Structure.Key then
            Error.ThrowTokenError(self.Source, Key, `Unexpected key: {Key.Value}, expected: "{Structure.Key}"`)
        end

        local Value: unknown;
        local Assign = self:Consume("Assign")
        
        if Structure.Key ~= "Data" then
            local Token = self:Consume(Structure.Type)
            if not table.find(Structure.Values, Token.Value) then
                Error.ThrowTokenError(self.Source, Token, `Unexpected value: {Token.Value}, expected one of {table.concat(Structure.Values, " or ")}`)
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

        Packet.Value[Structure.Key] = Value 

        if Index ~= #PacketStructure then
            self:Consume("Next")
        end
    end

    self:Consume("Close")

    return Packet
end

function Parser.GetDeclarationFromToken(self: Parser, Token: Lexer.Token, Identifier: Lexer.Token): Declaration
    if Token.Type == "Open" then
        return self:StructDeclaration(Identifier)
    elseif Token.Type == "OpenEnum" then
        return self:EnumDeclaration(Identifier)
    elseif Token.Type == "Primitive" then
        return self:TypeDeclaration(Identifier)
    elseif Token.Type == "Identifier" then
        local Type = self:Consume("Identifier")
        local Declaration = self.Types[Type.Value]
        if not Declaration then
            Error.ThrowTokenError(self.Source, Type, "Unknown type referenced")
        end

        local Reference: TypeReference = {
            Type = "TypeReference",
            Value = {
                Identifier = Identifier.Value,
                Reference = Type.Value,
                Optional = false
            }
        }
        
        return Reference
    end

    Error.ThrowTokenError(self.Source, Token, "Unknown type referenced")
    error("Never")
end

return Parser