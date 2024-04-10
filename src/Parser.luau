--!strict
--!native
--!optimize 2

local Lexer = require("./Lexer")
local Table = require("./Modules/Table")
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

type Generics = {
    Total: number,
    Span: Error.Span,
    Keys: {[number]: string},
    Indices: {[string]: number}
}

export type Scope = {
    Identifier: Token,
    Parent: Scope?,
    Symbols: {
        Types: {[string]: Reference},
        Scopes: {[string]: Scope},
    },
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
    Scope: Scope?,
    Array: Array?,
    Range: NumberRange?,
    Export: boolean?,
    Optional: boolean?,
    Generics: Generics?,
    Parameters: {TypeDeclaration}?,
    Components: {string}?
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
    UseColon: boolean?,
    TypesOutput: string?,
    ClientOutput: string?,
    ServerOutput: string?,
    FutureLibrary: string?,
    PromiseLibrary: string?,
    WriteValidations: boolean?,
    ManualReplication: boolean?,
}

export type Body = Node<"Body", {
    Options: Options,
    Declarations: {Declaration}
}, {}>

type Declarations = "Map" | "Enum" | "TagEnum" | "Tuple" | "Struct" | "Primitive" | "Generic" | "Reference" | "Event" | "Function" | "Scope" 
export type TypeDeclaration = MapDeclaration | EnumDeclaration | TagEnumDeclaration | TupleDeclaration | StructDeclaration | PrimitiveDeclaration | GenericDeclaration | ReferenceDeclaration

export type Declaration = Node<Declarations, {
    Identifier: string,
    [any]: any
}, {
    [any]: any
}>

export type MapDeclaration = Node<"Map", {
    Identifier: string,
    Values: {TypeDeclaration}
} & Attributes, AttributesTokens>

export type EnumDeclaration = Node<"Enum", {
    Identifier: string,
    Values: {string}
} & Attributes, AttributesTokens>

export type TagEnumDeclaration = Node<"TagEnum", {
    Identifier: string,
    Tag: string,
    Values: {StructDeclaration}
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
    Primitive: Token,
} & AttributesTokens>

export type GenericDeclaration = Node<"Generic", {
    Identifier: string,
    Generic: string,
} & Attributes, AttributesTokens>

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
    Scope: Scope,
    Identifier: string,
    Values: {Declaration}
}, {}> 

---- Settings ----

local OPTIONS: {[string]: Lexer.Types} = {
    Casing = "Identifier",
    UseColon = "Boolean",
    TypesOutput = "String",
    ClientOutput = "String",
    ServerOutput = "String",
    FutureLibrary = "String",
    PromiseLibrary = "String",
    WriteValidations = "Boolean",
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

type Bucket = "Types" | "Scopes"

local BUCKETS: {[string]: Bucket} = {
    Type = "Types",
    Event = "Scopes",
    Function = "Scopes",
    Scope = "Scopes"
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

local GENERICS_TYPES = {
    Map = true,
    Struct = true,
    TagEnum = true
}

local EXPORTABLE_TYPES = {
    map = true,
    type = true,
    enum = true,
    struct = true
}

local RESERVED = {
    StepReplication = true
}

local SUPPORTS_GENERICS = {
    map = true,
    enum = true,
    struct = true,
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

    Scope: Scope,
    Generics: Generics?,
}, Parser))

function Parser.new(): Parser
    return setmetatable({
        Source = "",
        Lexer = Lexer.new("Parsing"),
        Scope = nil :: any,
    }, Parser)
end

---- Utility Functions ----

local function GetFileSource(Path: string): string?
    local IsROBLOX = (task ~= nil)
    if IsROBLOX then
        local Parent = game:GetService("ServerStorage")["BLINK_DEFINITION_FILES"]
        local Indices = string.split(Path, ".")
        for _, Index in Indices do
            Parent = Parent:FindFirstChild(Index)
        end

        return (Parent ~= nil and Parent:IsA("StringValue")) and Parent.Value or nil
    end

    local fs = require("@lune/fs")
    local process = require("@lune/process")
    local cwd = process.env.cwd

    if not fs.isFile(`{cwd}/{Path}`) then
        return
    end

    return fs.readFile(`{cwd}/{Path}`)
