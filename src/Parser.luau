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

type Type = "Type" | "Event" | "Scope"
type Node<Type, Body, Tokens> = {
    Type: Type,
    Value: Body,
    Tokens: Tokens
}

type Array = {
    Bounds: NumberRange,
    Optional: boolean
}

type EventOption = {
    Key: string, 
    Type: Lexer.Types, 
    Values: {string}
}

type Attributes = {
    Scope: string?,
    Array: Array?,
    Range: NumberRange?,
    Optional: boolean?
}

type AttributesTokens = {
    Array: Token?,
    Range: Token?,
    Optional: Token?
}

type Reference = {
    Identifier: Token,
    Declaration: Declaration
}

export type Options = {
    Casing: string?,
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
}, {}>

type Declarations = "Map" | "Enum" | "Tuple" | "Struct" | "Primitive" | "Reference" | "Event" | "Function" | "Scope" 
export type TypeDeclaration = MapDeclaration | EnumDeclaration | TupleDeclaration | StructDeclaration | PrimitiveDeclaration | ReferenceDeclaration

export type Declaration = Node<Declarations, {
    Identifier: string,
    [any]: any
}, {
    [any]: any
}>

export type MapDeclaration = Node<"Map", {
    Identifier: string,
    Key: TypeDeclaration,
    Value: TypeDeclaration
} & Attributes, AttributesTokens>

export type EnumDeclaration = Node<"Enum", {
    Identifier: string,
    Values: {string}
} & Attributes, AttributesTokens>

export type StructDeclaration = Node<"Struct", {
    Identifier: string,
    Values: {TypeDeclaration}
} & Attributes, AttributesTokens>

export type PrimitiveDeclaration = Node<"Primitive", {
    Identifier: string,
    Class: string?,
    Primitive: Settings.Primitive,
} & Attributes, {
    Primitive: Token
} & AttributesTokens>

export type ReferenceDeclaration = Node<"Reference", {
    Identifier: string,
    Declaration: TypeDeclaration
} & Attributes, AttributesTokens>

export type TupleDeclaration = Node<"Tuple", {
    Identifier: string,
    Values: {TypeDeclaration}
} & Attributes, AttributesTokens>

export type EventDeclaration = Node<"Event", {
    Identifier: string,
    From: "Client" | "Server",
    Type: "Reliable" | "Unreliable",
    Call: "SingleSync" | "SingleAsync",
    Data: TypeDeclaration | TupleDeclaration 
}, {}>

export type FunctionDeclaration = Node<"Function", {
    Identifier: string,
    Yield: "Future" | "Promise" | "Coroutine",
    Data: TypeDeclaration | TupleDeclaration,
    Return: TypeDeclaration | TupleDeclaration
}, {}>

export type ScopeDeclaration = Node<"Scope", {
    Identifier: string,
    Values: {Declaration}
}, {}> 

---- Settings ----

