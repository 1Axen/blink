--!strict
--!native
--!optimize 2

local Lexer = require("./Lexer")
local Error = require("./Modules/Error")
local Settings = require("./Settings")

---- Globals ----

type NumberRange = {Min: number, Max: number}
local NumberRange = {
    new = function(Min: number, Max: number?): NumberRange
        return {
            Min = Min,
            Max = Max or Min
        }
    end
}

---- Types ----

type Token = Lexer.Token

type Node<Type, Body> = {
    Type: Type,
    Value: Body
}

type EventOption = {
    Key: string, 
    Type: Lexer.Types, 
    Values: {string}
}

type Attributes = {
    Array: {
        Bounds: NumberRange,
        Optional: boolean
    }?,
    Range: NumberRange,
    Optional: boolean?
}

type Reference = {
    Identifier: Token,
    Declaration: Declaration
}

export type Options = {
    TypesOutput: string?,
    ClientOutput: string?,
    ServerOutput: string?,
    FutureLibrary: string?,
    PromiseLibrary: string?,
    ManualReplication: boolean?,
}

export type Body = Node<"Body", {
    Options: Options,
    Declarations: {Declaration}
}>

export type Declaration = Node<any, {
    Identifier: string,
    [any]: any
}>

export type TypeDeclaration = MapDeclaration | EnumDeclaration | StructDeclaration | PrimitiveDeclaration

export type MapDeclaration = Node<"Map", {
    Identifier: string,
    Key: TypeDeclaration,
    Value: TypeDeclaration
} & Attributes>

export type EnumDeclaration = Node<"Enum", {
    Identifier: string,
    Values: {string}
} & Attributes>

export type StructDeclaration = Node<"Enum", {
    Identifier: string,
    Values: {TypeDeclaration}
} & Attributes>

export type PrimitiveDeclaration = Node<"Primitive", {
    Identifier: string,
    Primitive: Settings.Primitive,
} & Attributes>

export type TupleDeclaration = Node<"Tuple", {
    Identifier: string,
    Values: {TypeDeclaration}
}>

export type EventDeclaration = Node<"Event", {
    Identifier: string,
    From: "Client" | "Server",
    Type: "Reliable" | "Unreliable",
    Call: "SingleSync" | "SingleAsync",
    Data: TypeDeclaration | TupleDeclaration 
}>

export type FunctionDeclaration = Node<"Function", {
    Identifier: string,
    Yield: "Future" | "Promise" | "Coroutine",
    Data: TypeDeclaration | TupleDeclaration,
    Return: TypeDeclaration | TupleDeclaration
}>

export type ScopeDeclaration = Node<"Scope", {
    Identifier: string,
    Values: {Declaration}
}> 

---- Settings ----

local OPTIONS: {[string]: Lexer.Types} = {
    TypesOutput = "String",
    ClientOutput = "String",
    ServerOutput = "String",
    FutureLibrary = "String",
    PromiseLibrary = "String",
    ManualReplication = "Boolean",
}

local EVENT: {EventOption} = {
    {Key = "From", Type = "Identifier", Values = {"Client", "Server"}},
    {Key = "Type", Type = "Identifier", Values = {"Reliable", "Unreliable"}},
    {Key = "Call", Type = "Identifier", Values = {"SingleSync", "SingleAsync"}},
    {Key = "Data", Type = "Identifier", Values = {}}
}

local FUNCTION: {EventOption} = {
    {Key = "Yield", Type = "Identifier", Values = {"Future", "Promise", "Coroutine"}},
    {Key = "Data", Type = "Identifier", Values = {}},
    {Key = "Return", Type = "Identifier", Values = {}}
}

local PRIMITIVES = Settings.Primtives
local ARRAY_BOUNDS = NumberRange.new(0, (PRIMITIVES.u16.Bounds :: NumberRange).Max)

---- Variables -----

local TotalOptions = 0
for _ in OPTIONS do
    TotalOptions += 1
end

---- Main ----

local Parser = {}
Parser.__index = Parser

export type Parser = typeof(setmetatable({} :: {
    Source: string,

    Lexer: Lexer.Lexer,
    LookAhead: Token?,

    Scope: string?,
    Types: {[string]: Reference},
    Events: {[string]: Reference}
}, Parser))

function Parser.new(): Parser
    return setmetatable({
        Source = "",
        Lexer = Lexer.new("Parsing"),
        Types = {},
        Events = {}
    }, Parser)
end

---- Lexer Functions -----

function Parser.Consume(self: Parser, Type: Lexer.Types): Token
    local Token = self.LookAhead
    if not Token then
        Error.new(Error.ParserUnexpectedEndOfFile, self.Source, "Unexpected end of file")
            :Primary({Start = #self.Source, End = #self.Source}, "File ends here")
        :Emit()
        
        --> Above already errors
        error("Unexpected end of file")
    end

    if Token.Type ~= Type then
        Error.new(Error.ParserUnexpectedToken, self.Source, `Unexpected token`)
            :Primary(Token, `Expected "{Type}", found "{Token.Type}"`)
        :Emit()
    end

    --> Advance tokenizer
    self.LookAhead = self.Lexer:GetNextToken()

    return Token
end

function Parser.TryConsume(self: Parser, Type: Lexer.Types): Token?
    local Token = self.LookAhead
    if not Token then
        return
    end

    if Token.Type ~= Type then
        return
    end

    --> Advance lexer
    self.LookAhead = self.Lexer:GetNextToken()

    return Token
end

function Parser.ConsumeAll(self: Parser, ...: Lexer.Types): (...Token)
    local Tokens = {}
    for _, Type: Lexer.Types in {...} do
        table.insert(Tokens, self:Consume(Type))
    end

    return table.unpack(Tokens)
end

---- Top-Level Parsing Functions ----

function Parser.Parse(self: Parser, Source: string): Body
    --> Reset state
    self.Scope = nil
    table.clear(self.Types)
    table.clear(self.Events)
    
    --> Start the lexer
    self.Lexer:Initialize(Source)
    self.LookAhead = self.Lexer:GetNextToken()

    return {
        Type = "Body",
        Value = {
            Options = self:Options(),
            Declarations = self:Declarations()
        }
    }
end

function Parser.Options(self: Parser): Options
    local Options: Options = {}
    for Index = 1, TotalOptions do
        local Keyword = self:TryConsume("Keyword")
        if not Keyword or Keyword.Value ~= "option" then
            break
        end

        local Key = self:ConsumeAll("Identifier", "Assign")
        local Identifier = Key.Value
        
        local Type = Options[Identifier]
        if not Type then
            Error.new(Error.ParserUnknownOption, self.Source, `Unknown option "{Identifier}"`)
                :Primary(Key, `Expected one of "ClientOutput" or "ServerOutput" or "ManualReplicationLoop", found "{Identifier}"`)
            :Emit()
        end

        local Value = self:Consume(Type)
        Options[Identifier] = Value
    end

    return Options
end

function Parser.Declarations(self: Parser): {Declaration}
    return {}
end

return Parser