end

local function IsDeclarationTypeSimiliar(A: Declarations, B: Declarations): boolean
    if A == B then
        return true
    end

    if A == "Enum" or B == "Enum" then
        return (A == "TagEnum" and B == "Enum") 
            or (A == "Enum" and B == "TagEnum")
    end

    return false
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

function Parser.ConsumeAny(self: Parser, ...: Lexer.Types): Token
    local Types = {...}
    for _, Type: Lexer.Types in Types do
        local Token = self:TryConsume(Type)
        if Token then
            return Token
        end
    end

    local Token = self:Peek()
    error(Error.new(Error.ParserUnexpectedToken, self.Source, `Unexpected token`)
        :Primary(Token, `Expected one of "{table.concat(Types, `", "`)}", found "{Token.Type}"`)
    :Emit())
end

function Parser.ConsumeAll(self: Parser, ...: Lexer.Types): (...Token)
    local Tokens = {}
    for _, Type: Lexer.Types in {...} do
        table.insert(Tokens, self:Consume(Type))
    end

    return table.unpack(Tokens)
end

---- Utility Parsing Functions ----

function Parser.GetReference(self: Parser, Bucket: Bucket, Identifier: string): Reference?
    local Path = string.split(Identifier, ".")
    local Scope: Scope? = self.Scope

    local Offset = 1
    local Length = #Path

    while (Scope) do
        local Index = Path[Offset]
        if not Index then
            break
        end

        local Symbols = Scope.Symbols
        local Symbol = 
            if (Offset == Length) 
            then Symbols[Bucket][Index] 
            else Symbols.Scopes[Index]

        --> Nothing found in the current scope search upwards
        if Symbol == nil then
            Scope = Scope.Parent
            continue
        end

        --> We found a scope, start searching in it
        if Symbol and Offset < Length then
            Offset += 1
            Scope = Symbol :: any
            continue
        end

        --> Found the reference
        return Symbol :: Reference
    end

    return nil
end

function Parser.SetReference(self: Parser, Bucket: Bucket, Identifier: Token, Declaration: Declaration)
    local Name = Identifier.Value

    if RESERVED[Name] then
        Error.new(Error.AnalyzeReservedIdentifier, self.Source, `Reserved identifier`)
            :Primary(Identifier, `"{Name}" is reserved and cannot be used as an identifier.`)
            :Emit()
    end

    self.Scope.Symbols[Bucket][Name] = {
        Identifier = Identifier,
        Declaration = Declaration
    }
end

function Parser.GetGenerics(self: Parser): Generics?
    if self.Generics then
        return self.Generics
    end

    local OpenChevrons = self:TryConsume("OpenChevrons")
    if not OpenChevrons then
        return
    end

    --> Parse generics
    local Generics: Generics = {
        Total = 0,
        Span = {
            Start = OpenChevrons.Start,
            End = OpenChevrons.End + 1
        },
        Keys = {},
        Indices = {}
    }

    while true do
        if self:TryConsume("CloseChevrons") then
            break
        end

        local Index = (Generics.Total + 1)
        local Token = self:Consume("Identifier")
        local Identifier = Token.Value
        
        Generics.Total = Index
        Generics.Span.End += (Token.End - Token.Start)
        Generics.Keys[Index] = Identifier
        Generics.Indices[Identifier] = Index

        if self:Peek().Type ~= "CloseChevrons" then
            self:Consume("Comma")
        end
    end

    self.Generics = Generics
    return Generics
end