local OPTIONS: {[string]: Lexer.Types} = {
    Casing = "Identifier",
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

local KEYWORDS = {
    map = "Type",
    enum = "Type",
    type = "Type",
    struct = "Type",
    event = "Event",
    ["function"] = "Function",
    scope = "Scope",
}

local TYPE_KEYWORDS = {
    map = "Map",
    enum = "Enum",
    type = "Primitive"
}

local RESERVED = {
    StepReplication = true
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

function Parser.Peek(self: Parser): Token
    local Token = self.LookAhead
    if not Token then
        error(Error.new(Error.ParserUnexpectedEndOfFile, self.Source, "Unexpected end of file")
            :Primary({Start = #self.Source, End = #self.Source}, "File ends here")
        :Emit())
    end

    return Token
end

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
    --print(Type, Token.Value, debug.info(2, "nl"))
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
    --print(Type, Token.Value, debug.info(2, "nl"))
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

---- Utility Parsing Functions ----

function Parser.GetReference(self: Parser, Type: Type, Identifier: Token, OnlyWithinScope: boolean?): Reference?
    local Name = Identifier.Value
    local WithScope = `{self.Scope and `{self.Scope}.` or ""}{Name}`
    local ReferenceHashMap = (Type == "Type" and self.Types or self.Events)
    if OnlyWithinScope then
        return ReferenceHashMap[WithScope]
    end

    return ReferenceHashMap[Name] or ReferenceHashMap[WithScope]
end

function Parser.SetReference(self: Parser, Type: Type, Identifier: Token, Declaration: Declaration)
    local Name = `{self.Scope and `{self.Scope}.` or ""}{Identifier.Value}`
    local ReferenceHashMap = (Type == "Type" and self.Types or self.Events)
    if Type ~= "Type" and RESERVED[Name] then
        Error.new(Error.AnalyzeReservedIdentifier, self.Source, `Reserved identifier`)
            :Primary(Identifier, `"{Name}" is reserved and cannot be used as an identifier.`)
            :Emit()
    end

    ReferenceHashMap[Name] = {
        Identifier = Identifier,
        Declaration = Declaration
    }
end

function Parser.GetTypeAttributes(self: Parser, Primitive: Settings.Primitive?): (NumberRange?, boolean, Array?, Token?, Token?, Token?, Token?)
    local function TryToParseOptional(): (boolean, Token?)
        local Token = self:TryConsume("Optional")
        return (Token ~= nil), Token
    end

    local function TryToParseRange(): (NumberRange?, Token?)
        if not Primitive then
            return
        end

        local Token = self:TryConsume("Range")
        if not Token then
            return
        end

        local Value = Token.Value
        
        --> Parse exact range bounds
        local Single = tonumber(string.match(Value, "%((%d+)%)"))
        if Single then
            return NumberRange.new(Single), Token
        end

        --> Parse inexact range bounds
        local Lower, Upper = string.match(Value, "%((%d+)..(%d+)%)")
        local Minimum, Maximum = tonumber(Lower), tonumber(Upper)
        if Minimum and Maximum then
            return NumberRange.new(Minimum, Maximum), Token
        end

        error(Error.new(Error.AnalyzeInvalidRange, self.Source, "Malformed range")
            :Primary(Token, "Unable to parse range")
            :Emit()
        )
    end

    local function TryToParseArray(): (Array?, Token?, Token?)
        local Token = self:TryConsume("Array")
        if not Token then
            return
        end

        local Value = Token.Value
        local Optional, OptionalToken = TryToParseOptional()

        --> Empty bounds
        if Value == "[]" then
            return {
                Bounds = ARRAY_BOUNDS,
                Optional = Optional,
            }, Token, OptionalToken
        end
        
        --> Parse exact range bounds
        local Single = tonumber(string.match(Value, "%[(%d+)%]"))
        if Single then
            return {
                Bounds = NumberRange.new(Single),
                Optional = Optional,
            }, Token, OptionalToken
        end

        --> Parse inexact range bounds
        local Lower, Upper = string.match(Value, "%[(%d+)..(%d+)%]")
        local Minimum, Maximum = tonumber(Lower), tonumber(Upper)
        if Minimum and Maximum then
            return {
                Bounds = NumberRange.new(Minimum, Maximum),
                Optional = Optional,
            }, Token, OptionalToken
        end

        error(Error.new(Error.AnalyzeInvalidRange, self.Source, "Malformed array range")
            :Primary(Token, "Unable to parse array range")
            :Emit()
        )
    end

    local Range, RangeToken = TryToParseRange()
    local Optional, OptionalToken = TryToParseOptional()
    local Array, ArrayToken, ArrayOptionalToken = TryToParseArray()

    if Primitive then
        if RangeToken and Primitive.AllowsRange == false then
            Error.new(Error.AnalyzeInvalidRangeType, self.Source, "Type does not support ranges")
                :Primary(RangeToken, `Type does not support ranges`)
            :Emit()
        end

        if OptionalToken and Primitive.AllowsOptional == false then
            Error.new(Error.AnalyzeInvalidOptionalType, self.Source, "Type cannot be optional")
                :Primary(OptionalToken, `Type cannot be optional`)
            :Emit()
        end

        local Bounds = Primitive.Bounds
        if RangeToken and Bounds and Range and (Range.Min < Bounds.Min or Range.Max > Bounds.Max) then
            Error.new(Error.AnalyzeInvalidRange, self.Source, "Range out of bounds")
                :Primary(RangeToken, `Range out of bounds ({Bounds.Min} -> {Bounds.Max})`)
            :Emit()
        end
    end

    return Range, Optional, Array, RangeToken, OptionalToken, ArrayToken, ArrayOptionalToken
end

---- Top-Level Parsing Functions ----

function Parser.Parse(self: Parser, Source: string): Body
    --> Set state
    self.Scope = nil
    self.Source = Source
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
        },
        Tokens = {}
    }
end

function Parser.Options(self: Parser): Options
    local Options: Options = {}
    for Index = 1, TotalOptions do
        local Keyword = self:Peek()
        if Keyword.Value ~= "option" then
            break
        end

        self:Consume("Keyword")
        local Key = self:ConsumeAll("Identifier", "Assign")
        local Identifier = Key.Value
        
        local Type: Lexer.Types = OPTIONS[Identifier]
        if not Type then
            local Examples = ""
            for Option in OPTIONS do
                Examples ..= `{Examples ~= "" and " or " or ""}"{Option}"`
            end

            Error.new(Error.ParserUnknownOption, self.Source, `Unknown option "{Identifier}"`)
                :Primary(Key, `Expected one of {Examples}`)
            :Emit()
        end

        local Value = self:Consume(Type)
        Options[Identifier] = Value.Value
    end

    return Options
end

function Parser.Declarations(self: Parser): {Declaration}
    local Declarations = {}
    while true do
        if self:TryConsume("EndOfFile") then
            break
        end

        if self.Scope and self:TryConsume("CloseCurlyBrackets") then
            break
        end

        local Keyword = self:Consume("Keyword")
        local Identifier = self:Consume("Identifier")
        local Declaration: Declaration;

        --> Prevent duplicates
        local Type = KEYWORDS[Keyword.Value]
        local Reference = self:GetReference(Type, Identifier, true)
        if Reference then
            Error.new(Error.AnalyzeDuplicateDeclaration, self.Source, `Duplicate {Keyword.Value} declared`)
                :Secondary(Reference.Identifier, "Previously declared here")
                :Primary(Identifier, "Duplicate declared here")
                :Emit()
        end

        if Type == "Type" then
           local TypeDeclaration = self:Type(Identifier, Keyword)
           local Value: Attributes = TypeDeclaration.Value
           Value.Scope = self.Scope
           Declaration = TypeDeclaration
        elseif Type == "Event" then
            Declaration = self:Event(Identifier)
        elseif Type == "Function" then
            Declaration = self:Function(Identifier)
        elseif Type  == "Scope" then
            Declaration = self:Namespace(Identifier)
        end
        
        table.insert(Declarations, Declaration)
        self:SetReference(Type, Identifier, Declaration)
    end

    return Declarations
end

---- Structure Parsing Functions ----

function Parser.GetOptionFromToken(self: Parser, Token: Token, Structure: {EventOption}): EventOption
    local Value = Token.Value
    for Index, Option in Structure do
        local Key = Option.Key
        if Key == Value or string.lower(Key) == Value then
            return Option
        end
    end

    local OptionsString = ""
    for Index, Option in Structure do
        OptionsString ..= `{Index ~= 1 and " or " or ""}"Option.Key"`
    end

    error(Error.new(Error.ParserUnknownOption, self.Source, `Unknown option "{Value}"`)
        :Primary(Token, `Expected one of {OptionsString}`)
        :Emit())
end

function Parser.Structure(self: Parser, Identifier: Token, Structure: {EventOption}): {[string]: any}
    local Fields: {[string]: any} = {}
    for Index = 1, #Structure do
        local Field = self:ConsumeAll("Identifier", "FieldAssign")
        local Option = self:GetOptionFromToken(Field, Structure)

        --> Parse non data field
        local Value: any;
        if Option.Key ~= "Data" and Option.Key ~= "Return" then
            local Token = self:Consume(Option.Type)
            Value = Token.Value

            if not table.find(Option.Values, Value) then
                Error.new(Error.ParserUnknownOption, self.Source, `Unknown option "{Value}"`)
                    :Primary(Token, `Expected of on "{table.concat(Option.Values, `" or "`)}"`)
                    :Emit()
            end
        else
            Value = self:Type(Identifier, nil, true)
        end

        Fields[Field.Value] = Value
        self:TryConsume("Comma")
    end

    return Fields
end

function Parser.Event(self: Parser, Identifier: Token): EventDeclaration
    self:Consume("OpenCurlyBrackets")
    local Structure = self:Structure(Identifier, EVENT)
    self:Consume("CloseCurlyBrackets")

    return {
        Type = "Event",
        Value = {
            Identifier = Identifier.Value,
            From = Structure.From,
            Type = Structure.Type,
            Call = Structure.Call,
            Data = Structure.Data
        },
        Tokens = {}
    }
end

function Parser.Function(self: Parser, Identifier: Token): FunctionDeclaration
    self:Consume("OpenCurlyBrackets")
    local Structure = self:Structure(Identifier, FUNCTION)
    self:Consume("CloseCurlyBrackets")

    return {
        Type = "Function",
        Value = {
            Identifier = Identifier.Value,
            Yield = Structure.Yield,
            Data = Structure.Data,
            Return = Structure.Return
        },
        Tokens = {}
    }
end

function Parser.Namespace(self: Parser, Identifier: Token): ScopeDeclaration
    if self.Scope then
        Error.new(Error.AnalyzeNestedScope, self.Source, "You cannot declare a scope within a scope")
            :Primary(Identifier, `Nested scope declared`)
            :Emit()
    end

    self:Consume("OpenCurlyBrackets")

    --> Open scope
    self.Scope = Identifier.Value
    local Declarations = self:Declarations()

    --> Close scope
    self.Scope = nil
    --self:Consume("CloseCurlyBrackets") --> Consumed by self:Declarations()

    return {
        Type = "Scope",
        Value = {
            Identifier = Identifier.Value,
            Values = Declarations
        },
        Tokens = {}
    }
end

---- Type Parsing Functions ----

function Parser.Type(self: Parser, Identifier: Token, Keyword: Token?, IsDataField: boolean?): TypeDeclaration
    local Declaration: TypeDeclaration;

    --> Fast path: We know the exact type
    if Keyword then
        local Value = Keyword.Value
        if Value ~= "struct" then
            self:Consume("Assign")

            --> Handle reference declarations
            local Type = TYPE_KEYWORDS[Value]
            local Token = self:Peek()
            
            if Token.Type == "Identifier" then
                Declaration = self:Reference(Identifier)
                local Reference = (Declaration :: ReferenceDeclaration).Value.Declaration
                if Reference.Type ~= Type then
                    Error.new(Error.AnalyzeReferenceInvalidType, self.Source, `Cannot cast "{Declaration.Type}" to "{Type}"`)
                        :Primary(Token, `Expected a reference to "{Type}", got "{Declaration.Type}" instead`)
                        :Emit()
                end
            end
        end

        --> Wasn't a reference declaration
        if not Declaration then
            if Value == "map" then
                Declaration = self:Map(Identifier)
            elseif Value == "enum" then
                Declaration = self:Enum(Identifier)
            elseif Value == "type" then
                Declaration = self:Primitive(Identifier)
            elseif Value == "struct" then
                Declaration = self:Struct(Identifier)
            end
        end
    end

    --> Slow path: We have to figure out what we're declaring :)
    if not Keyword then
        local Peek = self:Peek()
        local Type: Lexer.Types = Peek.Type :: Lexer.Types
        
        if Type == "OpenCurlyBrackets" then
            local FarPeek = self.Lexer:GetNextToken(true)
            if FarPeek.Type == "OpenSquareBrackets" then
                Declaration = self:Map(Identifier)
            elseif FarPeek.Type == "CloseCurlyBrackets" then
                Declaration = self:Struct(Identifier) 
            else
                local FurtherPeek = self.Lexer:GetNextToken(true, FarPeek.End)
                if FurtherPeek.Type == "FieldAssign" then 
                    Declaration = self:Struct(Identifier) 
                else 
                    Declaration = self:Enum(Identifier) 
                end
            end
        elseif Type == "Primitive" then
            Declaration = self:Primitive(Identifier)
        elseif Type == "Identifier" then
            Declaration = self:Reference(Identifier)
        elseif Type == "OpenBrackets" and IsDataField then
            Declaration = self:Tuple(Identifier)
        end
    end

    --> Set type attributes
    local Primitive: Settings.Primitive?;
    if Declaration.Type == "Primitive" then
        Primitive = (Declaration :: PrimitiveDeclaration).Value.Primitive
    end

    local Value = Declaration.Value :: Attributes
    local Tokens = Declaration.Tokens :: AttributesTokens
    Value.Range, Value.Optional, Value.Array, Tokens.Range, Tokens.Optional, Tokens.Array = self:GetTypeAttributes(Primitive)

    return Declaration
end


function Parser.Map(self: Parser, Identifier: Token): MapDeclaration
    self:ConsumeAll("OpenCurlyBrackets", "OpenSquareBrackets")

    --> Errors
    local function ThrowOptional(Token: Error.Span, IsReference: boolean?): never
        error(Error.new(Error.AnalyzeInvalidOptionalType, self.Source, "Invalid optional type")
            :Primary(Token, `{IsReference and "Declaration is a reference to an optional. " or ""}Maps cannot have maps as keys or values`)
            :Emit())
    end

    local function ThrowNestedMap(Token: Error.Span): never
        error(Error.new(Error.AnalyzeNestedMap, self.Source, "Nested map")
            :Primary(Token, `Maps cannot have maps as keys or values`)
            :Emit())
    end

    local function ParseElement(): TypeDeclaration
        local Token = self:Peek()
        local Declaration = self:Type(Identifier)

        local Type = Declaration.Type
        local Value = Declaration.Value

        if Type == "Map" then
            ThrowNestedMap(Token)
        elseif Type == "Reference" then
            local Reference: TypeDeclaration = (Value :: any).Declaration
            if Reference.Type == "Map" then
                ThrowNestedMap(Token)
            elseif Reference.Value.Optional then
                ThrowOptional(Token)
            end
        end

        return Declaration
    end

    --> Parse key and value
    local Key = ParseElement()
    self:Consume("CloseSquareBrackets")
    self:Consume("FieldAssign")

    local Value = ParseElement()
    self:Consume("CloseCurlyBrackets")

    return {
        Type = "Map",
        Value = {
            Identifier = Identifier.Value,
            Key = Key,
            Value = Value
        },
        Tokens = {}
    }
end

function Parser.Enum(self: Parser, Identifier: Token): EnumDeclaration
    local Values: {string} = {}
    self:Consume("OpenCurlyBrackets")

    while true do
        if self:TryConsume("CloseCurlyBrackets") then
            break
        end

        local Token = self:Consume("Identifier")
        table.insert(Values, Token.Value)

        if self:TryConsume("CloseCurlyBrackets") then
            break
        end

        self:Consume("Comma")
    end

    return {
        Type = "Enum",
        Value = {
            Identifier = Identifier.Value,
            Values = Values,
        },
        Tokens = {}
    }
end

function Parser.Tuple(self: Parser, Identifier: Token): TupleDeclaration
    local Values: {TypeDeclaration} = {}
    self:Consume("OpenBrackets")

    while true do
        if self:TryConsume("CloseBrackets") then
            break
        end

        local Value = self:Type(Identifier)
        table.insert(Values, Value)

        if self:TryConsume("CloseBrackets") then
            break
        end

        self:Consume("Comma")
    end

    return {
        Type = "Tuple",
        Value = {
            Identifier = Identifier.Value,
            Values = Values,
        },
        Tokens = {}
    }
end

function Parser.Struct(self: Parser, Identifier: Token): StructDeclaration
    local Values: {TypeDeclaration} = {}
    self:Consume("OpenCurlyBrackets")

    while true do
        if self:TryConsume("CloseCurlyBrackets") then
            break
        end

        local Field = self:ConsumeAll("Identifier", "FieldAssign")
        table.insert(Values, self:Type(Field))

        if self:TryConsume("CloseCurlyBrackets") then
            break
        end

        self:Consume("Comma")
    end

    return {
        Type = "Struct",
        Value = {
            Identifier = Identifier.Value,
            Values = Values,
        },
        Tokens = {}
    }
end

function Parser.Primitive(self: Parser, Identifier: Token): PrimitiveDeclaration
    local Token = self:Consume("Primitive")

    local Class: string?;
    local Value = Token.Value
    local Primitive = PRIMITIVES[Value]

    if Value == "Instance" then
        local ClassToken = self:TryConsume("Class")
        Class = if ClassToken then string.sub(ClassToken.Value, 2, #ClassToken.Value - 1) else "Instance"
    end

    return {
        Type = "Primitive",
        Value = {
            Identifier = Identifier.Value,
            Class = Class,
            Primitive = Primitive
        },
        Tokens = {
            Primitive = Token
        }
    }
end

function Parser.Reference(self: Parser, Identifier: Token): ReferenceDeclaration
    local Token = self:Consume("Identifier")
    local Reference = self:GetReference("Type", Token)
    if not Reference then
        error(Error.new(Error.AnalyzeUnknownReference, self.Source, `Unknown reference`)
            :Primary(Token, "Unknown reference")
            :Emit())
    end

    return {
        Type = "Reference",
        Value = {
            Identifier = Identifier.Value,
            Declaration = Reference.Declaration :: TypeDeclaration
        },
        Tokens = {}
    }
end

return Parser