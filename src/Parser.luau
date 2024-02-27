--!strict
--!native
--!optimize 2

local Lexer = require("./Lexer")
local Error = require("./Modules/Error")
local Table = require("./Modules/Table")

type NumberRange = {Min: number, Max: number}
type Declarations = "TypeReference" | "MapDeclaration" | "TypeDeclaration" | "EnumDeclaration" | "StructDeclaration" 
    | "TupleDeclaration" | "EventDeclaration" | "FunctionDeclaration" | "ScopeDeclaration"

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
    Scope: string?,
    Identifier: string,
    Reference: string,
    
    Array: NumberRange?,
    Range: NumberRange?,
    Optional: boolean,
}>

export type MapDeclaration = Node<"MapDeclaration", {
    Scope: string?,
    Identifier: string,

    Key: Declaration,
    Value: Declaration,

    Array: NumberRange?,
    Optional: boolean,
}>

export type TypeDeclaration = Node<"TypeDeclaration", {
    Scope: string?,
    Identifier: string,
    Primitive: string,

    Class: string?,
    Array: NumberRange?,
    Range: NumberRange?,
    Optional: boolean,
}>

export type EnumDeclaration = Node<"EnumDeclaration", {
    Scope: string?,
    Identifier: string,
    Enums: {string},
    Optional: boolean,
}>

export type StructDeclaration = Node<"StructDeclaration", {
    Scope: string?,
    Identifier: string,
    Fields: {Declaration},
    Optional: boolean,
}>

export type TupleDeclaration = Node<"TupleDeclaration", {
    Identifier: string,
    Values: {Declaration},
    Optional: boolean
}>

export type EventDeclaration = Node<"EventDeclaration", {
    Scope: string?,
    Identifier: string,
    Optional: boolean,
    From: "Client" | "Server",
    Type: "Reliable" | "Unreliable",
    Call: "SingleSync" | "ManySync" | "SingleAsync" | "ManyAsync",
    Data: Declaration
}>

export type FunctionDeclaration = Node<"FunctionDeclaration", {
    Scope: string?,
    Identifier: string,
    Optional: boolean,
    Yield: "Future" | "Promise" | "Coroutine",
    Data: Declaration,
    Return: Declaration
}>

export type ScopeDeclaration = Node<"ScopeDeclaration", {
    Identifier: string,
    Declarations: {Declaration},
    Optional: boolean,
}>

export type Options = {
    TypesOutput: string?,
    ClientOutput: string?,
    ServerOutput: string?,
    FutureLibrary: string?,
    PromiseLibrary: string?,
    ManualReplication: boolean?,
}

export type Duplicate = {
    Type: string,
    Identifier: Lexer.Token,
    Declaration: Declaration
}

export type Parser = {
    Source: string,
    Lexer: Lexer.Lexer,

    Scope: string?,
    Types: {[string]: Duplicate},
    Events: {[string]: Duplicate},
    LookAhead: Lexer.Token?,

    Parse: (self: Parser, Source: string) -> (Body, Options),
    Consume: (self: Parser, Type: Lexer.Types) -> Lexer.Token,
    ConsumeAny: (self: Parser, Types: {Lexer.Types}) -> Lexer.Token,
    GetSafeLookAhead: (self: Parser) -> Lexer.Token,

    --> Parsable types
    Body: (self: Parser) -> Body,
    Options: (self: Parser) -> Options,

    Declaration: (self: Parser) -> Declaration,
    Declarations: (self: Parser) -> {Declaration},

    MapDeclaration: (self: Parser, Identifier: Lexer.Token) -> MapDeclaration,
    TypeDeclaration: (self: Parser, Identifier: Lexer.Token) -> TypeDeclaration,
    EnumDeclaration: (self: Parser, Identifier: Lexer.Token) -> EnumDeclaration,
    TupleDeclaration: (self: Parser, Identifier: Lexer.Token) -> TupleDeclaration,
    StructDeclaration: (self: Parser, Identifier: Lexer.Token) -> StructDeclaration,
    EventDeclaration: (self: Parser, Identifier: Lexer.Token) -> EventDeclaration,
    FunctionDeclaration: (self: Parser, Identifier: Lexer.Token) -> FunctionDeclaration,
    ScopeDeclaration: (self: Parser, Identifier: Lexer.Token) -> ScopeDeclaration,

    GetReference: (self: Parser, Reference: Lexer.Token) -> Declaration,
    GetTypeAttributes: (self: Parser, Primitive: Lexer.Token?) -> (NumberRange?, NumberRange?),
    GetDeclarationFromToken: (self: Parser, Token: Lexer.Token, Identifier: Lexer.Token) -> (Declaration, Lexer.Token?),
}