function Parser.SolveGenerics(self: Parser, Identifier: Token, Declaration: StructDeclaration)
    local Generics = Declaration.Value.Generics
    if not Generics then
        return
    end

    local OpenToken = self:TryConsume("OpenChevrons")
    if not OpenToken then
        Error.new(Error.AnalyzeInvalidGenerics, self.Source, `Type expects parameters list`)
            :Primary(self:Peek(), "")
        :Emit()

        return
    end

    local Maximum = Generics.Total
    local Parameters = {}
    local References: {[string]: TypeDeclaration} = {}

    for Index, Generic in Generics.Keys do
        local Type = self:Type(Identifier)
        References[Generic] = Type
        table.insert(Parameters, Type)
        
        if Index ~= Maximum then
            self:Consume("Comma")
        end
    end

    local CloseToken = self:Consume("CloseChevrons")
    if #Parameters ~= Maximum then
        Error.new(Error.AnalyzeInvalidGenerics, self.Source, `Type expects {Maximum} parameters, but {#Parameters} are specified`)
            :Primary({Start = OpenToken.Start, End = CloseToken.End}, "")
        :Emit()
    end

    --> Solve references
    Declaration = Table.DeepClone(Declaration)

    local function SolveValues(Values: {TypeDeclaration})
        for Index, Field in Values do
            if GENERICS_TYPES[Field.Type] then
                local Value = (Field :: StructDeclaration).Value
                SolveValues(Value.Values)
                continue
            end

            if Field.Type ~= "Generic" then
                continue
            end

            local Value = Field.Value
            local Generic = Value.Generic

            --> Create a unique reference for each generic
            local Reference = References[Generic]
            Reference = Table.DeepClone(Reference)
            ;(Reference :: Declaration).Value.Identifier = Value.Identifier
            
            --> Set value to reference
            Values[Index] = Reference
        end
    end

    Declaration.Value.Generics = nil
    SolveValues(Declaration.Value.Values)

    return Declaration, Parameters
end

function Parser.GetTypeAttributes(self: Parser, Primitive: Settings.Primitive?): (Attributes, AttributesTokens)
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
        :Emit())
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
        :Emit())
    end

    local function TryToParseComponents(): {string}?
        if not Primitive then
            return
        end

        local OpenChevrons = self:TryConsume("OpenChevrons")
        if not OpenChevrons then
            return
        end

        if Primitive.AllowedComponents == 0 then
            error(Error.new(Error.AnalyzeInvalidRange, self.Source, `Type doesn't accept components`)
                :Primary(OpenChevrons, `Remove component here`)
            :Emit())
        end

        local Components = {}
        local Primitives = {}

        for Index = 1, Primitive.AllowedComponents do
            table.insert(Primitives, self:Consume("Primitive"))
            if self:TryConsume("CloseChevrons") then
                break
            end

            self:Consume("Comma")
        end

        for Index, Token in Primitives do
            local Component = Token.Value
            local ComponentPrimitive = PRIMITIVES[Component]

            if not ComponentPrimitive then
                error(Error.new(Error.AnalyzeInvalidRange, self.Source, `Unknown primitive used as component`)
                    :Primary(Token, `"{Component}" is invalid`)
                :Emit())
            end

            if not ComponentPrimitive.Component then
                error(Error.new(Error.AnalyzeInvalidRange, self.Source, `Invalid primitive used as component`)
                    :Primary(Token, `"{Component}" cannot be used as a component`)
                :Emit())
            end

            table.insert(Components, Component)
        end

        return Components
    end

    local Range, RangeToken = TryToParseRange()
    local Components = TryToParseComponents()
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

    return {
        Range = Range,
        Array = Array,
        Optional = Optional,
        Components = Components
    }, {
        Range = RangeToken,
        Array = ArrayToken,
        Optional = OptionalToken,
    }
end


---- Top-Level Parsing Functions ----

function Parser.Parse(self: Parser, Source: string, Scope: Token?): Body
    --> Set state
    self.Scope = {Identifier = Scope or {Value = "", Start = 0, End = 0} :: any, Symbols = {Types = {}, Scopes = {}}}
    self.Source = Source
    
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