local Errors = {
    DuplicateDeclaration = 3001
}

local RangePrimitives = {
    u8 = true,
    u16 = true,
    u32 = true,
    i8 = true,
    i16 = true,
    i32 = true,
    f16 = true,
    f32 = true,
    f64 = true,
    string = true,
    vector = true,
    buffer = true,
}

local OptionsTypes: {[string]: Lexer.Types} = {
    TypesOutput = "String",
    ClientOutput = "String",
    ServerOutput = "String",
    FutureLibrary = "String",
    PromiseLibrary = "String",
    ManualReplication = "Boolean",
}

local ReservedMembers = {
	StepReplication = true
}

local KeywordTypes = {
    map = "Types",
    type = "Types",
    enum = "Types",
    struct = "Types",
    scope = "Events",
    event = "Events",
    ["function"] = "Events"
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

        local Size = tonumber(Lower) or -1
        if Size < 0 then
            Error.new(Error.AnalyzeInvalidRange, Source, "Invalid array size")
                :Primary(Token, "Array cannot be smaller than 0 elements")
            :Emit()
        end

        if not Upper then
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

    --[[if Min < 0 then
        Error.new(Error.AnalyzeInvalidRange, Source, "Invalid range")
            :Primary(Token, "Minimum cannot be negative")
        :Emit()
    end]]

    if Upper then
        Max = tonumber(Upper) or 0
        if Min >= Max then
            Error.new(Error.AnalyzeInvalidRange, Source, "Invalid range")
                :Primary(Token, "Maximum must be greater than minimum")
            :Emit()
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
        Scopes = {},
        Events = {},
        Lexer = Lexer.new()
    } :: any, Parser)
end

function Parser.Parse(self: Parser, Source: string): (Body, Options)
    self.Scope = nil
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