function Parser.Import(self: Parser): ScopeDeclaration
    self:Consume("Import")

    local Path = self:Consume("String")
    local ImportPath = Path.Value
    local ImportSource = GetFileSource(ImportPath)

    if not ImportSource then
        error(Error.new(Error.AnalyzeUnknownImport, self.Source, `Unknown require`)
            :Primary(Path, `Unknown require: "{ImportPath}"`)
        :Emit())
    end

    --> Import namespace
    local Token = Path
    local Identifier: string;

    if self:TryConsume("As") then
        --> Use user provided namespace identifier
        Token = self:Consume("Identifier")
        Identifier = Token.Value 
    elseif (task ~= nil) then
        --> ROBLOX
        local Indices = string.split(ImportPath, ".")
        Identifier = Indices[#Indices]
    else
        --> Use file name as namespace identifier
        local Directory, Filename, Extension = string.match(ImportPath, "^([%.%w_/]*)/([%w_]+)%.(%w+)")
        assert(Filename, "Unable to parse file path for filename!")
        Identifier = Filename
        Token.Value = Filename
    end

    local Reference = self:GetReference("Scopes", Identifier)
    if Reference then
        Error.new(Error.AnalyzeDuplicateDeclaration, self.Source, `Duplicate declaration: "{Identifier}"`)
            :Secondary(Reference.Identifier, "Previously declared here")
            :Primary(Token, "Duplicate declared here")
        :Emit()
    end

    --> Parse import into AST
    local AST: Body;
    local ImportParser = Parser.new()
    local Success, ErrorText = pcall(function()
        AST = ImportParser:Parse(ImportSource, Token)
    end)

    if not Success then
        error(`Error while parsing "{ImportPath}":\n{ErrorText}`)
    end

    --> Import
    print(`Importing {ImportPath} as {Identifier}`)

    local Parent = self.Scope
    local Scope: Scope = {
        Identifier = Token,
        Parent = Parent,
        Symbols = {
            Types = {},
            Scopes = {}
        }
    }

    Parent.Symbols.Scopes[Identifier] = Scope
    
    return {
        Type = "Scope",
        Value = {
            Scope = Scope,
            Identifier = Identifier,
            Values = AST.Value.Declarations
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

        if self.Scope and self:TryConsume("CloseBraces") then
            break
        end

        --> Is an import?
        local LookAhead = self:Peek()
        if LookAhead.Type == "Import" then
            table.insert(Declarations, self:Import())
            continue
        end

        --> Is standalone/exported?
        local Export: Token?
        if LookAhead.Type == "Keyword" and LookAhead.Value == "export" then
            Export = self:Consume("Keyword")
        end

        local Keyword = self:Consume("Keyword")
        local Identifier = self:Consume("Identifier")
        local Declaration: Declaration;

        --> Prevent duplicates
        local Type = KEYWORDS[Keyword.Value]
        local Bucket: Bucket = BUCKETS[Type]
        local Reference = self:GetReference(Bucket, Identifier.Value)

        if Reference then
            Error.new(Error.AnalyzeDuplicateDeclaration, self.Source, `Duplicate declaration`)
                :Secondary(Reference.Identifier, "Previously declared here")
                :Primary(Identifier, "Duplicate declared here")
            :Emit()
        end

        --> Generics
        local Generics: Generics?;
        if SUPPORTS_GENERICS[Keyword.Value] then
            Generics = self:GetGenerics()
        end

        --> Parse declaration
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

        --> Update declarations
        table.insert(Declarations, Declaration :: any)

        if Export then
            --> Prevent non exportable types from being exported
            if not EXPORTABLE_TYPES[Keyword.Value] then
                Error.new(Error.AnalyzeInvalidExport, self.Source, `Declaration of type "{Keyword.Value}" is not exportable`)
                    :Primary(Export, `Remove export here`)
                :Emit()
            --> Prevent types with generics from being exported
            elseif Generics then
                Error.new(Error.AnalyzeInvalidExport, self.Source, `Generic types can't be exported`)
                    :Primary(Export, `Remove export here`)
                :Emit()
            end

            Declaration.Value.Export = true
        end

        if Generics then
            if Declaration.Type == "Enum" then
                Error.new(Error.AnalyzeInvalidGenerics, self.Source, `Unit enums don't support generics`)
                    :Primary(Generics.Span, "Remove generics")
                :Emit()
            end

            self.Generics = nil
            Declaration.Value.Generics = Generics
        end

        if Type ~= "Scope" then
            self:SetReference(Bucket, Identifier, Declaration)
        end
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
        OptionsString ..= `{Index ~= 1 and " or " or ""}"{Option.Key}"`
    end

    error(Error.new(Error.ParserUnknownOption, self.Source, `Unknown option "{Value}"`)
        :Primary(Token, `Expected one of {OptionsString}`)
    :Emit())
end

function Parser.Structure(self: Parser, Identifier: Token, Structure: {EventOption}): {[string]: any}
    local Fields: {[string]: any} = {}
    for Index = 1, #Structure do
        --> Identifier or Keyword ("type" might be used as a field which will be lexed as "Keyword")
        local Field = self:ConsumeAny("Identifier", "Keyword")
        self:Consume("FieldAssign")

        --> Parse non data field
        local Value: any;
        local Option = self:GetOptionFromToken(Field, Structure)

        if Option.Key ~= "Data" and Option.Key ~= "Return" then
            local Token = self:Consume(Option.Type)
            Value = Token.Value

            if not table.find(Option.Values, Value) then
                Error.new(Error.ParserUnknownOption, self.Source, `Unknown option "{Value}"`)
                    :Primary(Token, `Expected one of "{table.concat(Option.Values, `" or "`)}"`)
                :Emit()
            end
        else
            Value = self:Type(Identifier, nil, true)
        end

        Fields[Option.Key] = Value
        if self:Peek().Type ~= "CloseBraces" then
            self:Consume("Comma")
        end
    end

    return Fields
end

function Parser.Event(self: Parser, Identifier: Token): EventDeclaration
    self:Consume("OpenBraces")
    local Structure = self:Structure(Identifier, EVENT)
    self:Consume("CloseBraces")

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
    self:Consume("OpenBraces")
    local Structure = self:Structure(Identifier, FUNCTION)
    self:Consume("CloseBraces")

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
    --[[if self.Scope then
        Error.new(Error.AnalyzeNestedScope, self.Source, "You cannot declare a scope within a scope")
            :Primary(Identifier, `Nested scope declared`)
            :Emit()
    end]]

    self:Consume("OpenBraces")

    --> Open scope
    local Parent = self.Scope
    local Scope: Scope = {
        Identifier = Identifier,
        Parent = Parent,
        Symbols = {
            Types = {},
            Scopes = {}
        }
    }

    self.Scope = Scope
    Parent.Symbols.Scopes[Identifier.Value] = Scope

    --> Gather declarations
    local Declarations = self:Declarations()

    --> Close scope
    self.Scope = Parent

    return {
        Type = "Scope",
        Value = {
            Scope = Scope,
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
                if not IsDeclarationTypeSimiliar(Reference.Type, Type) then
                    Error.new(Error.AnalyzeReferenceInvalidType, self.Source, `Cannot cast "{Reference.Type}" to "{Type}"`)
                        :Primary(Token, `Expected a reference to "{Type}", got "{Reference.Type}" instead`)
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
        
        if Type == "Keyword" then
            local Value = Peek.Value
            self:Consume("Keyword")

            if Value == "map" then
                Declaration = self:Map(Identifier)
            elseif Value == "enum" then
                Declaration = self:Enum(Identifier)
            elseif Value == "struct" then
                Declaration = self:Struct(Identifier)
            end
        elseif Type == "Primitive" then
            Declaration = self:Primitive(Identifier)
        elseif Type == "Identifier" then
            Declaration = self:Reference(Identifier)
        elseif Type == "OpenParentheses" and IsDataField then
            Declaration = self:Tuple(Identifier)
        end

        if not Declaration then
            Error.new(Error.ParserUnexpectedToken, self.Source, `Unexpected token`)
                :Primary(Peek, `Expected one of "Identifier" or "Primitive" or "Keyword", got "{Type}" instead`)
            :Emit()
        end
    end

    --> Solve generics
    if Declaration.Type == "Reference" then
        local Value = Declaration.Value
        local Referencing = Value.Declaration
        if Referencing.Value.Generics then
            Value.Declaration, Value.Parameters = self:SolveGenerics(Identifier, Referencing :: StructDeclaration)
        end
    end

    --> Set type attributes
    local Primitive: Settings.Primitive?;
    if Declaration.Type == "Primitive" then
        Primitive = (Declaration :: PrimitiveDeclaration).Value.Primitive
    end

    local Value = Declaration.Value :: Attributes
    local Tokens = Declaration.Tokens :: AttributesTokens
    local Attributes, AttributesTokens = self:GetTypeAttributes(Primitive)

    Value.Range, Value.Optional, Value.Array, Value.Components = Attributes.Range, Attributes.Optional, Attributes.Array, Attributes.Components
    Tokens.Range, Tokens.Optional, Tokens.Array = AttributesTokens.Range, AttributesTokens.Optional, AttributesTokens.Array

    return Declaration
end

function Parser.Map(self: Parser, Identifier: Token): MapDeclaration
    self:ConsumeAll("OpenBraces", "OpenBrackets")

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
    self:Consume("CloseBrackets")
    self:Consume("FieldAssign")

    local Value = ParseElement()
    self:Consume("CloseBraces")

    return {
        Type = "Map",
        Value = {
            Identifier = Identifier.Value,
            Values = {Key, Value}
        },
        Tokens = {}
    }
end

function Parser.Enum(self: Parser, Identifier: Token): EnumDeclaration | TagEnumDeclaration
    local Values: {string} = {}

    --> Is it a tagged enum?
    local Tag = self:TryConsume("String")
    if Tag then
        return self:TagEnum(Tag, Identifier)
    end

    self:Consume("OpenBraces")

    while true do
        if self:TryConsume("CloseBraces") then
            break
        end

        local Token = self:Consume("Identifier")
        table.insert(Values, Token.Value)

        if self:TryConsume("CloseBraces") then
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
    } :: EnumDeclaration
end

function Parser.TagEnum(self: Parser, Tag: Token, Identifier: Token): TagEnumDeclaration
    local Values: {StructDeclaration} = {}
    self:Consume("OpenBraces")

    while true do
        if self:TryConsume("CloseBraces") then
            break
        end

        local Token = self:Consume("Identifier")
        local Struct = self:Struct(Token)
        local Fields = Struct.Value.Values

        --> Don't allow tag field to be set
        for _, Field: TypeDeclaration in Fields do
            if Field.Value.Identifier == Tag.Value then
                Error.new(Error.AnalyzeReservedIdentifier, self.Source, `Enum tag used as field in variant`)
                    :Secondary(Token, `Used in variant`)
                    :Primary(Tag, `Enum tag`)
                :Emit()
            end
        end

        table.insert(Values, Struct)

        if self:TryConsume("CloseBraces") then
            break
        end

        self:Consume("Comma")
    end

    return {
        Type = "TagEnum",
        Value = {
            Identifier = Identifier.Value,
            Tag = Tag.Value,
            Values = Values
        },
        Tokens = {}
    }
end

function Parser.Tuple(self: Parser, Identifier: Token): TupleDeclaration
    local Values: {TypeDeclaration} = {}
    self:Consume("OpenParentheses")

    while true do
        if self:TryConsume("CloseParentheses") then
            break
        end

        local Value = self:Type(Identifier)
        table.insert(Values, Value)

        if self:TryConsume("CloseParentheses") then
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
    self:Consume("OpenBraces")

    while true do
        if self:TryConsume("CloseBraces") then
            break
        end

        local Field = self:ConsumeAll("Identifier", "FieldAssign")
        table.insert(Values, self:Type(Field))

        if self:TryConsume("CloseBraces") then
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

function Parser.Reference(self: Parser, Identifier: Token): (ReferenceDeclaration | GenericDeclaration)
    local Token = self:Consume("Identifier")

    --> Generics reference resolution
    local Generics = self.Generics
    local Generic = Generics and Generics.Indices[Token.Value]

    if Generic then
        return {
            Type = "Generic",
            Value = {
                Identifier = Identifier.Value,
                Generic = Token.Value
            },
            Tokens = {}
        } :: GenericDeclaration
    end

    --> Normal reference resolution
    local Reference = self:GetReference("Types", Token.Value)
    if not Reference then
        error(Error.new(Error.AnalyzeUnknownReference, self.Source, `Unknown reference`)
            :Primary(Token, "Unknown reference")
        :Emit())
    end

    return {
        Type = "Reference",
        Value = {
            Identifier = Identifier.Value,
            Declaration = Reference.Declaration
        },
        Tokens = {}
    } :: ReferenceDeclaration
end

return Parser