function Parser.ConsumeAny(self: Parser, Types: {Lexer.Types}): Lexer.Token
    local Token = self.LookAhead
    if not Token then
        Error.new(Error.ParserUnexpectedEndOfFile, self.Source, "Unexpected end of file")
            :Primary({Start = #self.Source, End = #self.Source}, "File ends here")
        :Emit()
        
        --> Above already errors
        error("Unexpected end of file")
    end

    if not table.find(Types, Token.Type) then
        Error.new(Error.ParserUnexpectedToken, self.Source, `Unexpected token`)
            :Primary(Token, `Expected one of "{table.concat(Types, "\", ")}", found "{Token.Type}"`)
        :Emit()
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
            Error.new(Error.ParserUnknownOption, self.Source, `Unknown option "{Key.Value}"`)
                :Primary(Key, `Expected one of "ClientOutput" or "ServerOutput" or "ManualReplicationLoop", found "{Key.Value}"`)
            :Emit()
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

    --> Handle duplicate declarations
    local Type = KeywordTypes[Keyword.Value]
    local Duplicates: {[string]: Duplicate} = self[Type]
    local ScopedIdentifier = `{self.Scope and `{self.Scope}.` or ""}{Identifier.Value}`
    local Duplicate = Duplicates[ScopedIdentifier]

    if Duplicate then
        Error.new(Errors.DuplicateDeclaration, self.Source, `Duplicate {Keyword.Value} "{Identifier.Value}"`)
            :Secondary(Duplicate.Identifier, "Previously delcared here")
            :Primary(Identifier, "Duplicate declaration here")
        :Emit()
    end

    --> Parse declaration
    local Declaration: Declaration?;
    if Keyword.Value == "map" then
        Declaration = self:MapDeclaration(Identifier)
    elseif Keyword.Value == "type" then
        Declaration = self:TypeDeclaration(Identifier)
    elseif Keyword.Value == "enum" then
        Declaration = self:EnumDeclaration(Identifier)
    elseif Keyword.Value == "struct" then
        Declaration = self:StructDeclaration(Identifier)
    elseif Keyword.Value == "event" then
        Declaration = self:EventDeclaration(Identifier)
    elseif Keyword.Value == "function" then
        Declaration = self:FunctionDeclaration(Identifier)
    elseif Keyword.Value == "scope" then
        Declaration = self:ScopeDeclaration(Identifier)
    end
    
    if not Declaration then
        error(`{Keyword.Value} has no declaration handler.`)
    end

    if 
        Duplicates == self.Types 
        and (self:GetSafeLookAhead().Type == "Optional")
    then
        self:Consume("Optional")
        Declaration.Value.Optional = true
    end

    --> Save declaration to duplicates
    Duplicates[ScopedIdentifier] = {
        Type = Type,
        Identifier = Identifier,
        Declaration = Declaration
    }

    return Declaration
end

function Parser.TypeDeclaration(self: Parser, Identifier: Lexer.Token): TypeDeclaration
    local LookAhead = self:GetSafeLookAhead()

    local Primitive: Lexer.Token;
    local Declaration: TypeDeclaration; 

    if LookAhead.Type == "Identifier" then
        local Reference = self:GetReference(LookAhead)
        if Reference.Type ~= "TypeDeclaration" then
            Error.new(Error.AnalyzePrimitiveReferencesNonPrimitive, self.Source, `Primitive referencing non primitive type`)
                :Primary(LookAhead, `Primitives can only reference other primitives`)
            :Emit()
        end

        self:Consume("Identifier")
        Declaration = Table.DeepClone(Reference)
        Declaration.Value.Identifier = Identifier.Value
    else
        Primitive = self:Consume("Primitive")
        Declaration = {
            Type = "TypeDeclaration",
            Value = {
                Scope = self.Scope,
                Identifier = Identifier.Value,
                Primitive = Primitive.Value,
                Optional = false
            }
        }

        if Primitive.Value == "Instance" then
            local Class = "Instance"
            LookAhead = self:GetSafeLookAhead()
            
            if LookAhead.Type == "Class" then
                local ClassToken = self:Consume("Class")
                Class = ClassToken.Value
                Class = string.sub(Class, 2, #Class - 1)
            end
    
            Declaration.Value.Class = Class
        end
    end

    --> Attempt to read type attributes [Primitive][Range][Array][Optional] [u8(0..1)[10]?]
    local Value = Declaration.Value
    local Array, Range = self:GetTypeAttributes(Primitive)
    Value.Array = Array
    Value.Range = Range

    return Declaration
end

function Parser.EnumDeclaration(self: Parser, Identifier: Lexer.Token): EnumDeclaration
    self:Consume("OpenBrackets")

    local Enums: {string} = {}
    while (self.LookAhead) do
        --> Allows trailing commas in struct definitions
        if self.LookAhead.Type == "CloseBrackets" then
            self:Consume("CloseBrackets")
            break
        end

        local Token = self:Consume("Identifier")
        local Match = string.match(Token.Value, Number)
        
        if Match then
            Error.new(Error.ParserUnexpectedSymbol, self.Source, `Unexpected symbol "{Match}"`)
                :Primary(Token, `Enums can only contain letters, found "{Match}"`)
            :Emit()
        end

        table.insert(Enums, Token.Value)

        local LookAhead = self:GetSafeLookAhead().Type
        if LookAhead == "Comma" then
            self:Consume("Comma")
        elseif LookAhead == "CloseBrackets" then
            self:Consume("CloseBrackets")
            break
        end
    end

    return {
        Type = "EnumDeclaration",
        Value = {
            Scope = self.Scope,
            Identifier = Identifier.Value,
            Enums = Enums,
            Optional = false
        }
    }
end

function Parser.MapDeclaration(self: Parser, Identifier: Lexer.Token): MapDeclaration
    self:Consume("OpenCurlyBrackets")
    self:Consume("OpenSquareBrackets")

    local Key = self:GetSafeLookAhead()
    local KeyDeclaration, KeyOptional = self:GetDeclarationFromToken(Key, Key)

    if KeyOptional then
        Error.new(Error.AnalyzeInvalidOptionalType, self.Source, "Invalid optional type")
            :Primary(KeyOptional, `Maps cannot have optionals as keys or values`)
        :Emit()
    end

    if KeyDeclaration.Type == "MapDeclaration" then
        Error.new(Error.AnalyzeNestedMap, self.Source, "Nested map")
            :Primary(Key, `Maps cannot have maps as keys or values`)
        :Emit()
    elseif KeyDeclaration.Type == "TypeReference" then
        local Reference = self:GetReference(Key)
        if Reference.Value.Optional then
            Error.new(Error.AnalyzeInvalidOptionalType, self.Source, "Invalid optional type")
                :Primary(Key, `Key is a reference to an optional type, maps cannot have optional keys or values`)
            :Emit()
        elseif Reference.Type == "MapDeclaration" then
            Error.new(Error.AnalyzeNestedMap, self.Source, "Nested map")
                :Primary(Key, `Maps cannot have maps as keys or values`)
            :Emit()
        end
    end

    self:Consume("CloseSquareBrackets")
    self:Consume("Assign")

    local Value = self:GetSafeLookAhead()
    local ValueDeclaration, ValueOptional = self:GetDeclarationFromToken(Value, Value)

    if ValueOptional or ValueDeclaration.Value.Optional then
        Error.new(Error.AnalyzeInvalidOptionalType, self.Source, "Invalid optional type")
            :Primary(ValueOptional, `Maps cannot have optionals as keys or values`)
        :Emit()
    end

    if ValueDeclaration.Type == "MapDeclaration" then
        Error.new(Error.AnalyzeNestedMap, self.Source, "Nested map")
            :Primary(Value, `Maps cannot have maps as keys or values`)
        :Emit()
    elseif ValueDeclaration.Type == "TypeReference" then
        local Reference = self:GetReference(Value)
        if Reference.Value.Optional then
            Error.new(Error.AnalyzeInvalidOptionalType, self.Source, "Invalid optional type")
                :Primary(Value, `Value is a reference to an optional type, maps cannot have optional keys or values`)
            :Emit()
        elseif Reference.Type == "MapDeclaration" then
            Error.new(Error.AnalyzeNestedMap, self.Source, "Nested map")
                :Primary(Value, `Maps cannot have maps as keys or values`)
            :Emit()
        end
    end

    self:Consume("CloseCurlyBrackets")

    local Array = self:GetTypeAttributes()
    return {
        Type = "MapDeclaration",
        Value = {
            Scope = self.Scope,
            Identifier = Identifier.Value,

            Key = KeyDeclaration,
            Value = ValueDeclaration,

            Array = Array,
            Optional = false,
        }
    }
end

function Parser.StructDeclaration(self: Parser, Identifier: Lexer.Token): StructDeclaration
    self:Consume("OpenCurlyBrackets")

    local Keys: {[string]: Lexer.Token} = {}
    local Fields = {}

    while (self.LookAhead) do
        --> Allows trailing commas in struct definitions
        if self:GetSafeLookAhead().Type == "CloseCurlyBrackets" then
            self:Consume("CloseCurlyBrackets")
            break
        end

        local Key = self:Consume("Identifier")
        self:Consume("Assign")

        local Duplicate = Keys[Key.Value]
        if Duplicate then
            Error.new(Error.AnalyzeDuplicateField, self.Source, "Duplicate struct field")
                :Secondary(Duplicate, "Previously declared here")
                :Primary(Key, "Duplicate declared here")
            :Emit()
        end

        local Declaration: Declaration = self:GetDeclarationFromToken(self:GetSafeLookAhead(), Key)

        Keys[Key.Value] = Key
        table.insert(Fields, Declaration)

        if self:GetSafeLookAhead().Type == "CloseCurlyBrackets" then
            self:Consume("CloseCurlyBrackets")
            break
        end

        self:Consume("Comma")
    end

    return {
        Type = "StructDeclaration",
        Value = {
            Scope = self.Scope,
            Identifier = Identifier.Value,
            Fields = Fields,
            Optional = false,
        }
    }
end

function Parser.TupleDeclaration(self: Parser, Identifier: Lexer.Token): TupleDeclaration
    self:Consume("OpenSquareBrackets")

    local Values: {Declaration} = {}
    while (self.LookAhead) do
        --> Allows trailing commas in struct definitions
        if self:GetSafeLookAhead().Type == "CloseSquareBrackets" then
            self:Consume("CloseSquareBrackets")
            break
        end
        
        local Key = self:GetSafeLookAhead()
        local Declaration: Declaration = self:GetDeclarationFromToken(self:GetSafeLookAhead(), Key)
        table.insert(Values, Declaration)

        if self:GetSafeLookAhead().Type == "CloseSquareBrackets" then
            self:Consume("CloseSquareBrackets")
            break
        end

        self:Consume("Comma")
    end

    return {
        Type = "TupleDeclaration",
        Value = {
            Identifier = Identifier.Value,
            Values = Values,
            Optional = false
        }
    }
end

function Parser.EventDeclaration(self: Parser, Identifier: Lexer.Token): EventDeclaration
    self:Consume("OpenCurlyBrackets")

    if ReservedMembers[Identifier.Value] then
        Error.new(Error.AnalyzeReservedIdentifier, self.Source, "Reserved identifier")
            :Primary(Identifier, `"{Identifier.Value}" is reserved and cannot be used as a event identifier`)
        :Emit()
    end

    local Event: EventDeclaration = {
        Type = "EventDeclaration",
        Value = {
            Scope = self.Scope,
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
            Error.new(Error.ParserUnexpectedToken, self.Source, `Unexpected token`)
                :Primary(Key, `Expected "{Entry.Key}", found "{Key.Value}"`)
            :Emit()
        end

        local Value: unknown;
        local Assign = self:Consume("Assign")
        
        if Entry.Key ~= "Data" then
            local Token = self:Consume(Entry.Type)
            if not table.find(Entry.Values, Token.Value) then
                Error.new(Error.ParserUnexpectedToken, self.Source, `Unexpected token`)
                    :Primary(Token, `Expected one of "{table.concat(Entry.Values, "\" or \"")}", found "{Token.Value}"`)
                :Emit()
            end

            Value = Token.Value
        else
            local Token = self.LookAhead
            if not Token then
                Error.new(Error.ParserExpectedExtraToken, self.Source, `Expected a token`)
                    :Primary(Assign, `Expected a value to follow after assignment`)
                :Emit()
                break
            end

            if Token.Type == "OpenSquareBrackets" then
                Value = self:TupleDeclaration(Identifier)
            else
                Value = self:GetDeclarationFromToken(Token, Identifier)
            end
        end

        Event.Value[Entry.Key] = Value 

        if Index ~= #EventStructure then
            self:Consume("Comma")
        end
    end

    self:Consume("CloseCurlyBrackets")

    return Event
end

function Parser.FunctionDeclaration(self: Parser, Identifier: Lexer.Token): FunctionDeclaration
    self:Consume("OpenCurlyBrackets")

    if ReservedMembers[Identifier.Value] then
        Error.new(Error.AnalyzeReservedIdentifier, self.Source, "Reserved identifier")
            :Primary(Identifier, `"{Identifier.Value}" is reserved and cannot be used as a function identifier`)
        :Emit()
    end

    local Function: FunctionDeclaration = {
        Type = "FunctionDeclaration",
        Value = {
            Scope = self.Scope,
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
            Error.new(Error.ParserUnexpectedToken, self.Source, `Unexpected token`)
                :Primary(Key, `Expected "{Entry.Key}", found "{Key.Value}"`)
            :Emit()
        end

        local Value: unknown;
        local Assign = self:Consume("Assign")
        
        if Entry.Key ~= "Data" and Entry.Key ~= "Return" then
            local Token = self:Consume(Entry.Type)
            if not table.find(Entry.Values, Token.Value) then
                Error.new(Error.ParserUnexpectedToken, self.Source, `Unexpected token`)
                    :Primary(Token, `Expected one of "{table.concat(Entry.Values, "\" or \"")}", found "{Token.Value}"`)
                :Emit()
            end

            Value = Token.Value
        else
            local Token = self.LookAhead
            if not Token then
                Error.new(Error.ParserExpectedExtraToken, self.Source, `Expected a token`)
                    :Primary(Assign, `Expected a value to follow after assignment`)
                :Emit()
                break
            end

            if Token.Type == "OpenSquareBrackets" then
                Value = self:TupleDeclaration(Identifier)
            else
                Value = self:GetDeclarationFromToken(Token, Identifier)
            end
        end

        Function.Value[Entry.Key] = Value 

        if Index ~= #FunctionStructure then
            self:Consume("Comma")
        end
    end

    self:Consume("CloseCurlyBrackets")

    return Function
end

function Parser.ScopeDeclaration(self: Parser, Identifier: Lexer.Token): ScopeDeclaration
    if self.Scope then
        Error.new(Error.AnalyzeNestedScope, self.Source, "Nested scope")
            :Primary(Identifier, `Blink doesn't currently support declaring scopes within scopes`)
        :Emit()
    end

    if ReservedMembers[Identifier.Value] then
        Error.new(Error.AnalyzeReservedIdentifier, self.Source, "Reserved identifier")
            :Primary(Identifier, `"{Identifier.Value}" is reserved and cannot be used as a scope identifier`)
        :Emit()
    end

    local Scope = Identifier.Value
    local Declarations = {}
    local Declaration: ScopeDeclaration = {
        Type = "ScopeDeclaration",
        Value = {
            Identifier = Scope,
            Optional = false,
            Declarations = Declarations
        }
    }

    self.Scope = Scope
    self:Consume("OpenCurlyBrackets")

    while (self.LookAhead) do
        if self.LookAhead.Type == "CloseCurlyBrackets" then
            self:Consume("CloseCurlyBrackets")
            break
        end

        table.insert(Declarations, self:Declaration())
    end 

    self.Scope = nil

    return Declaration
end

function Parser.GetReference(self: Parser, Token: Lexer.Token): Declaration
    local Identifier = `{self.Scope and `{self.Scope}.` or ""}{Token.Value}`
    local Reference = self.Types[Identifier] or self.Types[Token.Value]
    if not Reference then
        Error.new(Error.AnalyzeUnknownReference, self.Source, "Unknown reference")
            :Primary(Token, `Unknown type referenced`)
        :Emit()
    end

    return Reference.Declaration
end

function Parser.GetTypeAttributes(self: Parser, Primitive: Lexer.Token?): (NumberRange?, NumberRange?)
    local Array, Range;
    for _, Expected in {"Range", "Array"} do
        local LookAhead = self.LookAhead
        if not LookAhead then 
            break
        end

        local Type: Lexer.Types = LookAhead.Type
        if Type ~= Expected then
            continue
        end
        
        if Type == "Range" then
            if not Primitive then
                Error.new(Error.AnalyzeInvalidRangeType, self.Source, "Type does not support ranges")
                    :Primary(LookAhead, `References do not support ranges`)
                :Emit()
            elseif not RangePrimitives[Primitive.Value] then
                Error.new(Error.AnalyzeInvalidRangeType, self.Source, "Type does not support ranges")
                    :Primary(LookAhead, `"{Primitive.Value}" does not support ranges`)
                :Emit()
            end

            Range = GetAttributeRange(LookAhead, false, self.Source)
        elseif Type == "Array" then
            Array = GetAttributeRange(LookAhead, true, self.Source)
        end

        self:Consume(Type)
    end

    return Array, Range
end

function Parser.GetDeclarationFromToken(self: Parser, Token: Lexer.Token, Identifier: Lexer.Token): (Declaration, Lexer.Token?)
    local Declaration: Declaration;
    if Token.Type == "OpenCurlyBrackets" then
        local NextToken = self.Lexer:GetNextToken(true)
        if NextToken and NextToken.Type == "OpenSquareBrackets" then
            Declaration = self:MapDeclaration(Identifier)
        else
            Declaration = self:StructDeclaration(Identifier)
        end
    elseif Token.Type == "OpenBrackets" then
        Declaration = self:EnumDeclaration(Identifier)
    elseif Token.Type == "Primitive" then
        Declaration = self:TypeDeclaration(Identifier)
    elseif Token.Type == "Identifier" then
        local Type = self:Consume("Identifier")
        local Reference = self:GetReference(Type)
        local Array, Range = self:GetTypeAttributes()

        Declaration = {
            Type = "TypeReference",
            Value = {
                Scope = Reference.Value.Scope,
                Identifier = Identifier.Value,
                Reference = Reference.Value.Identifier,

                Array = Array,
                Range = Range,
                Optional = false
            }
        }
    end

    if not Declaration then
        Error.new(Error.AnalyzeUnknownReference, self.Source, "Unknown reference")
            :Primary(Token, `Unknown type referenced`)
        :Emit()
    end

    local Optional;
    if self:GetSafeLookAhead().Type == "Optional" then
        Optional = self:Consume("Optional")
        Declaration.Value.Optional = true
    end

    return Declaration, Optional
end

return Parser