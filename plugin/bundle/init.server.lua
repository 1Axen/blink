local __DARKLUA_BUNDLE_MODULES

__DARKLUA_BUNDLE_MODULES = {
    cache = {},
    load = function(m)
        if not __DARKLUA_BUNDLE_MODULES.cache[m] then
            __DARKLUA_BUNDLE_MODULES.cache[m] = {
                c = __DARKLUA_BUNDLE_MODULES[m](),
            }
        end

        return __DARKLUA_BUNDLE_MODULES.cache[m].c
    end,
}

do
    function __DARKLUA_BUNDLE_MODULES.a()
        local State = {}

        State.__index = State

        function State.new(Value)
            return setmetatable({
                Value = Value,
                Observers = {},
            }, State)
        end
        function State.Get(self)
            return self.Value
        end
        function State.Set(self, Value)
            if self.Value ~= Value or type(Value) == 'table' then
                self.Value = Value

                self:_updateObservers()
            end
        end
        function State.OnChange(self, Observer)
            self.Observers[Observer] = true

            task.defer(function()
                self:_updateObservers()
            end)

            return function()
                self.Observers[Observer] = nil
            end
        end
        function State._updateObservers(self)
            for Observer in self.Observers do
                task.spawn(Observer, self.Value)
            end
        end

        return State
    end
    function __DARKLUA_BUNDLE_MODULES.b()
        local Table = {}

        function Table.MergeArrays(a, b)
            local Array = table.create(#a + #b)

            for _, Element in a do
                table.insert(Array, Element)
            end
            for _, Element in b do
                table.insert(Array, Element)
            end

            return Array
        end
        function Table.MergeDictionaries(a, b)
            local Dictionary = table.clone(a)

            for Key, Value in b do
                if Dictionary[Key] then
                    warn(`Key "{Key}" already exists in the first dictionary.`)

                    continue
                end

                Dictionary[Key] = Value
            end

            return Dictionary
        end
        function Table.GetDictionaryKeys(Dictionary)
            local Keys = {}

            for Key in Dictionary do
                table.insert(Keys, Key)
            end

            return Keys
        end

        return Table
    end
    function __DARKLUA_BUNDLE_MODULES.c()
        local stdio

        if not true then
            stdio = require('@lune/stdio')
        end

        local SPACE = ' '
        local INDENT = '    '
        local IS_ROBLOX = (game ~= nil)
        local INVISIBLE_SPACE = `<font transparency="1">0</font>`

        if IS_ROBLOX then
            SPACE = INVISIBLE_SPACE
            INDENT = string.rep(INVISIBLE_SPACE, #INDENT)
        end

        local Colors = {
            black = 'rgb(0, 0, 0)',
            blue = 'rgb(0, 0, 255)',
            cyan = 'rgb(0, 255, 255)',
            green = 'rgb(0, 255, 0)',
            purple = 'rgb(163, 44, 196)',
            red = 'rgb(255, 0, 0)',
            white = 'rgb(255, 255, 255)',
            yellow = 'rgb(255, 255, 0)',
        }
        local Error = {
            OnEmit = nil,
            LexerUnexpectedToken = 1001,
            ParserUnexpectedEndOfFile = 2001,
            ParserUnexpectedToken = 2002,
            ParserUnknownOption = 2003,
            ParserUnexpectedSymbol = 2004,
            ParserExpectedExtraToken = 2005,
            AnalyzePrimitiveReferencesNonPrimitive = 3001,
            AnalyzeInvalidOptionalType = 3002,
            AnalyzeNestedMap = 3003,
            AnalyzeDuplicateField = 3004,
            AnalyzeReservedIdentifier = 3005,
            AnalyzeNestedScope = 3006,
            AnalyzeUnknownReference = 3007,
            AnalyzeInvalidRangeType = 3008,
            AnalyzeInvalidRange = 3009,
            AnalyzeDuplicateDeclaration = 3010,
        }

        Error.__index = Error

        local function Fix(Text)
            if IS_ROBLOX then
                Text = string.gsub(Text, '%s', INVISIBLE_SPACE)
            end

            return Text
        end
        local function Color(Text, Color)
            if true then
                return `<font color="{Colors[Color]}">{Text}</font>`
            end

            return `{stdio.color(Color)}{Text}{stdio.color('reset')}`
        end

        function Error.new(Code, Source, Message)
            local Content = `{Color(`error[{Code}]`, 'red')}:{SPACE}{Fix(Message)}`

            Content ..= `\n{INDENT}\u{250c}\u{2500}{SPACE}input.blink`

            return setmetatable({
                Labels = {},
                Source = string.split(Source, '\n'),
                Message = Content,
            }, Error)
        end
        function Error.Slice(self, Span)
            local Cursor = 1

            for Line, Text in self.Source do
                local Start = Cursor
                local Length = #Text

                Cursor += (Length + 1)

                if Span.End >= Cursor then
                    continue
                end

                local Spaces = (Span.Start - Start)
                local Underlines = math.max(1, Span.End - Span.Start)

                return {
                    Line = Line,
                    Text = Fix(Text),
                    Spaces = Spaces,
                    Underlines = Underlines,
                }
            end

            error('Unable to find span bounds.')
        end
        function Error.Primary(self, Span, Text)
            local Slice = self:Slice(Span)

            table.insert(self.Labels, {
                Span = Span,
                Text = Text,
                Type = 'Primary',
            })

            self.Message ..= `\n{Color(string.format('%03i', Slice.Line), 'blue')}{SPACE}\u{2502}{SPACE}{Slice.Text}`
            self.Message ..= `\n{INDENT}\u{2502}{SPACE}{string.rep(SPACE, Slice.Spaces)}{Color(`{string.rep('^', Slice.Underlines)}{SPACE}{Fix(Text)}`, 'red')}`

            return self
        end
        function Error.Secondary(self, Span, Text)
            local Slice = self:Slice(Span)

            table.insert(self.Labels, {
                Span = Span,
                Text = Text,
                Type = 'Secondary',
            })

            self.Message ..= `\n{Color(string.format('%03i', Slice.Line), 'blue')}{SPACE}\u{2502}{SPACE}{Slice.Text}`
            self.Message ..= `\n{INDENT}\u{2502}{SPACE}{string.rep(SPACE, Slice.Spaces)}{Color(`{string.rep('^', Slice.Underlines)}{SPACE}{Fix(Text)}`, 'blue')}`

            return self
        end
        function Error.Emit(self)
            local OnEmit = Error.OnEmit

            if OnEmit then
                OnEmit(self.Labels)
            end

            error(self.Message, 2)
        end

        return Error
    end
    function __DARKLUA_BUNDLE_MODULES.d()
        return {
            Keywords = {
                map = true,
                type = true,
                enum = true,
                struct = true,
                event = true,
                ['function'] = true,
                scope = true,
                option = true,
            },
            Primtives = {
                u8 = true,
                u16 = true,
                u32 = true,
                i8 = true,
                i16 = true,
                i32 = true,
                f16 = true,
                f32 = true,
                f64 = true,
                boolean = true,
                string = true,
                vector = true,
                buffer = true,
                Color3 = true,
                CFrame = true,
                Instance = true,
            },
        }
    end
    function __DARKLUA_BUNDLE_MODULES.e()
        local Error = __DARKLUA_BUNDLE_MODULES.load('c')
        local Settings = __DARKLUA_BUNDLE_MODULES.load('d')
        local Primitives = Settings.Primtives
        local Keywords = Settings.Keywords
        local Booleans = {
            ['true'] = true,
            ['false'] = true,
        }
        local Number = '[%+%-]?%d+'
        local Matches = {
            {
                '^%s+',
                'Whitespace',
            },
            {
                '^=',
                'Assign',
            },
            {
                '^{',
                'OpenCurlyBrackets',
            },
            {
                '^}',
                'CloseCurlyBrackets',
            },
            {
                '^,',
                'Comma',
            },
            {
                '^?',
                'Optional',
            },
            {
                `^%(%a+%)`,
                'Class',
            },
            {
                `^%({Number}%)`,
                'Range',
            },
            {
                `^%({Number}..{Number}%)`,
                'Range',
            },
            {
                `^%[{Number}]`,
                'Array',
            },
            {
                `^%[{Number}..{Number}]`,
                'Array',
            },
            {
                '^%(',
                'OpenBrackets',
            },
            {
                '^%)',
                'CloseBrackets',
            },
            {
                '^%[',
                'OpenSquareBrackets',
            },
            {
                '^%]',
                'CloseSquareBrackets',
            },
            {
                '^([\'"]).-[^\\](\\*)%2%1',
                function(Token)
                    return 'String', string.sub(Token, 2, #Token - 1)
                end,
            },
            {
                '^%a+%.%a+',
                'Identifier',
            },
            {
                '^[%a_][%w_]*',
                function(Token)
                    if Keywords[Token] then
                        return 'Keyword', Token
                    elseif Primitives[Token] then
                        return 'Primitive', Token
                    elseif Booleans[Token] then
                        return 'Boolean', (Token == 'true')
                    end

                    return 'Identifier', Token
                end,
            },
        }
        local Lexer = {}

        Lexer.__index = Lexer

        function Lexer.new(Mode)
            local Mode = Mode or 'Parsing'

            return setmetatable({
                Size = 0,
                Mode = Mode,
                Source = '',
                Cursor = 1,
            }, Lexer)
        end
        function Lexer.Initialize(self, Source)
            self.Size = #Source
            self.Source = Source
            self.Cursor = 1
        end
        function Lexer.GetNextToken(self, DontAdvanceCursor)
            if self.Cursor > self.Size then
                return
            end

            local Slice = string.sub(self.Source, self.Cursor)
            local IsHighlighting = (self.Mode == 'Highlighting')

            local function Match(Pattern)
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
                local Type = Token[2]
                local Matched, Start, End = Match(Pattern)

                if not Matched then
                    continue
                end
                if (DontAdvanceCursor ~= true or Type == 'Whitespace') then
                    self.Cursor += #Matched
                end
                if (Type == 'Whitespace') and not IsHighlighting then
                    return self:GetNextToken(DontAdvanceCursor)
                end
                if type(Type) == 'function' then
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
                Error.new(Error.LexerUnexpectedToken, self.Source, 'Unexpected token'):Primary({
                    Start = self.Cursor,
                    End = self.Cursor,
                }, `Unexpected token`):Emit()
            else
                local Cursor = self.Cursor
                local Symbol = string.sub(self.Source, Cursor, Cursor)

                self.Cursor += 1

                return {
                    Type = 'Unknown',
                    Value = Symbol,
                    Start = Cursor,
                    End = Cursor,
                }
            end

            return
        end

        return Lexer
    end
    function __DARKLUA_BUNDLE_MODULES.f()
        return {
            DeepClone = function(Table)
                local function Clone(Source)
                    local Result = {}

                    for Index, Value in Source do
                        if type(Value) == 'table' then
                            Result[Index] = Clone(Value)
                        else
                            Result[Index] = Value
                        end
                    end

                    return Result
                end

                return Clone(Table)
            end,
        }
    end
    function __DARKLUA_BUNDLE_MODULES.g()
        local Lexer = __DARKLUA_BUNDLE_MODULES.load('e')
        local Error = __DARKLUA_BUNDLE_MODULES.load('c')
        local Table = __DARKLUA_BUNDLE_MODULES.load('f')
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
        local OptionsTypes = {
            ClientOutput = 'String',
            ServerOutput = 'String',
            FutureLibrary = 'String',
            PromiseLibrary = 'String',
            ManualReplication = 'Boolean',
        }
        local ReservedMembers = {StepReplication = true}
        local KeywordTypes = {
            map = 'Types',
            type = 'Types',
            enum = 'Types',
            struct = 'Types',
            scope = 'Events',
            event = 'Events',
            ['function'] = 'Events',
        }
        local EventStructure = {
            {
                Key = 'From',
                Type = 'Identifier',
                Values = {
                    'Client',
                    'Server',
                },
            },
            {
                Key = 'Type',
                Type = 'Identifier',
                Values = {
                    'Reliable',
                    'Unreliable',
                },
            },
            {
                Key = 'Call',
                Type = 'Identifier',
                Values = {
                    'SingleSync',
                    'ManySync',
                    'SingleAsync',
                    'ManyAsync',
                },
            },
            {
                Key = 'Data',
                Type = 'Identifier',
                Values = {},
            },
        }
        local FunctionStructure = {
            {
                Key = 'Yield',
                Type = 'Identifier',
                Values = {
                    'Future',
                    'Promise',
                    'Coroutine',
                },
            },
            {
                Key = 'Data',
                Type = 'Identifier',
                Values = {},
            },
            {
                Key = 'Return',
                Type = 'Identifier',
                Values = {},
            },
        }
        local Number = '[%+%-]?%d+'
        local NumberRange = {
            new = function(Min, Max)
                return {
                    Min = Min,
                    Max = Max or Min,
                }
            end,
        }

        local function GetTypeRange(Token, Array, Source)
            local Value = Token.Value

            local function ThrowMalformedRange()
                Error.new(Error.AnalyzeInvalidRange, Source, 'Malformed range'):Primary(Token, 'Unable to parse range'):Emit()
                error('Unable to parse range')
            end

            local Single = Array and string.match(Value, '%[(%d+)%]') or string.match(Value, '%((%d+)%)')

            if Single then
                local Number = (tonumber(Single))

                if not Number then
                    ThrowMalformedRange()
                end
                if Array and Number < 0 then
                    Error.new(Error.AnalyzeInvalidRange, Source, 'Invalid array size'):Primary(Token, 'Array cannot be smaller than 0 elements'):Emit()
                end

                return NumberRange.new(Number, Number)
            end

            local Lower = Array and string.match(Value, '%[(%d+)') or string.match(Value, '%((%d+)')
            local Upper = Array and string.match(Value, '(%d+)%]') or string.match(Value, '(%d+)%)')

            if Lower and Upper then
                local Minimum = (tonumber(Lower))
                local Maximum = (tonumber(Upper))

                if not Minimum or not Maximum then
                    ThrowMalformedRange()
                end
                if Minimum >= Maximum then
                    Error.new(Error.AnalyzeInvalidRange, Source, 'Invalid range'):Primary(Token, 'Maximum must be greater than minimum'):Emit()
                end

                return NumberRange.new(Minimum, Maximum)
            end

            ThrowMalformedRange()

            return NumberRange.new(0, 0)
        end

        local Parser = {}

        Parser.__index = Parser

        function Parser.new()
            return setmetatable({
                Source = '',
                Types = {},
                Scopes = {},
                Events = {},
                Lexer = Lexer.new(),
            }, Parser)
        end
        function Parser.Parse(self, Source)
            self.Scope = nil
            self.Source = Source

            table.clear(self.Types)
            self.Lexer:Initialize(Source)

            self.LookAhead = self.Lexer:GetNextToken()

            local Options = self:Options()
            local Body = self:Body()

            return Body, Options
        end
        function Parser.Consume(self, Type)
            local Token = self.LookAhead

            if not Token then
                Error.new(Error.ParserUnexpectedEndOfFile, self.Source, 'Unexpected end of file'):Primary({
                    Start = #self.Source,
                    End = #self.Source,
                }, 'File ends here'):Emit()
                error('Unexpected end of file')
            end
            if Token.Type ~= Type then
                Error.new(Error.ParserUnexpectedToken, self.Source, `Unexpected token`):Primary(Token, `Expected "{Type}", found "{Token.Type}"`):Emit()
            end

            self.LookAhead = self.Lexer:GetNextToken()

            return Token
        end
        function Parser.ConsumeAny(self, Types)
            local Token = self.LookAhead

            if not Token then
                Error.new(Error.ParserUnexpectedEndOfFile, self.Source, 'Unexpected end of file'):Primary({
                    Start = #self.Source,
                    End = #self.Source,
                }, 'File ends here'):Emit()
                error('Unexpected end of file')
            end
            if not table.find(Types, Token.Type) then
                Error.new(Error.ParserUnexpectedToken, self.Source, `Unexpected token`):Primary(Token, `Expected one of "{table.concat(Types, '", ')}", found "{Token.Type}"`):Emit()
            end

            self.LookAhead = self.Lexer:GetNextToken()

            return Token
        end
        function Parser.GetSafeLookAhead(self)
            if self.LookAhead then
                return self.LookAhead
            end

            return {
                Type = 'Unknown',
                Value = '\0',
                Start = #self.Source + 1,
                End = #self.Source + 1,
            }
        end
        function Parser.Body(self)
            return {
                Type = 'Body',
                Value = self:Declarations(),
                Tokens = {},
            }
        end
        function Parser.Options(self)
            local Options = {}

            local function ParseOption()
                local LookAhead = self:GetSafeLookAhead()

                if LookAhead.Value ~= 'option' then
                    return
                end

                self:Consume('Keyword')

                local Key = self:Consume('Identifier')

                self:Consume('Assign')

                local Type = OptionsTypes[Key.Value]

                if not Type then
                    Error.new(Error.ParserUnknownOption, self.Source, `Unknown option "{Key.Value}"`):Primary(Key, `Expected one of "ClientOutput" or "ServerOutput" or "ManualReplicationLoop", found "{Key.Value}"`):Emit()

                    return
                end

                local Value = self:Consume(Type)

                Options[Key.Value] = Value.Value

                ParseOption()
            end

            ParseOption()

            return Options
        end
        function Parser.Declarations(self)
            local Declarations = {
                self:Declaration(),
            }

            while(self.LookAhead) do
                table.insert(Declarations, self:Declaration())
            end

            return Declarations
        end
        function Parser.Declaration(self)
            local Keyword = self:Consume('Keyword')
            local Identifier = self:Consume('Identifier')

            self:Consume('Assign')

            local Type = KeywordTypes[Keyword.Value]
            local Duplicates = self[Type]
            local ScopedIdentifier = `{self.Scope and `{self.Scope}.` or ''}{Identifier.Value}`
            local Duplicate = Duplicates[ScopedIdentifier]

            if Duplicate then
                Error.new(Error.AnalyzeDuplicateDeclaration, self.Source, `Duplicate {Keyword.Value} "{Identifier.Value}"`):Secondary(Duplicate.Identifier, 'Previously delcared here'):Primary(Identifier, 'Duplicate declaration here'):Emit()
            end

            local Declaration

            if Keyword.Value == 'map' then
                Declaration = self:MapDeclaration(Identifier)
            elseif Keyword.Value == 'type' then
                Declaration = self:TypeDeclaration(Identifier)
            elseif Keyword.Value == 'enum' then
                Declaration = self:EnumDeclaration(Identifier)
            elseif Keyword.Value == 'struct' then
                Declaration = self:StructDeclaration(Identifier)
            elseif Keyword.Value == 'event' then
                Declaration = self:EventDeclaration(Identifier)
            elseif Keyword.Value == 'function' then
                Declaration = self:FunctionDeclaration(Identifier)
            elseif Keyword.Value == 'scope' then
                Declaration = self:ScopeDeclaration(Identifier)
            end
            if not Declaration then
                error(`{Keyword.Value} has no declaration handler.`)
            end
            if Duplicates == self.Types and (self:GetSafeLookAhead().Type == 'Optional') then
                Declaration.Value.Optional = true
                Declaration.Tokens.Optional = self:Consume('Optional')
            end

            Duplicates[ScopedIdentifier] = {
                Type = Type,
                Identifier = Identifier,
                Declaration = Declaration,
            }

            return Declaration
        end
        function Parser.TypeDeclaration(self, Identifier)
            local LookAhead = self:GetSafeLookAhead()
            local Primitive
            local Declaration

            if LookAhead.Type == 'Identifier' then
                local Reference = self:GetReference(LookAhead)

                if Reference.Type ~= 'TypeDeclaration' then
                    Error.new(Error.AnalyzePrimitiveReferencesNonPrimitive, self.Source, `Primitive referencing non primitive type`):Primary(LookAhead, `Primitives can only reference other primitives`):Emit()
                end

                self:Consume('Identifier')

                Declaration = Table.DeepClone(Reference)
                Declaration.Value.Identifier = Identifier.Value
                Declaration.Tokens.Identifier = Identifier
                Declaration.Tokens.Value = LookAhead
            else
                Primitive = self:Consume('Primitive')
                Declaration = {
                    Type = 'TypeDeclaration',
                    Value = {
                        Scope = self.Scope,
                        Identifier = Identifier.Value,
                        Primitive = Primitive.Value,
                        Optional = false,
                    },
                    Tokens = {
                        Identifier = Identifier,
                        Value = Primitive,
                    },
                }

                if Primitive.Value == 'Instance' then
                    local Class = 'Instance'

                    LookAhead = self:GetSafeLookAhead()

                    if LookAhead.Type == 'Class' then
                        local ClassToken = self:Consume('Class')

                        Class = ClassToken.Value
                        Class = string.sub(Class, 2, #Class - 1)
                    end

                    Declaration.Value.Class = Class
                end
            end

            local Value = Declaration.Value
            local Array, Range = self:GetTypeAttributes(Primitive)

            Value.Array = Array
            Value.Range = Range

            return Declaration
        end
        function Parser.EnumDeclaration(self, Identifier)
            self:Consume('OpenBrackets')

            local Enums = {}

            while(self.LookAhead) do
                if self.LookAhead.Type == 'CloseBrackets' then
                    self:Consume('CloseBrackets')

                    break
                end

                local Token = self:Consume('Identifier')
                local Match = string.match(Token.Value, Number)

                if Match then
                    Error.new(Error.ParserUnexpectedSymbol, self.Source, `Unexpected symbol "{Match}"`):Primary(Token, `Enums can only contain letters, found "{Match}"`):Emit()
                end

                table.insert(Enums, Token.Value)

                local LookAhead = self:GetSafeLookAhead().Type

                if LookAhead == 'Comma' then
                    self:Consume('Comma')
                elseif LookAhead == 'CloseBrackets' then
                    self:Consume('CloseBrackets')

                    break
                end
            end

            return {
                Type = 'EnumDeclaration',
                Value = {
                    Scope = self.Scope,
                    Identifier = Identifier.Value,
                    Enums = Enums,
                    Optional = false,
                },
                Tokens = {Identifier = Identifier},
            }
        end
        function Parser.MapDeclaration(self, Identifier)
            self:Consume('OpenCurlyBrackets')
            self:Consume('OpenSquareBrackets')

            local Key = self:GetSafeLookAhead()
            local KeyDeclaration, KeyOptional = self:GetDeclarationFromToken(Key, Key)

            if KeyOptional then
                Error.new(Error.AnalyzeInvalidOptionalType, self.Source, 'Invalid optional type'):Primary(KeyOptional, `Maps cannot have optionals as keys or values`):Emit()
            end
            if KeyDeclaration.Type == 'MapDeclaration' then
                Error.new(Error.AnalyzeNestedMap, self.Source, 'Nested map'):Primary(Key, `Maps cannot have maps as keys or values`):Emit()
            elseif KeyDeclaration.Type == 'TypeReference' then
                local Reference = self:GetReference(Key)

                if Reference.Value.Optional then
                    Error.new(Error.AnalyzeInvalidOptionalType, self.Source, 'Invalid optional type'):Primary(Key, `Key is a reference to an optional type, maps cannot have optional keys or values`):Emit()
                elseif Reference.Type == 'MapDeclaration' then
                    Error.new(Error.AnalyzeNestedMap, self.Source, 'Nested map'):Primary(Key, `Maps cannot have maps as keys or values`):Emit()
                end
            end

            self:Consume('CloseSquareBrackets')
            self:Consume('Assign')

            local Value = self:GetSafeLookAhead()
            local ValueDeclaration, ValueOptional = self:GetDeclarationFromToken(Value, Value)

            if ValueOptional or ValueDeclaration.Value.Optional then
                Error.new(Error.AnalyzeInvalidOptionalType, self.Source, 'Invalid optional type'):Primary(ValueOptional, `Maps cannot have optionals as keys or values`):Emit()
            end
            if ValueDeclaration.Type == 'MapDeclaration' then
                Error.new(Error.AnalyzeNestedMap, self.Source, 'Nested map'):Primary(Value, `Maps cannot have maps as keys or values`):Emit()
            elseif ValueDeclaration.Type == 'TypeReference' then
                local Reference = self:GetReference(Value)

                if Reference.Value.Optional then
                    Error.new(Error.AnalyzeInvalidOptionalType, self.Source, 'Invalid optional type'):Primary(Value, `Value is a reference to an optional type, maps cannot have optional keys or values`):Emit()
                elseif Reference.Type == 'MapDeclaration' then
                    Error.new(Error.AnalyzeNestedMap, self.Source, 'Nested map'):Primary(Value, `Maps cannot have maps as keys or values`):Emit()
                end
            end

            self:Consume('CloseCurlyBrackets')

            local Array = self:GetTypeAttributes()

            return {
                Type = 'MapDeclaration',
                Value = {
                    Scope = self.Scope,
                    Identifier = Identifier.Value,
                    Key = KeyDeclaration,
                    Value = ValueDeclaration,
                    Array = Array,
                    Optional = false,
                },
                Tokens = {
                    Identifier = Identifier,
                    Key = Key,
                    Value = Value,
                },
            }
        end
        function Parser.StructDeclaration(self, Identifier)
            self:Consume('OpenCurlyBrackets')

            local Keys = {}
            local Fields = {}

            while(self.LookAhead) do
                if self:GetSafeLookAhead().Type == 'CloseCurlyBrackets' then
                    self:Consume('CloseCurlyBrackets')

                    break
                end

                local Key = self:Consume('Identifier')

                self:Consume('Assign')

                local Duplicate = Keys[Key.Value]

                if Duplicate then
                    Error.new(Error.AnalyzeDuplicateField, self.Source, 'Duplicate struct field'):Secondary(Duplicate, 'Previously declared here'):Primary(Key, 'Duplicate declared here'):Emit()
                end

                local Declaration = self:GetDeclarationFromToken(self:GetSafeLookAhead(), Key)

                Keys[Key.Value] = Key

                table.insert(Fields, Declaration)

                if self:GetSafeLookAhead().Type == 'CloseCurlyBrackets' then
                    self:Consume('CloseCurlyBrackets')

                    break
                end

                self:Consume('Comma')
            end

            return {
                Type = 'StructDeclaration',
                Value = {
                    Scope = self.Scope,
                    Identifier = Identifier.Value,
                    Fields = Fields,
                    Optional = false,
                },
                Tokens = {Identifier = Identifier},
            }
        end
        function Parser.TupleDeclaration(self, Identifier)
            self:Consume('OpenSquareBrackets')

            local Values = {}

            while(self.LookAhead) do
                if self:GetSafeLookAhead().Type == 'CloseSquareBrackets' then
                    self:Consume('CloseSquareBrackets')

                    break
                end

                local Key = self:GetSafeLookAhead()
                local Declaration = self:GetDeclarationFromToken(self:GetSafeLookAhead(), Key)

                table.insert(Values, Declaration)

                if self:GetSafeLookAhead().Type == 'CloseSquareBrackets' then
                    self:Consume('CloseSquareBrackets')

                    break
                end

                self:Consume('Comma')
            end

            return {
                Type = 'TupleDeclaration',
                Value = {
                    Identifier = Identifier.Value,
                    Values = Values,
                    Optional = false,
                },
            }
        end
        function Parser.EventDeclaration(self, Identifier)
            self:Consume('OpenCurlyBrackets')

            if ReservedMembers[Identifier.Value] then
                Error.new(Error.AnalyzeReservedIdentifier, self.Source, 'Reserved identifier'):Primary(Identifier, `"{Identifier.Value}" is reserved and cannot be used as a event identifier`):Emit()
            end

            local Event = {
                Type = 'EventDeclaration',
                Value = {
                    Scope = self.Scope,
                    Identifier = Identifier.Value,
                    From = 'Client',
                    Type = 'Reliable',
                    Call = 'SingleSync',
                    Data = nil,
                    Optional = false,
                },
                Tokens = {
                    Identifier = Identifier,
                    Fields = {},
                },
            }

            for Index, Entry in EventStructure do
                local Key = self:Consume('Identifier')

                if Key.Value ~= Entry.Key then
                    Error.new(Error.ParserUnexpectedToken, self.Source, `Unexpected token`):Primary(Key, `Expected "{Entry.Key}", found "{Key.Value}"`):Emit()
                end

                local Value
                local Token = self:GetSafeLookAhead()
                local Assign = self:Consume('Assign')

                if Entry.Key ~= 'Data' then
                    Token = self:Consume(Entry.Type)

                    if not table.find(Entry.Values, Token.Value) then
                        Error.new(Error.ParserUnexpectedToken, self.Source, `Unexpected token`):Primary(Token, `Expected one of "{table.concat(Entry.Values, '" or "')}", found "{Token.Value}"`):Emit()
                    end

                    Value = Token.Value
                else
                    if not self.LookAhead then
                        Error.new(Error.ParserExpectedExtraToken, self.Source, `Expected a token`):Primary(Assign, `Expected a value to follow after assignment`):Emit()

                        break
                    end
                    if Token.Type == 'OpenSquareBrackets' then
                        Value = self:TupleDeclaration(Identifier)
                    else
                        Value = self:GetDeclarationFromToken(Token, Identifier)
                    end
                end

                Event.Value[Entry.Key] = Value

                table.insert(Event.Tokens, {
                    Field = Key,
                    Value = Token,
                })

                if Index ~= #EventStructure then
                    self:Consume('Comma')
                end
            end

            self:Consume('CloseCurlyBrackets')

            return Event
        end
        function Parser.FunctionDeclaration(self, Identifier)
            self:Consume('OpenCurlyBrackets')

            if ReservedMembers[Identifier.Value] then
                Error.new(Error.AnalyzeReservedIdentifier, self.Source, 'Reserved identifier'):Primary(Identifier, `"{Identifier.Value}" is reserved and cannot be used as a function identifier`):Emit()
            end

            local Function = {
                Type = 'FunctionDeclaration',
                Value = {
                    Scope = self.Scope,
                    Identifier = Identifier.Value,
                    Optional = false,
                    Yield = 'Coroutine',
                    Data = nil,
                    Return = nil,
                },
                Tokens = {
                    Identifier = Identifier,
                    Fields = {},
                },
            }

            for Index, Entry in FunctionStructure do
                local Key = self:Consume('Identifier')

                if Key.Value ~= Entry.Key then
                    Error.new(Error.ParserUnexpectedToken, self.Source, `Unexpected token`):Primary(Key, `Expected "{Entry.Key}", found "{Key.Value}"`):Emit()
                end

                local Value
                local Token = self:GetSafeLookAhead()
                local Assign = self:Consume('Assign')

                if Entry.Key ~= 'Data' and Entry.Key ~= 'Return' then
                    Token = self:Consume(Entry.Type)

                    if not table.find(Entry.Values, Token.Value) then
                        Error.new(Error.ParserUnexpectedToken, self.Source, `Unexpected token`):Primary(Token, `Expected one of "{table.concat(Entry.Values, '" or "')}", found "{Token.Value}"`):Emit()
                    end

                    Value = Token.Value
                else
                    if not self.LookAhead then
                        Error.new(Error.ParserExpectedExtraToken, self.Source, `Expected a token`):Primary(Assign, `Expected a value to follow after assignment`):Emit()

                        break
                    end
                    if Token.Type == 'OpenSquareBrackets' then
                        Value = self:TupleDeclaration(Identifier)
                    else
                        Value = self:GetDeclarationFromToken(Token, Identifier)
                    end
                end

                Function.Value[Entry.Key] = Value

                table.insert(Function.Tokens, {
                    Field = Key,
                    Value = Token,
                })

                if Index ~= #FunctionStructure then
                    self:Consume('Comma')
                end
            end

            self:Consume('CloseCurlyBrackets')

            return Function
        end
        function Parser.ScopeDeclaration(self, Identifier)
            if self.Scope then
                Error.new(Error.AnalyzeNestedScope, self.Source, 'Nested scope'):Primary(Identifier, `Blink doesn't currently support declaring scopes within scopes`):Emit()
            end
            if ReservedMembers[Identifier.Value] then
                Error.new(Error.AnalyzeReservedIdentifier, self.Source, 'Reserved identifier'):Primary(Identifier, `"{Identifier.Value}" is reserved and cannot be used as a scope identifier`):Emit()
            end

            local Scope = Identifier.Value
            local Declarations = {}
            local Declaration = {
                Type = 'ScopeDeclaration',
                Value = {
                    Identifier = Scope,
                    Optional = false,
                    Declarations = Declarations,
                },
                Tokens = {Identifier = Identifier},
            }

            self.Scope = Scope

            self:Consume('OpenCurlyBrackets')

            while(self.LookAhead) do
                if self.LookAhead.Type == 'CloseCurlyBrackets' then
                    self:Consume('CloseCurlyBrackets')

                    break
                end

                table.insert(Declarations, self:Declaration())
            end

            self.Scope = nil

            return Declaration
        end
        function Parser.GetReference(self, Token)
            local Identifier = `{self.Scope and `{self.Scope}.` or ''}{Token.Value}`
            local Reference = self.Types[Identifier] or self.Types[Token.Value]

            if not Reference then
                Error.new(Error.AnalyzeUnknownReference, self.Source, 'Unknown reference'):Primary(Token, `Unknown type referenced`):Emit()
            end

            return Reference.Declaration
        end
        function Parser.GetTypeAttributes(self, Primitive)
            local Array, Range

            for _, Expected in {
                'Range',
                'Array',
            }do
                local LookAhead = self.LookAhead

                if not LookAhead then
                    break
                end

                local Type = LookAhead.Type

                if Type ~= Expected then
                    continue
                end
                if Type == 'Range' then
                    if not Primitive then
                        Error.new(Error.AnalyzeInvalidRangeType, self.Source, 'Type does not support ranges'):Primary(LookAhead, `References do not support ranges`):Emit()
                    elseif not RangePrimitives[Primitive.Value] then
                        Error.new(Error.AnalyzeInvalidRangeType, self.Source, 'Type does not support ranges'):Primary(LookAhead, `"{Primitive.Value}" does not support ranges`):Emit()
                    end

                    Range = GetTypeRange(LookAhead, false, self.Source)
                elseif Type == 'Array' then
                    Array = GetTypeRange(LookAhead, true, self.Source)
                end

                self:Consume(Type)
            end

            return Array, Range
        end
        function Parser.GetDeclarationFromToken(self, Token, Identifier)
            local Declaration

            if Token.Type == 'OpenCurlyBrackets' then
                local NextToken = self.Lexer:GetNextToken(true)

                if NextToken and NextToken.Type == 'OpenSquareBrackets' then
                    Declaration = self:MapDeclaration(Identifier)
                else
                    Declaration = self:StructDeclaration(Identifier)
                end
            elseif Token.Type == 'OpenBrackets' then
                Declaration = self:EnumDeclaration(Identifier)
            elseif Token.Type == 'Primitive' then
                Declaration = self:TypeDeclaration(Identifier)
            elseif Token.Type == 'Identifier' then
                local Type = self:Consume('Identifier')
                local Reference = self:GetReference(Type)
                local Array, Range = self:GetTypeAttributes()

                Declaration = {
                    Type = 'TypeReference',
                    Value = {
                        Scope = Reference.Value.Scope,
                        Identifier = Identifier.Value,
                        Reference = Reference.Value.Identifier,
                        Array = Array,
                        Range = Range,
                        Optional = false,
                    },
                    Tokens = {Identifier = Identifier},
                }
            end
            if not Declaration then
                Error.new(Error.AnalyzeUnknownReference, self.Source, 'Unknown reference'):Primary(Token, `Unknown type referenced`):Emit()
            end

            local Optional

            if self:GetSafeLookAhead().Type == 'Optional' then
                Optional = self:Consume('Optional')
                Declaration.Value.Optional = true
            end

            return Declaration, Optional
        end

        return Parser
    end
    function __DARKLUA_BUNDLE_MODULES.h()
        local TextService = game:GetService('TextService')
        local RunService = game:GetService('RunService')
        local Table = __DARKLUA_BUNDLE_MODULES.load('b')
        local State = __DARKLUA_BUNDLE_MODULES.load('a')
        local Lexer = __DARKLUA_BUNDLE_MODULES.load('e')
        local Parser = __DARKLUA_BUNDLE_MODULES.load('g')
        local Settings = __DARKLUA_BUNDLE_MODULES.load('d')
        local Error = __DARKLUA_BUNDLE_MODULES.load('c')
        local ICONS = {
            Event = 'rbxassetid://16506730516',
            Field = 'rbxassetid://16506725096',
            Snippet = 'rbxassetid://16506712161',
            Keyword = 'rbxassetid://16506695241',
            Variable = 'rbxassetid://16506719167',
            Primitive = 'rbxassetid://16506695241',
        }
        local COLORS = {
            Text = Color3 .fromHex('#FFFFFF'),
            Keyword = Color3 .fromHex('#6796E6'),
            Primitive = Color3 .fromHex('#4EC9B0'),
            Identifier = Color3 .fromHex('#9CDCFE'),
            Class = Color3 .fromHex('#B5CEA8'),
            Number = Color3 .fromHex('#B5CEA8'),
            String = Color3 .fromHex('#ADF195'),
            Bracket = Color3 .fromHex('#FFFFFF'),
            Boolean = Color3 .fromHex('#B5CEA8'),
            Error = Color3 .fromHex('#FF5050'),
            Complete = Color3 .fromHex('#04385f'),
        }
        local SYMBOLS = {
            Event = {},
            Field = {},
            Snippet = {},
            Keyword = Table.GetDictionaryKeys(Settings.Keywords),
            Variable = {},
            Primitive = Table.GetDictionaryKeys(Settings.Primtives),
        }
        local FIELDS = {
            struct = true,
            event = true,
            ['function'] = true,
        }
        local BRACKETS = {
            OpenBrackets = true,
            CloseBrackets = true,
            OpenCurlyBrackets = true,
            CloseCurlyBrackets = true,
            OpenSquareBrackets = true,
            CloseSquareBrackets = true,
        }
        local SCROLL_LINES = 2
        local CURSOR_BLINK_RATE = 0.5
        local Editor = {}
        local Container = script.Widget
        local EditorContainer = Container.Editor
        local CompletionContainer = Container.Completion
        local TextContainer = EditorContainer.Text
        local LinesContainer = EditorContainer.Lines
        local Input = TextContainer.Input
        local Cursor = TextContainer.Cursor
        local Display = TextContainer.Display
        local Selection = TextContainer.Selection
        local LineTemplate = LinesContainer.Line:Clone()
        local SelectionTemplate = Selection.Line:Clone()
        local CompletionTemplate = CompletionContainer.Option:Clone()
        local TextSize = Input.TextSize
        local TextHeight = (Input.TextSize + 3)
        local SourceLexer = Lexer.new('Highlighting')
        local SourceParser = Parser.new()
        local Lines = State.new(0)
        local Scroll = State.new(0)
        local Errors = State.new({})
        local CursorTimer = 0

        local function ScrollTowards(Direction)
            local Value = Scroll:Get()
            local Maximum = math.max(1, (Input.TextBounds.Y - EditorContainer.AbsoluteSize.Y) // TextHeight + SCROLL_LINES)

            Scroll:Set(math.clamp(Value + (Direction * SCROLL_LINES), 0, Maximum))
        end
        local function WrapColor(Text, Color)
            return `<font color="#{Color:ToHex()}">{Text}</font>`
        end
        local function ClearChildrenWhichAre(Parent, Class)
            for Index, Child in Parent:GetChildren()do
                if Child:IsA(Class) then
                    Child:Destroy()
                end
            end
        end
        local function DoLexerPass()
            local Source = Input.Text
            local RichText = ''

            SourceLexer:Initialize(Source)

            local Keyword = 'none'
            local IsField = false

            while true do
                local Success, Error, Token = pcall(function()
                    return nil, SourceLexer:GetNextToken()
                end)

                if not Success then
                    warn(`Lexer error: {Error}`)

                    break
                end
                if not Token then
                    break
                end

                local Type = Token.Type
                local Value = Token.Value

                if Type == 'Keyword' then
                    Keyword = Value

                    RichText ..= WrapColor(Value, COLORS.Keyword)
                elseif Type == 'Primitive' then
                    RichText ..= WrapColor(Value, COLORS.Primitive)
                elseif Type == 'Identifier' then
                    RichText ..= WrapColor(Value, IsField and COLORS.Text or COLORS.Identifier)
                elseif Type == 'Array' or Type == 'Range' then
                    local Single = string.match(Value, '%[(%d+)%]') or string.match(Value, '%((%d+)%)')

                    if Single then
                        RichText ..= string.gsub(Value, Single, WrapColor(Single, COLORS.Number))

                        continue
                    end

                    local Lower = string.match(Value, '%[(%d+)') or string.match(Value, '%((%d+)')
                    local Upper = string.match(Value, '(%d+)%]') or string.match(Value, '(%d+)%)')

                    if Lower and Upper then
                        RichText ..= `{string.sub(Value, 1, 1)}{WrapColor(Lower, COLORS.Number)}..{WrapColor(Upper, COLORS.Number)}{string.sub(Value, #Value, #Value)}`

                        continue
                    end

                    RichText ..= Value
                elseif BRACKETS[Type] then
                    if Type == 'CloseCurlyBrackets' then
                        IsField = false
                    end

                    RichText ..= WrapColor(Value, COLORS.Bracket)
                elseif Type == 'Class' then
                    RichText ..= `({WrapColor(string.sub(Value, 2, #Value - 1), COLORS.Class)})`
                elseif Type == 'String' then
                    RichText ..= WrapColor(Value, COLORS.String)
                elseif Type == 'Boolean' then
                    RichText ..= WrapColor(Value, COLORS.Boolean)
                elseif Type == 'Unknown' then
                    IsField = false

                    RichText ..= WrapColor(Value, COLORS.Error)
                else
                    RichText ..= Value
                end
                if Type == 'Whitespace' then
                    continue
                end

                IsField = (Type == 'Comma' or Type == 'OpenCurlyBrackets') and FIELDS[Keyword]
            end

            Display.Text = RichText
        end
        local function OnErrorEmitted(Labels)
            Errors:Set(Labels)
        end
        local function OnPreRender(DeltaTime)
            if Input.CursorPosition == -1 then
                return
            end

            CursorTimer += DeltaTime

            if CursorTimer < CURSOR_BLINK_RATE then
                return
            end

            CursorTimer -= CURSOR_BLINK_RATE

            Cursor.Visible = not Cursor.Visible
        end
        local function OnLinesChanged(Value)
            ClearChildrenWhichAre(LinesContainer, 'TextLabel')

            for Index = 1, Value do
                local Line = LineTemplate:Clone()

                Line.Text = tostring(Index)
                Line.Parent = LinesContainer
            end
        end
        local function OnScrollChanged(Value)
            EditorContainer.Position = UDim2 .fromOffset(EditorContainer.Position.X.Offset, TextHeight * 
-Value)
        end
        local function OnCursorPositionChanged()
            local CursorPosition = Input.CursorPosition

            if CursorPosition == -1 then
                Cursor.Visible = false

                return
            end

            local Text = string.sub(Input.Text, 1, CursorPosition - 1)
            local Slices = string.split(Text, '\n')
            local Line = Slices[#Slices] or ''
            local GetTextBoundsParams = Instance.new('GetTextBoundsParams')

            GetTextBoundsParams.Text = Line
            GetTextBoundsParams.Size = TextSize
            GetTextBoundsParams.Font = Input.FontFace

            local TextBounds = TextService:GetTextBoundsAsync(GetTextBoundsParams)

            Cursor.Size = UDim2 .fromOffset(2, TextSize)
            Cursor.Position = UDim2 .fromOffset(TextBounds.X - 1, TextHeight * (#Slices - 1))
        end
        local function OnSelectionChanged()
            ClearChildrenWhichAre(Selection, 'Frame')

            local CursorPosition = Input.CursorPosition
            local SelectionStart = Input.SelectionStart

            if CursorPosition == -1 or SelectionStart == -1 then
                return
            end

            local Start = math.min(CursorPosition, SelectionStart)
            local Finish = math.max(CursorPosition, SelectionStart)
            local Text = string.sub(Input.ContentText, 1, Finish - 1)
            local Slices = string.split(Text, '\n')
            local Offset = 0

            for Index, Slice in Slices do
                local First = Offset

                Offset += (#Slice + 1)

                local Line = SelectionTemplate:Clone()
                local Fill = Line.Fill

                if Offset < Start then
                    Fill.BackgroundTransparency = 1
                    Line.Parent = Selection

                    continue
                end

                local Substring = Slice

                if First < Start then
                    Substring = string.sub(Slice, (Start - First), #Slice)
                elseif Index == #Slices then
                    Substring = string.sub(Slice, 1, math.max(1, Finish - First))
                end
                if Substring == '' then
                    Substring = ' '
                end

                local SelectionBoundsParams = Instance.new('GetTextBoundsParams')

                SelectionBoundsParams.Text = Substring
                SelectionBoundsParams.Size = TextSize
                SelectionBoundsParams.Font = Input.FontFace

                local SelectionBounds = TextService:GetTextBoundsAsync(SelectionBoundsParams)

                Fill.Size = UDim2 .new(0, SelectionBounds.X, 1, 0)

                if Start > First then
                    local Prefix = string.sub(Slice, 1, (Start - First) - 1)

                    if Prefix ~= '' then
                        local OffsetBoundsParams = Instance.new('GetTextBoundsParams')

                        OffsetBoundsParams.Text = Prefix
                        OffsetBoundsParams.Size = TextSize
                        OffsetBoundsParams.Font = Input.FontFace

                        local OffsetBounds = TextService:GetTextBoundsAsync(OffsetBoundsParams)

                        Fill.Position = UDim2 .new(0, OffsetBounds.X, 0, 0)
                    end
                end

                Line.Parent = Selection
            end
        end
        local function OnSourceChanged()
            local Text = Input.Text

            Text = string.gsub(Text, '\r', '')
            Input.Text = Text

            local SourceLines = #string.split(Text, '\n')

            if SourceLines ~= Lines:Get() then
                Lines:Set(SourceLines)
            end

            DoLexerPass()
        end

        function Editor.GetSource()
            return Input.Text
        end
        function Editor.SetSource(Source)
            Scroll:Set(0)

            Input.Text = Source
        end
        function Editor.Initialize()
            Selection.Line:Destroy()
            LinesContainer.Line:Destroy()
            CompletionContainer.Option:Destroy()

            for _, Symbols in SYMBOLS do
                table.sort(Symbols, function(a, b)
                    return #a < #b
                end)
            end

            Error.OnEmit = OnErrorEmitted

            Lines:OnChange(OnLinesChanged)
            Scroll:OnChange(OnScrollChanged)
            Input:GetPropertyChangedSignal('Text'):Connect(OnSourceChanged)
            Input:GetPropertyChangedSignal('SelectionStart'):Connect(OnSelectionChanged)
            Input:GetPropertyChangedSignal('CursorPosition'):Connect(OnSelectionChanged)
            Input:GetPropertyChangedSignal('CursorPosition'):Connect(OnCursorPositionChanged)
            Input.InputChanged:Connect(function(InputObject)
                if InputObject.UserInputType == Enum.UserInputType.MouseWheel then
                    ScrollTowards(-InputObject.Position.Z)
                end
            end)
            RunService.PreRender:Connect(OnPreRender)
        end

        return Editor
    end
    function __DARKLUA_BUNDLE_MODULES.i()
        local Branches = {
            Conditional = 'elseif',
            Default = 'else',
        }
        local Operators = {
            Not = '~=',
            Equals = '==',
            Greater = '>',
            Less = '<',
            GreaterOrEquals = '>=',
            LessOrEquals = '<=',
        }
        local Block = {}

        Block.__index = Block

        function Block.new(Parent)
            local Indent = (Parent and Parent.Indent + 1 or 1)

            return setmetatable({
                Parent = Parent,
                Indent = Indent,
                Content = '',
            }, Block)
        end
        function Block.Line(self, Content, Indent, Ignore)
            local Indent = Indent or self.Indent
            local NewLine = self.Content ~= '' and '\n' or ''

            self.Content ..= `{NewLine}{string.rep('\t', Indent)}{Content}`

            return self
        end
        function Block.Comment(self, Content)
            self:Line(`-- {Content}`)

            return self
        end
        function Block.Multiline(self, Content, Indent)
            local Lines = string.split(Content, '\n')

            for _, Line in Lines do
                local NoControlCharacters = string.gsub(Line, '%c+', '')

                if NoControlCharacters == '' then
                    continue
                end

                self:Line(Line, Indent or 0, true)
            end

            return self
        end
        function Block.Loop(self, Counter, Length)
            self:Line(`for {Counter}, {Length} do`)

            return Block.new(self)
        end
        function Block.While(self, Condition)
            self:Line(`while ({Condition}) do`)

            return Block.new(self)
        end
        function Block.Iterator(self, Key, Value, Iterator)
            self:Line(`for {Key}, {Value} in {Iterator} do`)

            return Block.new(self)
        end
        function Block.Compare(self, Left, Right, Operator)
            if self.Color then
                print('COMPARE')
            end

            self:Line(`if {Left} {Operators[Operator]} {Right} then`)

            return Block.new(self)
        end
        function Block.Branch(self, Branch, Left, Right, Operator)
            local Parent = self.Parent

            assert(Parent, 'Cannot branch the top level block.')
            Parent:Multiline(self.Content)

            if Branch == 'Conditional' then
                Parent:Line(`elseif {Left} {Operators[Operator]} {Right} then`)
            else
                Parent:Line(`else`)
            end

            return Block.new(Parent)
        end
        function Block.Return(self, Return)
            self:Line(`return {Return}`)

            return self
        end
        function Block.End(self)
            local Parent = self.Parent

            if Parent then
                Parent:Multiline(self.Content)
                Parent:Line('end')

                return Parent
            end

            self:Line('end', 0)

            return self
        end
        function Block.Unwrap(self)
            return self.Content
        end

        local Function = {}

        Function.__index = Function

        setmetatable(Function, Block)

        function Function.new(Name, Arguments, Return, IsInlined)
            local Block = Block.new(nil)

            setmetatable(Block, Function)

            local Suffix = Return and `: {Return}` or ''

            if IsInlined then
                Block:Line(`{Name} = function({Arguments}){Suffix}`, 0)
            else
                Block:Line(`function {Name}({Arguments}){Suffix}`, 0)
            end

            return Block
        end

        local Connection = {}

        Connection.__index = Connection

        setmetatable(Connection, Block)

        function Connection.new(Signal, Arguments)
            local Block = Block.new()

            setmetatable(Block, Connection)

            Block.Content = `{Signal}:Connect(function({Arguments})`

            return Block
        end
        function Connection.End(self, Return)
            self:Line('end)', 0)

            return self
        end

        return {
            Block = Block.new,
            Function = Function.new,
            Connection = Connection.new,
        }
    end
    function __DARKLUA_BUNDLE_MODULES.j()
        local Builder = {}

        function Builder.new(String, BaseIndentation)
            local String = String or ''
            local Indentation = (BaseIndentation or 0)

            local function GetIndentation(Tabs)
                return string.rep('\t', Indentation + (Tabs or 0))
            end
            local function PushLines(Lines, Returns, Tabs)
                local Indent = GetIndentation(Tabs)
                local Last = Lines[#Lines]

                if string.gsub(Last, '%c', '') == '' then
                    table.remove(Lines, #Lines)
                end

                for Index, Line in Lines do
                    String ..= Indent .. Line .. '\n'
                end

                String ..= string.rep('\n', Returns or 0)
            end

            return {
                Push = function(Text, Returns, Tabs)
                    String ..= (GetIndentation(Tabs) .. Text .. string.rep('\n', Returns or 1))
                end,
                PushFront = function(Text, Returns, Tabs)
                    String = (GetIndentation(Tabs) .. Text .. string.rep('\n', Returns or 1)) .. String
                end,
                PushLines = PushLines,
                PushMultiline = function(
                    Text,
                    Returns,
                    Tabs,
                    RemoveExistingTabs
                )
                    if RemoveExistingTabs then
                        Text = string.gsub(Text, '\t', '')
                    end

                    PushLines(string.split(Text, '\n'), Returns, Tabs)
                end,
                SetIndentation = function(NewIndentation)
                    Indentation = NewIndentation
                end,
                Print = function()
                    print(String)
                end,
                DumpNoClear = function()
                    return String
                end,
                Dump = function()
                    local Text = String

                    String = ''

                    return Text
                end,
            }
        end

        return Builder
    end
    function __DARKLUA_BUNDLE_MODULES.k()
        local Blocks = __DARKLUA_BUNDLE_MODULES.load('i')
        local Parser = __DARKLUA_BUNDLE_MODULES.load('g')
        local Builder = __DARKLUA_BUNDLE_MODULES.load('j')
        local SEND_BUFFER = 'SendBuffer'
        local RECIEVE_BUFFER = 'RecieveBuffer'
        local SEND_POSITION = 'SendOffset'
        local BYTE = 1
        local SHORT = 2
        local INTEGER = 4
        local HALF_FLOAT = 2
        local FLOAT = 4
        local DOUBLE = 8
        local Types = {}
        local Asserts = {
            number = function(Variable, Min, Max)
                return {
                    Lower = `if {Variable} < {Min} then error(\`Expected "{Variable}" to be larger than {Min}, got \{{Variable}} instead.\`) end`,
                    Upper = `if {Variable} > {Max} then error(\`Expected "{Variable}" to be smaller than {Max}, got \{{Variable}} instead.\`) end`,
                    Exact = `if {Variable} ~= {Max} then error(\`Expected "{Variable}" to be equal to {Max}, got \{{Variable}} instead.\`)`,
                }
            end,
            string = function(Variable, Min, Max)
                return {
                    Lower = `if #{Variable} < {Min} then error(\`Expected length of "{Variable}" to be larger than {Min}, got \{#{Variable}} instead.\`) end`,
                    Upper = `if #{Variable} > {Max} then error(\`Expected length of "{Variable}" to be smaller than {Max}, got \{#{Variable}} instead.\`) end`,
                    Exact = `if #{Variable} ~= {Max} then error(\`Expected length of "{Variable}" to equal to {Max}, got \{#{Variable}} instead.\`) end`,
                }
            end,
            vector = function(Variable, Min, Max)
                return {
                    Lower = `if {Variable}.Magnitude < {Min} then error(\`Expected magnitude of "{Variable}" to be larger than {Min}, got \{{Variable}.Magnitude} instead.\`) end`,
                    Upper = `if {Variable}.Magnitude > {Max} then error(\`Expected magnitude of "{Variable}" to be smaller than {Max}, got \{{Variable}.Magnitude} instead.\`) end`,
                    Exact = `if {Variable}.Magnitude ~= {Max} then error(\`Expected magnitude of "{Variable}" to equal to {Max}, got \{{Variable}.Magnitude} instead.\`) end`,
                }
            end,
            buffer = function(Variable, Min, Max)
                return {
                    Lower = `if buffer.len({Variable}) < {Min} then error(\`Expected size of "{Variable}" to be larger than {Min}, got \{buffer.len({Variable})} instead.\`) end`,
                    Upper = `if buffer.len({Variable}) > {Max} then error(\`Expected size of "{Variable}" to be smaller than {Max}, got \{buffer.len({Variable})} instead.\`) end`,
                    Exact = `if buffer.len({Variable}) ~= {Max} then error(\`Expected size of "{Variable}" to equal to {Max}, got \{buffer.len({Variable})} instead.\`) end`,
                }
            end,
            Instance = function(Variable, Class)
                return {
                    Lower = `error("Something has gone wrong")`,
                    Upper = `error("Something has gone wrong")`,
                    Exact = `if (not {Variable}) or typeof({Variable}) ~= "Instance" then error(\`Expected an Instance, got \{typeof({Variable})} instead.\`) end\nif not {Variable}:IsA("{Class}") then error(\`Expected an Instance of type "{Class}", got "\{{Variable}.ClassName}" instead.\`) end`,
                }
            end,
        }
        local Structures = {Array = nil}
        local Primitives = {}

        local function GeneratePrimitivePrefab(Prefab, AssertGenerator)
            return function(Declaration, Variable, Read, Write)
                local Value = Declaration.Value
                local Variable = Variable or 'Value'
                local Range = Value.Range
                local Array = Value.Array
                local Class = Value.Class
                local Primitive = Value.Primitive
                local ReadVariable = (Array and 'Item' or Variable)
                local WriteVariable = (Array and `{Variable}[Index]` or Variable)
                local IsVariableSize = (Range and Range.Max ~= Range.Min)

                local function GenerateValidation(Block, Variable)
                    if Range and AssertGenerator then
                        local Assert = AssertGenerator(Variable, Range.Min, Range.Max)

                        if not IsVariableSize and Assert.Exact then
                            Block:Line(Assert.Exact)
                        else
                            Block:Line(Assert.Lower)
                            Block:Line(Assert.Upper)
                        end
                    elseif Primitive == 'Instance' and AssertGenerator then
                        local Assert = AssertGenerator(Variable, Class)

                        if Value.Optional and Block == Write then
                            Block:Compare(Variable, 'nil', 'Not'):Multiline(Assert.Exact, Block.Indent + 1):End()
                        else
                            Block:Multiline(Assert.Exact, Block.Indent)
                        end
                    end
                end

                if Array then
                    Read, Write = Structures.Array(Variable, Read, Write, Array)
                end

                GenerateValidation(Write, WriteVariable)
                Prefab.Read(Array and `local {ReadVariable}` or Variable, Read, Range)
                Prefab.Write(WriteVariable, Write, Range)
                GenerateValidation(Read, ReadVariable)

                if Array then
                    Read:Line(`table.insert({Variable}, {ReadVariable})`)
                    Read:End()
                    Write:End()
                end
            end
        end
        local function GenerateNumberGenerator(Type, Size)
            local Prefab = {
                Read = function(Variable, Block)
                    Block:Line(`{Variable} = buffer.read{Type}({RECIEVE_BUFFER}, Read({Size}))`)
                end,
                Write = function(Value, Block)
                    Block:Line(`Allocate({Size})`)
                    Block:Line(`buffer.write{Type}({SEND_BUFFER}, {SEND_POSITION}, {Value})`)
                end,
            }
            local Primitive = {
                Type = 'number',
                Generate = GeneratePrimitivePrefab(Prefab, Asserts.number),
            }

            return Prefab, Primitive
        end

        Types.u8, Primitives.u8 = GenerateNumberGenerator('u8', BYTE)
        Types.u16, Primitives.u16 = GenerateNumberGenerator('u16', SHORT)
        Types.u32, Primitives.u32 = GenerateNumberGenerator('u32', INTEGER)
        Types.i8, Primitives.i8 = GenerateNumberGenerator('i8', BYTE)
        Types.i16, Primitives.i16 = GenerateNumberGenerator('i16', SHORT)
        Types.i32, Primitives.i32 = GenerateNumberGenerator('i32', INTEGER)
        Types.f32, Primitives.f32 = GenerateNumberGenerator('f32', FLOAT)
        Types.f64, Primitives.f64 = GenerateNumberGenerator('f64', DOUBLE)
        Types.f16 = {
            Read = function(Variable, Block)
                Block:Line(`local Encoded = buffer.readu16({RECIEVE_BUFFER}, Read({HALF_FLOAT}))`)
                Block:Line(`local MantissaExponent = Value % 0x8000`)
                Block:Compare('MantissaExponent', '0b0_11111_0000000000 ', 'Equals'):Compare('Encoded // 0x8000', '1', 'Equals'):Line(`{Variable} = -math.huge`):Branch('Default'):Line(`{Variable} = math.huge`):End():Branch('Conditional', 'MantissaExponent', '0b1_11111_0000000000  ', 'Equals'):Line(`{Variable} = 0 / 0`):Branch('Conditional', 'MantissaExponent', '0b0_00000_0000000000  ', 'Equals'):Line(`{Variable} = 0`):Branch('Default'):Multiline('local Mantissa = MantissaExponent % 0x400\r\nlocal Exponent = MantissaExponent // 0x400\r\n\t\r\nlocal Fraction;\r\nif Exponent == 0 then\r\n\tFraction = Mantissa / 0x400\r\nelse\r\n\tFraction = Mantissa / 0x800 + 0.5\r\nend\r\n\t\r\nlocal Result = math.ldexp(Fraction, Exponent - 14)', 1):Line(`{Variable} = if Value // 0x8000 == 1 then -Result else Result`):End()
            end,
            Write = function(Value, Block)
                Block:Line(`Allocate({HALF_FLOAT})`)
                Block:Compare(Value, '65504', 'Greater'):Line(`buffer.writeu16({SEND_BUFFER}, {SEND_POSITION}, 0b0_11111_0000000000)`):Branch('Conditional', Value, '-65504', 'Less'):Line(`buffer.writeu16({SEND_BUFFER}, {SEND_POSITION}, 0b1_11111_0000000000)`):Branch('Conditional', Value, Value, 'Not'):Line(`buffer.writeu16({SEND_BUFFER}, {SEND_POSITION}, 0b1_11111_0000000001)`):Branch('Conditional', Value, '0', 'Equals'):Line(`buffer.writeu16({SEND_BUFFER}, {SEND_POSITION}, 0)`):Branch('Default'):Multiline('local Abosulte = math.abs(Value)\r\nlocal Interval = math.ldexp(1, math.floor(math.log(Abosulte, 2)) - 10) \r\nlocal RoundedValue = (Abosulte // Interval) * Interval\r\n\r\nlocal Fraction, Exponent = math.frexp(RoundedValue)\r\nExponent += 14\r\n\r\nlocal Mantissa = math.round(if Exponent <= 0\r\n\tthen Fraction * 0x400 / math.ldexp(1, math.abs(Exponent))\r\n\telse Fraction * 0x800) % 0x400\r\n\r\nlocal Result = Mantissa\r\n\t+ math.max(Exponent, 0) * 0x400\r\n\t+ if Value < 0 then 0x8000 else 0', 1):Line(`buffer.writeu16({SEND_BUFFER}, {SEND_POSITION}, Result)`):End()
            end,
        }
        Primitives.f16 = {
            Type = 'number',
            Generate = GeneratePrimitivePrefab(Types.f16, Asserts.number),
        }
        Structures.Array = function(Variable, Read, Write, Length)
            local Lower = Length.Min
            local Upper = Length.Max
            local ReadArray, WriteArray
            local IsVariableSize = (Lower ~= Upper)

            if IsVariableSize then
                Types.u16 .Read('local Length', Read)

                local Assert = Asserts.number('Length', Lower, Upper)

                Read:Line(Assert.Lower)
                Read:Line(Assert.Upper)
                Types.u16 .Write(`#{Variable}`, Write)
            else
                Read:Line(`local Length = {Upper}`)
            end

            Read:Line(`{Variable} = table.create(Length)`)

            ReadArray = Read:Loop('Index = 1', 'Length')
            WriteArray = Write:Loop('Index = 1', IsVariableSize and `math.min(#{Variable}, {Upper})` or Upper)

            return ReadArray, WriteArray
        end

        do
            Types.boolean = {
                Read = function(Variable, Block)
                    Block:Line(`{Variable} = (buffer.readu8({RECIEVE_BUFFER}, Read({BYTE})) == 1)`)
                end,
                Write = function(Value, Block)
                    Block:Line(`Allocate({BYTE})`)
                    Block:Line(`buffer.writeu8({SEND_BUFFER}, {SEND_POSITION}, {Value} and 1 or 0)`)
                end,
            }
            Primitives.boolean = {
                Type = 'boolean',
                Generate = GeneratePrimitivePrefab(Types.boolean),
            }
        end
        do
            Types.string = {
                Read = function(Variable, Block, Range)
                    if Range and Range.Min == Range.Max then
                        Block:Line(`{Variable} = buffer.readstring({RECIEVE_BUFFER}, Read({Range.Min}), {Range.Min})`)

                        return
                    end

                    Types.u16 .Read('local Length', Block)
                    Block:Line(`{Variable} = buffer.readstring({RECIEVE_BUFFER}, Read(Length), Length)`)
                end,
                Write = function(Value, Block, Range)
                    if Range and Range.Min == Range.Max then
                        Block:Line(`Allocate({Range.Min})`)
                        Block:Line(`buffer.writestring({SEND_BUFFER}, {SEND_POSITION}, {Value}, {Range.Min})`)
                    else
                        Block:Line(`local Length = #{Value}`)
                        Types.u16 .Write('Length', Block)
                        Block:Line(`Allocate(Length)`)
                        Block:Line(`buffer.writestring({SEND_BUFFER}, {SEND_POSITION}, {Value}, Length)`)
                    end
                end,
            }
            Primitives.string = {
                Type = 'string',
                Generate = GeneratePrimitivePrefab(Types.string, Asserts.string),
            }
        end
        do
            Types.vector = {
                Read = function(Variable, Block)
                    Block:Line(`{Variable} = Vector3.new(buffer.readf32({RECIEVE_BUFFER}, Read({FLOAT})), buffer.readf32({RECIEVE_BUFFER}, Read({FLOAT})), buffer.readf32({RECIEVE_BUFFER}, Read({FLOAT})))`)
                end,
                Write = function(Value, Block)
                    Block:Line(`Allocate({FLOAT * 3})`)
                    Block:Line(`local Vector = {Value}`)
                    Block:Line(`buffer.writef32({SEND_BUFFER}, {SEND_POSITION}, Vector.X)`)
                    Block:Line(`buffer.writef32({SEND_BUFFER}, {SEND_POSITION} + {FLOAT}, Vector.Y)`)
                    Block:Line(`buffer.writef32({SEND_BUFFER}, {SEND_POSITION} + {FLOAT * 2}, Vector.Z)`)
                end,
            }
            Primitives.vector = {
                Type = 'Vector3',
                Generate = GeneratePrimitivePrefab(Types.vector, Asserts.vector),
            }
        end
        do
            Types.buffer = {
                Read = function(Variable, Block, Range)
                    if Range and Range.Min == Range.Max then
                        Block:Line(`local Length = {Range.Min}`)
                    else
                        Types.u16 .Read('local Length', Block)
                    end

                    Block:Line(`{Variable} = buffer.create(Length)`)
                    Block:Line(`buffer.copy({Variable}, 0, {RECIEVE_BUFFER}, Read(Length))`)
                end,
                Write = function(Value, Block, Range)
                    if Range and Range.Min == Range.Max then
                        Block:Line(`local Length = {Range.Max}`)
                    else
                        Block:Line(`local Length = buffer.len({Value})`)
                        Types.u16 .Write('Length', Block)
                    end

                    Block:Line(`Allocate(Length)`)
                    Block:Line(`buffer.copy({SEND_BUFFER}, {SEND_POSITION}, {Value}, 0, Length)`)
                end,
            }
            Primitives.buffer = {
                Type = 'buffer',
                Generate = GeneratePrimitivePrefab(Types.buffer, Asserts.buffer),
            }
        end
        do
            Types.CFrame = {
                Read = function(Variable, Block)
                    Types.vector.Read('local Position', Block)
                    Types.f32 .Read('local rX', Block)
                    Types.f32 .Read('local rY', Block)
                    Types.f32 .Read('local rZ', Block)
                    Block:Line(`{Variable} = CFrame.new(Position) * CFrame.fromOrientation(rX, rY, rZ)`)
                end,
                Write = function(Value, Block)
                    Types.vector.Write(`{Value}.Position`, Block)
                    Block:Line(`local rX, rY, rZ = {Value}:ToOrientation()`)
                    Types.f32 .Write('rX', Block)
                    Types.f32 .Write('rY', Block)
                    Types.f32 .Write('rZ', Block)
                end,
            }
            Primitives.CFrame = {
                Type = 'CFrame',
                Generate = GeneratePrimitivePrefab(Types.CFrame),
            }
        end
        do
            Types.Color3 = {
                Read = function(Variable, Block)
                    Block:Line(`{Variable} = Color3.new(buffer.readu8({RECIEVE_BUFFER}, Read({BYTE})), buffer.readu8({RECIEVE_BUFFER}, Read({BYTE})), buffer.readu8({RECIEVE_BUFFER}, Read({BYTE})))`)
                end,
                Write = function(Value, Block)
                    Block:Line(`Allocate({FLOAT * 3})`)
                    Block:Line(`local Color = {Value}`)
                    Block:Line(`buffer.writef32({SEND_BUFFER}, {SEND_POSITION}, Color.R * 8)`)
                    Block:Line(`buffer.writef32({SEND_BUFFER}, {SEND_POSITION} + {FLOAT}, Color.G * 8)`)
                    Block:Line(`buffer.writef32({SEND_BUFFER}, {SEND_POSITION} + {FLOAT * 2}, Color.B * 8)`)
                end,
            }
            Primitives.Color3 = {
                Type = 'Color3',
                Generate = GeneratePrimitivePrefab(Types.Color3),
            }
        end
        do
            Types.Instance = {
                Read = function(Variable, Block)
                    Block:Line(`{Variable} = RecieveInstances[RecieveInstanceCursor]`)
                end,
                Write = function(Value, Block)
                    Block:Line(`table.insert(SendInstances, {Value} or false :: any)`)
                end,
            }
            Primitives.Instance = {
                Type = function(Declaration)
                    return Declaration.Value.Class
                end,
                Generate = GeneratePrimitivePrefab(Types.Instance, Asserts.Instance),
            }
        end

        return {
            Types = Types,
            Asserts = Asserts,
            Primitives = Primitives,
            Structures = Structures,
        }
    end
    function __DARKLUA_BUNDLE_MODULES.l()
        return 'local Invocations = 0\r\n\r\nlocal SendOffset = 0\r\nlocal SendCursor = 0\r\nlocal SendBuffer = buffer.create(64)\r\nlocal SendInstances = {}\r\n\r\nlocal RecieveCursor = 0\r\nlocal RecieveBuffer = buffer.create(64)\r\n\r\nlocal RecieveInstances = {}\r\nlocal RecieveInstanceCursor = 0\r\n\r\ntype BufferSave = {Cursor: number, Buffer: buffer, Instances: {Instance}}\r\n\r\nlocal function Read(Bytes: number)\r\n    local Offset = RecieveCursor\r\n    RecieveCursor += Bytes\r\n    return Offset\r\nend\r\n\r\nlocal function Save(): BufferSave\r\n    return {\r\n        Cursor = SendCursor,\r\n        Buffer = SendBuffer,\r\n        Instances = SendInstances\r\n    }\r\nend\r\n\r\nlocal function Load(Save: BufferSave?)\r\n    if Save then\r\n        SendCursor = Save.Cursor\r\n        SendOffset = Save.Cursor\r\n        SendBuffer = Save.Buffer\r\n        SendInstances = Save.Instances\r\n        return\r\n    end\r\n\r\n    SendCursor = 0\r\n    SendOffset = 0\r\n    SendBuffer = buffer.create(64)\r\n    SendInstances = {}\r\nend\r\n\r\nlocal function Invoke()\r\n    if Invocations == 255 then\r\n        Invocations = 0\r\n    end\r\n\r\n    local Invocation = Invocations\r\n    Invocations += 1\r\n    return Invocation\r\nend\r\n\r\nlocal function Allocate(Bytes: number)\r\n    local Len = buffer.len(SendBuffer)\r\n\r\n    local Size = Len\r\n    local InUse = (SendCursor + Bytes)\r\n    \r\n    if InUse > Size then\r\n        --> Avoid resizing the buffer for every write\r\n        while InUse > Size do\r\n            Size *= 1.5\r\n        end\r\n\r\n        local Buffer = buffer.create(Size)\r\n        buffer.copy(Buffer, 0, SendBuffer, 0, Len)\r\n        SendBuffer = Buffer\r\n    end\r\n\r\n    SendOffset = SendCursor\r\n    SendCursor += Bytes\r\n    \r\n    return SendOffset\r\nend\r\n\r\nlocal Types = {}\r\nlocal Calls = table.create(256)\r\n\r\nlocal Events: any = {\r\n    Reliable = table.create(256),\r\n    Unreliable = table.create(256)\r\n}\r\n\r\nlocal Queue: any = {\r\n    Reliable = table.create(256),\r\n    Unreliable = table.create(256)\r\n}\r\n\r\n'
    end
    function __DARKLUA_BUNDLE_MODULES.m()
        return 'local ReplicatedStorage = game:GetService("ReplicatedStorage")\r\nlocal RunService = game:GetService("RunService")\r\n\r\nif not RunService:IsClient() then\r\n    error("Client network module can only be required from the client.")\r\nend\r\n\r\nlocal Reliable: RemoteEvent = ReplicatedStorage:WaitForChild("BLINK_RELIABLE_REMOTE") :: RemoteEvent\r\nlocal Unreliable: UnreliableRemoteEvent = ReplicatedStorage:WaitForChild("BLINK_UNRELIABLE_REMOTE") :: UnreliableRemoteEvent\r\n\r\n-- SPLIT --\r\nlocal function StepReplication()\r\n    if SendCursor <= 0 then\r\n        return\r\n    end\r\n\r\n    local Buffer = buffer.create(SendCursor)\r\n    buffer.copy(Buffer, 0, SendBuffer, 0, SendCursor)\r\n    Reliable:FireServer(Buffer, SendInstances)\r\n\r\n    SendCursor = 0\r\n    SendOffset = 0\r\n    buffer.fill(SendBuffer, 0, 0)\r\n    table.clear(SendInstances)\r\nend\r\n'
    end
    function __DARKLUA_BUNDLE_MODULES.n()
        return 'local Players = game:GetService("Players")\r\nlocal ReplicatedStorage = game:GetService("ReplicatedStorage")\r\nlocal RunService = game:GetService("RunService")\r\n\r\nif not RunService:IsServer() then\r\n    error("Server network module can only be required from the server.")\r\nend\r\n\r\nlocal Reliable: RemoteEvent = ReplicatedStorage:FindFirstChild("BLINK_RELIABLE_REMOTE") :: RemoteEvent\r\nif not Reliable then\r\n    local RemoteEvent = Instance.new("RemoteEvent")\r\n    RemoteEvent.Name = "BLINK_RELIABLE_REMOTE"\r\n    RemoteEvent.Parent = ReplicatedStorage\r\n    Reliable = RemoteEvent\r\nend\r\n\r\nlocal Unreliable: UnreliableRemoteEvent = ReplicatedStorage:FindFirstChild("BLINK_UNRELIABLE_REMOTE") :: UnreliableRemoteEvent\r\nif not Unreliable then\r\n    local UnreliableRemoteEvent = Instance.new("UnreliableRemoteEvent")\r\n    UnreliableRemoteEvent.Name = "BLINK_UNRELIABLE_REMOTE"\r\n    UnreliableRemoteEvent.Parent = ReplicatedStorage\r\n    Unreliable = UnreliableRemoteEvent\r\nend\r\n\r\n-- SPLIT --\r\nlocal PlayersMap: {[Player]: BufferSave} = {}\r\n\r\nPlayers.PlayerRemoving:Connect(function(Player)\r\n    PlayersMap[Player] = nil\r\nend)\r\n\r\nlocal function StepReplication()\r\n    for Player, Send in PlayersMap do\r\n        if Send.Cursor <= 0 then\r\n            continue\r\n        end\r\n\r\n        local Buffer = buffer.create(Send.Cursor)\r\n        buffer.copy(Buffer, 0, Send.Buffer, 0, Send.Cursor)\r\n        Reliable:FireClient(Player, Buffer, Send.Instances)\r\n\r\n        Send.Cursor = 0\r\n        buffer.fill(Send.Buffer, 0, 0)\r\n        table.clear(Send.Instances)\r\n    end\r\nend\r\n'
    end
    function __DARKLUA_BUNDLE_MODULES.o()
        local Blocks = __DARKLUA_BUNDLE_MODULES.load('i')
        local Parser = __DARKLUA_BUNDLE_MODULES.load('g')
        local Builder = __DARKLUA_BUNDLE_MODULES.load('j')
        local Prefabs = __DARKLUA_BUNDLE_MODULES.load('k')
        local Sources = {
            Base = __DARKLUA_BUNDLE_MODULES.load('l'),
            Client = string.split(__DARKLUA_BUNDLE_MODULES.load('m'), '-- SPLIT --'),
            Server = string.split(__DARKLUA_BUNDLE_MODULES.load('n'), '-- SPLIT --'),
        }
        local DIRECTIVES = 
[[--!strict
--!native
--!optimize 2
--!nolint LocalShadow
--#selene: allow(shadowing)
]]
        local VERSION_HEADER = `-- File generated by Blink v{'0.6.2' or '0.0.0'} (https://github.com/1Axen/Blink)\n-- This file is not meant to be edited\n\n`
        local EVENT_BODY = 'RecieveCursor = 0\r\nRecieveBuffer = Buffer\r\nRecieveInstances = Instances\r\nRecieveInstanceCursor = 0\r\nlocal Size = buffer.len(RecieveBuffer)'
        local RELIABLE_BODY = {
            Header = 
[[local Buffer, Size, Instances = SendBuffer, SendCursor, SendInstances]],
            Body = 'Load(PlayersMap[Player])\r\nlocal Position = Allocate(Size)\r\nbuffer.copy(SendBuffer, Position, Buffer, 0, Size)\r\ntable.move(Instances, 1, #Instances, #SendInstances + 1, SendInstances)\r\nPlayersMap[Player] = Save()',
        }
        local UNRELIABLE_BODY = 'local Buffer = buffer.create(SendCursor)\r\nbuffer.copy(Buffer, 0, SendBuffer, 0, SendCursor)'
        local DEBUUG_GLOBALS = 'local og_typeof = typeof\r\nlocal typeof = function(a: any)\r\n    if type(a) == "table" then \r\n        return a.__typeof or "table" \r\n    end\r\n    return og_typeof(a)\r\nend\r\nlocal task = require("@lune/task")\r\nlocal game = _G.%s.game\r\n'
        local Scope
        local Context
        local Events
        local UserTypes
        local LuauTypes
        local Reliables
        local Unreliables
        local Return
        local Options
        local Generators = {}
        local Declarations = {}
        local Channels = {
            Reliable = {
                Count = 0,
                Listening = false,
            },
            Unreliable = {
                Count = 0,
                Listening = false,
            },
        }
        local Types = Prefabs.Types
        local Primitives = Prefabs.Primitives
        local Structures = Prefabs.Structures

        local function GetTypesPath(Identifier, Scope, Write)
            return `Types.{Scope and `{Scope}.` or ''}{Write and 'Write' or 'Read'}{Identifier}`
        end
        local function GetExportName(Identifier)
            return `{Scope and `{Scope}_` or ''}{Identifier}`
        end
        local function GenerateEnumLiterals(Enums)
            local Literal = ''

            for Index, EnumItem in Enums do
                Literal ..= `"{EnumItem}"{Index < #Enums and ' | ' or ''}`
            end

            return Literal
        end

        function Declarations.Primitive(Declaration, Read, Write, Variable)
            local Value = Declaration.Value
            local Primitive = Value.Primitive
            local Generator = Primitives[Primitive]

            Generator.Generate(Declaration, Variable, Read, Write)
        end
        function Declarations.Enum(Declaration, Read, Write, Variable)
            local Value = Declaration.Value
            local Enums = Value.Enums
            local Literal = GenerateEnumLiterals(Enums)

            Literal = string.gsub(Literal, '|', 'or')

            Types.u8 .Read(`local Index`, Read)

            Read = Read:Compare('Index', '0', 'Equals')

            for Index, EnumItem in Enums do
                if Index > 1 then
                    Read = Read:Branch('Conditional', 'Index', `{Index - 1}`, 'Equals')
                end

                Read:Line(`{Variable} = "{EnumItem}"`)
            end

            Read:Branch('Default'):Line(`error(\`Unexpected enum: \{Index}\`)`):End()
            Write:Line(`Allocate(1)`)

            for Index, EnumItem in Enums do
                if Index == 1 then
                    Write = Write:Compare(Variable, `"{EnumItem}"`, 'Equals')
                else
                    Write = Write:Branch('Conditional', Variable, `"{EnumItem}"`, 'Equals')
                end

                Write:Line(`buffer.writeu8(SendBuffer, SendOffset, {Index - 1})`)
            end

            Write:Branch('Default'):Line(`error(\`Unexpected enum: \{{Variable}}, expectd one of {Literal}.\`)`):End()
        end
        function Declarations.Map(Declaration, Read, Write, Variable)
            local MapValue = Declaration.Value
            local Key = MapValue.Key
            local Value = MapValue.Value
            local KeyType = Generators.LuauType(Key)
            local ValueType = Generators.LuauType(Value)

            Read:Line(`{Variable} = \{}`)
            Write:Line('local Elements = 0')
            Write:Line('local Position = Allocate(2)')
            Types.u16 .Read(`local Elements`, Read)

            local ReadLoop = Read:Loop('_ = 1', 'Elements')
            local WriteLoop = Write:Iterator('Key', 'Element', Variable)

            ReadLoop:Line(`local Key: {KeyType}, Element: {ValueType};`)
            WriteLoop:Line('Elements += 1')
            Generators.UserType(Key, ReadLoop, WriteLoop, 'Key')
            Generators.UserType(Value, ReadLoop, WriteLoop, 'Element')
            ReadLoop:Line(`{Variable}[Key] = Element`)
            WriteLoop:End()
            ReadLoop:End()
            Write:Line('buffer.writeu16(SendBuffer, Position, Elements)')
        end
        function Declarations.Struct(Declaration, Read, Write, Variable)
            local Value = Declaration.Value

            Read:Line(`{Variable} = \{} :: any`)

            for _, Field in Value.Fields do
                local FieldValue = Field.Value
                local Identifier = FieldValue.Identifier
                local FieldVariable = `{Variable}.{Identifier}`

                Generators.UserType(Field, Read, Write, FieldVariable)
            end
        end
        function Declarations.Tuple(Declaration, Read, Write)
            for Index, Value in Declaration.Value.Values do
                local Variable = `Value{Index}`

                Generators.UserType(Value, Read, Write, Variable)
            end
        end
        function Declarations.Reference(Declaration, Read, Write, Variable)
            local Value = Declaration.Value
            local Array = Value.Array
            local Reference = Value.Reference
            local ReferenceScope = Value.Scope
            local ReadPath = GetTypesPath(Reference, ReferenceScope, false)
            local WritePath = GetTypesPath(Reference, ReferenceScope, true)
            local ReadVariable = (Array and 'Item' or Variable)
            local WriteVariable = (Array and `{Variable}[Index]` or Variable)

            if Array then
                Read, Write = Structures.Array(Variable, Read, Write, Array)
            end

            Read:Line(`{Array and `local {ReadVariable}` or ReadVariable} = {ReadPath}()`)
            Write:Line(`{WritePath}({WriteVariable})`)

            if Array then
                Read:Line(`table.insert({Variable}, {ReadVariable})`)
                Read:End()
                Write:End()
            end
        end
        function Declarations.Event(Declaration)
            local Value = Declaration.Value
            local Identifier = `EVENT_{Value.Identifier}`
            local Reliability = Value.Type
            local IsReliable = (Reliability == 'Reliable')
            local IsUnreliable = (Reliability == 'Unreliable')
            local Block = IsUnreliable and Unreliables or Reliables
            local Channel = IsUnreliable and Channels.Unreliable or Channels.Reliable
            local Index = Channel.Count
            local Queue = `Queue.{Reliability}[{Index}]`
            local Connection = `Events.{Reliability}[{Index}]`
            local _, Values, _, Arguments = Generators.LuauType(Value.Data, true)
            local Read, Write = Generators.Event((Value.Data), Index, Identifier, false)

            UserTypes.PushMultiline(Read, 1, 0, false)
            UserTypes.PushMultiline(Write, 1, 0, false)

            local Body = Builder.new()
            local Indent = Scope and 2 or 1
            local WriteEvent = `{GetTypesPath(Identifier, Scope, true)}({Arguments})`

            Body.Push(`{Value.Identifier} = \{`, 1, Indent)

            if Value.From ~= Context then
                Events.Push(`{Queue} = table.create(256)`)

                Block = (Channel.Listening == false) and Block:Compare('Index', Index, 'Equals') or Block:Branch('Conditional', 'Index', Index, 'Equals')

                if IsUnreliable then
                    Unreliables = Block
                else
                    Reliables = Block
                end

                Channel.Listening = true

                Block:Line(`local {Values} = {GetTypesPath(Identifier, Scope, false)}()`)
                Block:Compare(Connection, 'nil', 'Not'):Line(Value.Call == 'SingleSync' and `{Connection}({Arguments})` or `task.spawn({Connection}, {Arguments})`):Branch('Default'):Compare(`#{Queue}`, '256', 'Greater'):Line(`warn("[Blink]: Event queue of \\"{Value.Identifier}\\" exceeded 256, did you forget to implement a listener?")`):End():Line(`table.insert({Queue}, \{{Arguments}} :: \{any})`):End()

                local ContextArguments = `Listener: ({Context == 'Server' and 'Player: Player, ' or ''}{Values}) -> ()`
                local Disconnect = Blocks.Function('', '', '()'):Line(`{Queue} = \{}`):Line(`{Connection} = nil`):End()
                local FlushQueue = Blocks.Function('', '', '()'):Line(`local EventQueue = {Queue} or \{}`):Line(`{Queue} = nil`):Iterator('Index', 'Arguments', 'EventQueue'):Line(Value.Call == 'SingleSync' and `Listener(table.unpack(Arguments))` or `task.spawn(Listener, table.unpack(Arguments))`):End():End()
                local Listener = Blocks.Function('On', ContextArguments, `() -> ()`, true):Line(`{Connection} = Listener`):Multiline(`task.spawn({FlushQueue:Unwrap()})`, 1):Multiline(`return {Disconnect:Unwrap()}`, 1):End()

                Body.PushMultiline(Listener:Unwrap(), 0, Indent + 1)
            elseif Context == 'Client' then
                local Fire = Blocks.Function('Fire', Values, '()', true)

                if IsReliable then
                    Fire:Line(WriteEvent)
                else
                    Fire:Line(`local Previous = Save()`)
                    Fire:Line(`Load()`)
                    Fire:Line(WriteEvent)
                    Fire:Line('local Buffer = buffer.create(SendCursor)')
                    Fire:Line('buffer.copy(Buffer, 0, SendBuffer, 0, SendCursor)')
                    Fire:Line('Unreliable:FireServer(Buffer, SendInstances)')
                    Fire:Line('Load(Previous)')
                end

                Fire:End()
                Body.PushMultiline(Fire:Unwrap(), 0, Indent + 1)
            else
                local Fire = Blocks.Function('Fire', `Player: Player, {Values}`, '()', true)

                if IsReliable then
                    Fire:Line('Load(PlayersMap[Player])')
                    Fire:Line(WriteEvent)
                    Fire:Line('PlayersMap[Player] = Save()')
                else
                    Fire:Line('Load()')
                    Fire:Line(WriteEvent)
                    Fire:Multiline(UNRELIABLE_BODY, 1)
                    Fire:Line('Unreliable:FireClient(Player, Buffer, SendInstances)')
                end

                Fire:End()

                local FireAll = Blocks.Function('FireAll', Values, '()', true)

                if IsReliable then
                    FireAll:Line('Load()')
                    FireAll:Line(WriteEvent)
                    FireAll:Line(RELIABLE_BODY.Header)
                    FireAll:Iterator('_', 'Player', 'Players:GetPlayers()'):Multiline(RELIABLE_BODY.Body, 2):End()
                else
                    FireAll:Line('Load()')
                    FireAll:Line(WriteEvent)
                    FireAll:Multiline(UNRELIABLE_BODY, 1)
                    FireAll:Line('Unreliable:FireAllClients(Buffer, SendInstances)')
                end

                FireAll:End()

                local FireList = Blocks.Function('FireList', `List: \{Player}, {Values}`, '()', true)

                if IsReliable then
                    FireList:Line('Load()')
                    FireList:Line(WriteEvent)
                    FireList:Line(RELIABLE_BODY.Header)
                    FireList:Iterator('_', 'Player', 'List'):Multiline(RELIABLE_BODY.Body, 2):End()
                else
                    FireList:Line('Load()')
                    FireList:Line(WriteEvent)
                    FireList:Multiline(UNRELIABLE_BODY, 1)
                    FireList:Iterator('_', 'Player', 'List'):Line('Unreliable:FireClient(Player, Buffer, SendInstances)'):End()
                end

                FireList:End()

                local FireExcept = Blocks.Function('FireExcept', `Except: Player, {Values}`, '()', true)

                if IsReliable then
                    FireExcept:Line('Load()')
                    FireExcept:Line(WriteEvent)
                    FireExcept:Line(RELIABLE_BODY.Header)
                    FireExcept:Iterator('_', 'Player', 'Players:GetPlayers()'):Compare('Player', 'Except', 'Equals'):Line('continue'):End():Multiline(RELIABLE_BODY.Body, 2):End()
                else
                    FireExcept:Line('Load()')
                    FireExcept:Line(WriteEvent)
                    FireExcept:Multiline(UNRELIABLE_BODY, 1)
                    FireExcept:Iterator('_', 'Player', 'Players:GetPlayers()'):Compare('Player', 'Except', 'Equals'):Line('continue'):End():Line('Unreliable:FireClient(Player, Buffer, SendInstances)'):End()
                end

                FireExcept:End()
                Body.PushMultiline(Fire:Unwrap() .. ',', 0, Indent + 1)
                Body.PushMultiline(FireAll:Unwrap() .. ',', 0, Indent + 1)
                Body.PushMultiline(FireList:Unwrap() .. ',', 0, Indent + 1)
                Body.PushMultiline(FireExcept:Unwrap() .. ',', 0, Indent + 1)
            end

            Channel.Count += 1

            Body.Push(`},`, 1, Indent)
            Return.PushMultiline(Body.Dump(), 0)
        end
        function Declarations.Function(Declaration)
            local Value = Declaration.Value
            local DataIdentifier = `FUNCTION_DATA_{Value.Identifier}`
            local ReturnIdentifier = `FUNCTION_RETURN_{Value.Identifier}`
            local Yield = Value.Yield
            local IsFuture = (Yield == 'Future')
            local IsPromise = (Yield == 'Promise')
            local IsCoroutine = (Yield == 'Coroutine')

            if IsFuture and not Options.FutureLibrary then
                error(`Cannot use yield type: "Future", without providing a path to the future library.`)
            end
            if IsPromise and not Options.PromiseLibrary then
                error(`Cannot use yield type: "Promise", without providing a path to the promise library.`)
            end

            local Block = Reliables
            local Channel = Channels.Reliable
            local Index = Channel.Count
            local Queue = `Queue.Reliable[{Index}]`
            local Connection = `Events.Reliable[{Index}]`
            local DataTypes, DataValues, _, DataArguments = Generators.LuauType(Value.Data, true)
            local ReturnTypes, ReturnValues, _, ReturnArguments = Generators.LuauType(Value.Return, true)

            do
                local Read, Write = Generators.Event((Value.Data), Index, DataIdentifier, 'Data')

                UserTypes.PushMultiline(Read, 1, 0, false)
                UserTypes.PushMultiline(Write, 1, 0, false)
            end
            do
                local Read, Write = Generators.Event((Value.Return), Index, ReturnIdentifier, 'Return')

                UserTypes.PushMultiline(Read, 1, 0, false)
                UserTypes.PushMultiline(Write, 1, 0, false)
            end

            local Body = Builder.new()
            local Indent = Scope and 2 or 1

            Body.Push(`{Value.Identifier} = \{`, 1, Indent)
            Events.Push(`{Queue} = table.create(256)`)

            Block = (Channel.Listening == false) and Block:Compare('Index', Index, 'Equals') or Block:Branch('Conditional', 'Index', Index, 'Equals')
            Reliables = Block

            if Context == 'Server' then
                Types.u8 .Read('local InvocationIdentifier', Block)
                Block:Line(`local {DataValues} = {GetTypesPath(DataIdentifier, Scope, false)}()`):Compare(Connection, 'nil', 'Not'):Line(`{Connection}(Player, {DataArguments}, InvocationIdentifier)`):Branch('Default'):Compare(`#{Queue}`, '256', 'Greater'):Line(`warn("[Blink]: Event queue of \\"{Value.Identifier}\\" exceeded 256, did you forget to implement a listener?")`):End():Line(`table.insert({Queue}, \{Player, {DataArguments}, InvocationIdentifier} :: \{any})`):End()

                local FlushQueue = Blocks.Function('', '', '()'):Line(`local EventQueue = {Queue} or \{}`):Line(`{Queue} = nil`):Iterator('Index', 'Arguments', 'EventQueue'):Line(`{Connection}(table.unpack(Arguments))`):End():End()
                local Serialize = Blocks.Function('', ''):Line(`local {ReturnValues} = Listener(Player, {DataArguments})`):Line(`SerializationError = true`):Line(`{GetTypesPath(ReturnIdentifier, Scope, true)}({ReturnArguments}, InvocationIdentifier)`):End()
                local TrueListener = Blocks.Function(Connection, `Player: Player, {DataValues}, InvocationIdentifier: number`, '()', true):Line('Load(PlayersMap[Player])'):Line('local SerializationError = false'):Multiline(`local Success, Error = pcall({Serialize:Unwrap()})`, 1):Compare('Success', 'true', 'Not'):Compare('SerializationError', 'true', 'Equals'):Line(`error(\`Blink failed to serialize function: "{Value.Identifier}", \{Error}\`)`):End():Line('local Position = Allocate(3)'):Line(`buffer.writeu8(SendBuffer, Position, {Index})`):Line(`buffer.writeu8(SendBuffer, Position + 1, InvocationIdentifier)`):Line(`buffer.writeu8(SendBuffer, Position + 2, 0)`):Line(`warn(\`"{Value.Identifier}" encountered an error, \{Error}\`)`):End():Line('PlayersMap[Player] = Save()'):End()
                local Listener = Blocks.Function('On', `Listener: (Player, {DataTypes}) -> ({ReturnTypes})`, '()', true):Multiline(TrueListener:Unwrap(), 1):Multiline(`task.spawn({FlushQueue:Unwrap()})`, 1):End()

                Body.PushMultiline(Listener:Unwrap(), 0, 2)
            else
                local Deserialize = Blocks.Function('', ''):Return(`{GetTypesPath(ReturnIdentifier, Scope, false)}()`):End()

                Types.u8 .Read('local InvocationIdentifier', Block)
                Block:Compare('Calls[InvocationIdentifier]', 'nil', 'Not'):Multiline(`local Success, {ReturnArguments} = pcall({Deserialize:Unwrap()})`, Block.Indent + 1):Line(`task.spawn(Calls[InvocationIdentifier], Success, {ReturnArguments})`):End()

                local Error = `"Server encountered an exception while processing \\"{Value.Identifier}\\"."`
                local Contents = Blocks.Block():Line('local InvocationIdentifier = Invoke()'):Line(`{GetTypesPath(DataIdentifier, Scope, true)}({DataArguments}, InvocationIdentifier)`):Line('Calls[InvocationIdentifier] = coroutine.running()'):Line(`local Success, {ReturnValues} = coroutine.yield()`):Compare('Success', 'true', 'Not'):Line(`error({Error})`):End():Return(ReturnArguments):Unwrap()
                local Invoke

                if IsFuture then
                    local Wrapper = Blocks.Function('', ''):Multiline(Contents):End()

                    Invoke = Blocks.Function('Invoke', DataValues, `Future.Future<{ReturnTypes}>`, true)

                    Invoke:Multiline(`return Future.Try({Wrapper:Unwrap()})`, 1)
                elseif IsPromise then
                    local OnCancel = Blocks.Function('', ''):Line('Calls[InvocationIdentifier] = nil'):End()
                    local Promise = Blocks.Function('', 'Resolve, Reject, OnCancel'):Line('local InvocationIdentifier = Invoke()'):Line(`{GetTypesPath(DataIdentifier, Scope, true)}({DataArguments}, InvocationIdentifier)`):Line('Calls[InvocationIdentifier] = coroutine.running()'):Multiline(`OnCancel({OnCancel:Unwrap()})`, 1):Line(`local Success, {ReturnValues} = coroutine.yield()`):Compare('Success', 'true', 'Not'):Line(`Reject({Error})`):Return(''):End():Line(`Resolve({ReturnArguments})`):End()

                    Invoke = Blocks.Function('Invoke', DataValues, `unknown`, true)

                    Invoke:Multiline(`return Promise.new({Promise:Unwrap()})`, 1)
                else
                    Invoke = Blocks.Function('Invoke', DataValues, `({ReturnTypes})`, true)

                    Invoke:Multiline(Contents, 1)
                end

                Body.PushMultiline(Invoke:End():Unwrap(), 0, 2)
            end

            Channel.Count += 1

            Channel.Listening = true

            Body.Push(`},`, 1, Indent)
            Return.PushMultiline(Body.Dump(), 0)
        end
        function Generators.Optional(Declaration, Read, Write, Variable)
            if Declaration.Type == 'TypeDeclaration' and Declaration.Value.Primitive == 'Instance' then
                Read = Read:Compare('typeof(RecieveInstances[RecieveInstanceCursor])', '"Instance"', 'Equals')
            else
                Types.u8 .Write(`{Variable} ~= nil and 1 or 0`, Write)

                Read = Read:Compare(`buffer.readu8(RecieveBuffer, Read(1))`, '1', 'Equals')
                Write = Write:Compare(Variable, 'nil', 'Not')
            end

            return Read, Write
        end
        function Generators.UserType(Declaration, Read, Write, Variable)
            local Value = Declaration.Value
            local Optional = Value.Optional
            local Variable = Variable or 'Value'
            local IsInstance = (Declaration.Type == 'TypeDeclaration' and (((Value).Primitive)) == 'Instance')

            if not true then
                Read:Comment(`{Variable}: {Value.Identifier}`)
                Write:Comment(`{Variable}: {Value.Identifier}`)
            end
            if IsInstance then
                Read:Line('RecieveInstanceCursor += 1')
            end
            if Optional then
                Read, Write = Generators.Optional(Declaration, Read, Write, Variable)
            end
            if Declaration.Type == 'TypeDeclaration' then
                Declarations.Primitive(Declaration, Read, Write, Variable)
            elseif Declaration.Type == 'EnumDeclaration' then
                Declarations.Enum(Declaration, Read, Write, Variable)
            elseif Declaration.Type == 'MapDeclaration' then
                Declarations.Map(Declaration, Read, Write, Variable)
            elseif Declaration.Type == 'StructDeclaration' then
                Declarations.Struct(Declaration, Read, Write, Variable)
            elseif Declaration.Type == 'TupleDeclaration' then
                Declarations.Tuple(Declaration, Read, Write)
            elseif Declaration.Type == 'TypeReference' then
                Declarations.Reference(Declaration, Read, Write, Variable)
            end
            if Optional then
                Read:End()

                if not IsInstance then
                    Write:End()
                end
            end
        end
        function Generators.LuauType(Declaration, UseTypeAsValue)
            local Type = ''
            local Values = ''
            local Export = GetExportName(Declaration.Value.Identifier)
            local Returns = 'Value'

            if Declaration.Type == 'TypeDeclaration' then
                local Value = (Declaration).Value
                local Primitive = Primitives[Value.Primitive]

                if type(Primitive.Type) == 'function' then
                    Type = Primitive.Type(Declaration)
                else
                    Type = Primitive.Type
                end
                if Value.Array then
                    Type = `\{{Type}}`
                end
            elseif Declaration.Type == 'EnumDeclaration' then
                local Value = (Declaration).Value

                Type = GenerateEnumLiterals(Value.Enums)
            elseif Declaration.Type == 'MapDeclaration' then
                local MapValue = (Declaration).Value
                local Key = Generators.LuauType(MapValue.Key)
                local Value = Generators.LuauType(MapValue.Value)

                Type = `\{[{Key}]: {Value}}`
            elseif Declaration.Type == 'StructDeclaration' then
                local Value = Declaration.Value

                Type = '{ '

                for _, Field in Value.Fields do
                    local FieldValue = Field.Value
                    local Identifier = FieldValue.Identifier
                    local FieldType = Generators.LuauType(Field)

                    Type ..= `{Identifier}: {FieldType}, `
                end

                Type ..= ' }'
            elseif Declaration.Type == 'TypeReference' then
                local Value = (Declaration).Value
                local Reference = Value.Reference
                local ReferenceScope = Value.Scope
                local Prefix = ReferenceScope and `{ReferenceScope}_` or ''

                Type = `{Prefix}{Reference}`

                if Value.Array then
                    Type = `\{{Type}}`
                end
            elseif Declaration.Type == 'TupleDeclaration' then
                local Value = (Declaration).Value
                local TupleValues = Value.Values

                Returns = ''

                for Index, TupleValue in TupleValues do
                    local Variable = `Value{Index}`
                    local ValueType = Generators.LuauType(TupleValue)
                    local Seperator = Index < #TupleValues and ', ' or ''

                    Type ..= `{ValueType}{Seperator}`
                    Values ..= `{Variable}: {ValueType}{Seperator}`
                    Returns ..= `{Variable}{Seperator}`
                end
            end
            if Declaration.Type ~= 'TupleDeclaration' then
                if Declaration.Value.Optional then
                    Type = `({Type})?`
                end

                Values = `Value: {UseTypeAsValue and Type or Export}`
            end

            return Type, Values, Export, Returns
        end
        function Generators.Type(Declaration)
            local Value = Declaration.Value
            local Identifier = Value.Identifier
            local Type, Values, Export, Returns = Generators.LuauType(Declaration)
            local Read = Blocks.Function(GetTypesPath(Identifier, Scope, false), '', `({Export})`)
            local Write = Blocks.Function(GetTypesPath(Identifier, Scope, true), Values, '()')

            Read:Line(`local {Values};`)
            Generators.UserType(Declaration, Read, Write)

            return `export type {Export} = {Type}`, Read:Return(Returns):End():Unwrap(), Write:End():Unwrap()
        end
        function Generators.Event(Data, Index, Identifier, Function)
            local Type, Values, _, Returns = Generators.LuauType(Data, true)
            local Arguments = `{Values}{Function and ', InvocationIdentifier: number' or ''}`
            local Read = Blocks.Function(GetTypesPath(Identifier, Scope, false), '', `({Type})`)
            local Write = Blocks.Function(GetTypesPath(Identifier, Scope, true), Arguments, '()')

            if not true then
                Write:Comment(`{Identifier} ({Index})`)
            end

            Types.u8 .Write(Index, Write)

            if Function then
                Types.u8 .Write('InvocationIdentifier', Write)

                if Function == 'Return' then
                    Types.u8 .Write('1', Write)
                    Types.u8 .Read('local Success', Read)
                    Read:Compare('Success', '1', 'Not'):Line('error("Server encountered an error.")'):End()
                end
            end

            Read:Line(`local {Values};`)
            Generators.UserType(Data, Read, Write)

            return Read:Return(Returns):End():Unwrap(), Write:End():Unwrap()
        end
        function Generators.Scope(Declaration)
            local Value = Declaration.Value
            local Identifier = Value.Identifier

            Scope = Identifier

            Return.Push(`{Identifier} = \{`, 1, 1)
            UserTypes.PushFront(`Types.{Identifier} = \{}`, 2)
            Generators.AbstractSyntaxTree(Value.Declarations)
            Return.Push(`},`, 1, 1)

            Scope = nil
        end
        function Generators.AbstractSyntaxTree(Value)
            for Index, Declaration in Value do
                if Declaration.Type == 'TypeDeclaration' or Declaration.Type == 'EnumDeclaration' or Declaration.Type == 'StructDeclaration' or Declaration.Type == 'MapDeclaration' then
                    local Export, Read, Write = Generators.Type(Declaration)

                    UserTypes.PushMultiline(Read, 1, 0, false)
                    UserTypes.PushMultiline(Write, 1, 0, false)
                    LuauTypes.PushMultiline(Export, 0, 0, false)
                elseif Declaration.Type == 'ScopeDeclaration' then
                    Generators.Scope(Declaration)
                elseif Declaration.Type == 'EventDeclaration' then
                    Declarations.Event(Declaration)
                elseif Declaration.Type == 'FunctionDeclaration' then
                    Declarations.Function(Declaration)
                end
            end
        end

        return function(FileContext, AbstractSyntaxTree, UserOptions)
            local Imports = Builder.new()

            Events = Builder.new()
            UserTypes = Builder.new()
            LuauTypes = Builder.new()
            Return = Builder.new()
            Context = FileContext
            Options = UserOptions
            Channels.Reliable.Count = 0
            Channels.Unreliable.Count = 0
            Channels.Reliable.Listening = false
            Channels.Unreliable.Listening = false

            local Signal = Context == 'Client' and 'OnClientEvent' or 'OnServerEvent'
            local Arguments = (Context == 'Server' and 'Player: Player, ' or '') .. 'Buffer: buffer, Instances: {Instance}'

            Reliables = Blocks.Connection(`Reliable.{Signal}`, Arguments)
            Unreliables = Blocks.Connection(`Unreliable.{Signal}`, Arguments)

            Reliables:Multiline(EVENT_BODY, 1)
            Unreliables:Multiline(EVENT_BODY, 1)

            Reliables = Reliables:While('RecieveCursor < Size')
            Unreliables = Unreliables:While('RecieveCursor < Size')

            Types.u8 .Read('local Index', Reliables)
            Types.u8 .Read('local Index', Unreliables)

            if UserOptions.FutureLibrary then
                Imports.Push(`local Future = require({UserOptions.FutureLibrary})`)
            end
            if UserOptions.PromiseLibrary then
                Imports.Push(`local Promise = require({UserOptions.PromiseLibrary})`)
            end

            local Replication = Builder.new()

            Return.Push('StepReplication = StepReplication,', 1, 1)

            if not UserOptions.ManualReplication then
                if Context == 'Server' then
                    Replication.Push('RunService.Heartbeat:Connect(StepReplication)')
                elseif Context == 'Client' then
                    Replication.Push('local Elapsed = 0')

                    local Connection = Blocks.Connection('RunService.Heartbeat', 'DeltaTime: number'):Line('Elapsed += DeltaTime'):Compare('Elapsed', '(1 / 61)', 'GreaterOrEquals'):Line('Elapsed -= (1 / 61)'):Line('StepReplication()'):End():End():Unwrap()

                    Replication.PushMultiline(Connection)
                end
            end

            Generators.AbstractSyntaxTree(AbstractSyntaxTree.Value)

            local Source = Sources[Context]

            if Channels.Reliable.Listening then
                Reliables = Reliables:End()
            end
            if Channels.Unreliable.Listening then
                Unreliables = Unreliables:End()
            end

            Reliables = Reliables:End():End()
            Unreliables = Unreliables:End():End()

            return DIRECTIVES .. VERSION_HEADER .. (if not true then string.format(DEBUUG_GLOBALS, string.lower(Context), string.lower(Context))else'') .. Source[1] .. Imports.Dump() .. Sources.Base .. Events.Dump() .. '\n' .. LuauTypes.Dump() .. '\n' .. UserTypes.Dump() .. Source[2] .. '\n' .. Replication.Dump() .. '\n' .. Reliables:Unwrap() .. '\n\n' .. Unreliables:Unwrap() .. '\n' .. `\nreturn \{\n{Return.Dump()}}`
        end
    end
end

local ServerStorage = game:GetService('ServerStorage')
local UserInputService = game:GetService('UserInputService')
local ContextActionService = game:GetService('ContextActionService')
local TweenService = game:GetService('TweenService')
local TextService = game:GetService('TextService')
local RunService = game:GetService('RunService')
local Selection = game:GetService('Selection')
local State = __DARKLUA_BUNDLE_MODULES.load('a')
local Editor = __DARKLUA_BUNDLE_MODULES.load('h')
local Parser = __DARKLUA_BUNDLE_MODULES.load('g')
local Generator = __DARKLUA_BUNDLE_MODULES.load('o')
local FILES_FOLDER = 'BLINK_CONFIGURATION_FILES'
local TEMPLATE_FILE = {
    Name = 'Template',
    Source = 'type Example = u8\r\nevent MyEvent = {\r\n    From = Server,\r\n    Type = Reliable,\r\n    Call = SingleSync,\r\n    Data = Example\r\n}',
}
local ERROR_WIDGET = DockWidgetPluginGuiInfo.new(Enum.InitialDockState.Float, false, true, 500, 240, 300, 240)
local EDITOR_WIDGET = DockWidgetPluginGuiInfo.new(Enum.InitialDockState.Left, false, false, 360, 400, 300, 400)
local SAVE_COLOR = Color3 .fromRGB(0, 100, 0)
local BUTTON_COLOR = Color3 .fromRGB(30, 30, 30)
local EXPAND_TWEEN = TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut)
local Toolbar = plugin:CreateToolbar('Blink Suite')
local EditorButton = Toolbar:CreateButton('Editor', 'Opens the configuration editor', 'rbxassetid://16468561002')

EditorButton.ClickableWhenViewportHidden = true

local Template = script.Widget
local FileTemplate = Template.Side.Content.Top.Files.File:Clone()

Template.Side.Content.Top.Files.File:Destroy()

local ErrorWidget = plugin:CreateDockWidgetPluginGui('Generation Error', ERROR_WIDGET)

ErrorWidget.Name = 'Generation Error'
ErrorWidget.Title = 'Error'
ErrorWidget.ZIndexBehavior = Enum.ZIndexBehavior.Sibling

local ErrorInterface = script.Error:Clone()

ErrorInterface.Parent = ErrorWidget

local ErrorText = ErrorInterface.Text
local EditorWidget = plugin:CreateDockWidgetPluginGui('Configuration Editor', EDITOR_WIDGET)

EditorWidget.Name = 'Blink Editor'
EditorWidget.Title = 'Configuration Editor'
EditorWidget.ZIndexBehavior = Enum.ZIndexBehavior.Sibling

local EditorInterface = script.Widget

EditorInterface.Size = UDim2 .fromScale(1, 1)
EditorInterface.Parent = EditorWidget

local Side = EditorInterface.Side
local Overlay = EditorInterface.Overlay
local Content = Side.Content
local Expand = Side.Expand
local Top = Content.Top
local Bottom = Content.Bottom
local Files = Top.Files
local Search = Top.Title.Search.Input
local Prompt = Bottom.Save
local Buttons = Bottom.Buttons
local GeneratePrompt = Bottom.Generate
local GenerateButtons = GeneratePrompt.Buttons
local Hint = GeneratePrompt.Hint
local Generate = GenerateButtons.Generate
local CancelGenerate = GenerateButtons.Cancel
local Input = Prompt.Input
local Save = Buttons.Save
local Cancel = Buttons.Cancel
local Tweens = {
    Editor = {
        Expand = {
            Side = TweenService:Create(Side, EXPAND_TWEEN, {
                Position = UDim2 .new(),
            }),
            Content = TweenService:Create(Content, EXPAND_TWEEN, {GroupTransparency = 0}),
            Overlay = TweenService:Create(Overlay, EXPAND_TWEEN, {BackgroundTransparency = 0.5}),
        },
        Retract = {
            Side = TweenService:Create(Side, EXPAND_TWEEN, {
                Position = Side.Position,
            }),
            Content = TweenService:Create(Content, EXPAND_TWEEN, {GroupTransparency = 1}),
            Overlay = TweenService:Create(Overlay, EXPAND_TWEEN, {BackgroundTransparency = 1}),
        },
    },
}
local Saving = false
local Expanded = State.new(false)
local Selected = State.new(nil)
local Generating = State.new(nil)
local WasOpened = false
local Editing

local function ShowError(Error)
    local Start = string.find(Error, '<font', 1, true)

    ErrorText.Text = string.sub(Error, Start or 1, #Error)
    ErrorWidget.Enabled = true
end
local function PlayTweens(Tweens)
    for _, Tween in Tweens do
        Tween:Play()
    end
end
local function CreateScript(Name, Source, RunContent, Parent)
    local Script = Instance.new('Script')

    Script.Name = Name
    Script.Source = Source
    Script.RunContext = RunContent
    Script.Parent = Parent
end
local function RequestScriptPermissions()
    local Success = pcall(function()
        local Script = Instance.new('Script', script)

        Script:Destroy()
    end)

    return Success
end
local function ClearChildrenWhichAre(Parent, Class)
    for Index, Child in Parent:GetChildren()do
        if Child:IsA(Class) then
            Child:Destroy()
        end
    end
end
local function GetSaveFolder()
    local SaveFolder = ServerStorage:FindFirstChild(FILES_FOLDER)

    if not SaveFolder then
        local Folder = Instance.new('Folder')

        Folder.Name = FILES_FOLDER
        Folder.Parent = ServerStorage
        SaveFolder = Folder
    end

    return SaveFolder
end
local function GenerateFile(File, Directory)
    local Source = File.Value
    local SourceParser = Parser.new()
    local Success, Error, AbstractSyntaxTree, UserOptions = pcall(function()
        return nil, SourceParser:Parse(Source)
    end)

    if not Success then
        ShowError(tostring(Error))

        return
    end
    if not RequestScriptPermissions() then
        warn(
[[[BLINK]: File generation failed, plugin doesn't have script inject permissions.]])

        return
    end

    local ServerOutput = Generator('Server', AbstractSyntaxTree, UserOptions)
    local ClientOutput = Generator('Client', AbstractSyntaxTree, UserOptions)
    local BlinkFolder = (Directory:FindFirstChild('Folder'))

    if not BlinkFolder then
        local Folder = Instance.new('Folder')

        Folder.Name = 'Blink'
        Folder.Parent = Directory
        BlinkFolder = Folder
    end

    BlinkFolder:ClearAllChildren()
    CreateScript('Server', ServerOutput, Enum.RunContext.Server, BlinkFolder)
    CreateScript('Client', ClientOutput, Enum.RunContext.Client, BlinkFolder)
end
local function LoadFile(File)
    Expanded:Set(false)

    Editing = File.Name

    Editor.SetSource(File.Value)
end
local function LoadFiles()
    Generating:Set()
    ClearChildrenWhichAre(Files, 'Frame')

    local FileInstances = GetSaveFolder():GetChildren()

    table.sort(FileInstances, function(a, b)
        return a.Name < b.Name
    end)

    for _, File in FileInstances do
        local Name = File.Name
        local Frame = FileTemplate:Clone()
        local Buttons = Frame.Buttons

        Frame.Name = Name
        Frame.Title.Text = Name

        Buttons.Edit.Activated:Connect(function()
            LoadFile(File)
        end)
        Buttons.Delete.Activated:Connect(function()
            File:Destroy()
            LoadFiles()
        end)
        Buttons.Generate.Activated:Connect(function()
            if GeneratePrompt.Visible then
                return
            end

            Generating:Set(File)
        end)

        Frame.Parent = Files
    end
end
local function SaveFile(Name, Source)
    local SaveFolder = GetSaveFolder()
    local SaveInstance = (SaveFolder:FindFirstChild(Name))

    if not SaveInstance then
        local NewSaveInstance = Instance.new('StringValue')

        NewSaveInstance.Name = Name
        NewSaveInstance.Value = Source
        NewSaveInstance.Parent = SaveFolder

        return
    end

    SaveInstance.Value = Source
end
local function CreateTemplateFile()
    if ServerStorage:FindFirstChild(FILES_FOLDER) then
        return
    end

    SaveFile(TEMPLATE_FILE.Name, TEMPLATE_FILE.Source)
    LoadFile((GetSaveFolder():FindFirstChild(TEMPLATE_FILE.Name)))
end
local function OnSearch(PressedEnter)
    if not PressedEnter then
        return
    end

    local Query = Search.Text

    for _, Frame in Files:GetChildren()do
        if not Frame:IsA('Frame') then
            continue
        end
        if Query == '' then
            Frame.Visible = true

            continue
        end

        Frame.Visible = (string.find(Frame.Name, Query) ~= nil)
    end
end
local function OnSaveCompleted()
    Saving = false
    Prompt.Visible = false
    Cancel.Visible = false
    Save.BackgroundColor3 = BUTTON_COLOR
end
local function OnSaveActivated()
    if Saving then
        local Name = Input.Text

        if Name == '' then
            return
        end

        SaveFile(Name, Editor.GetSource())
        LoadFiles()
        OnSaveCompleted()

        return
    end

    Saving = true
    Input.Text = Editing or ''
    Prompt.Visible = true
    Cancel.Visible = true
    Save.BackgroundColor3 = SAVE_COLOR
end
local function OnExpandActivated()
    if not WasOpened then
        WasOpened = true

        CreateTemplateFile()
        LoadFiles()
    end

    Expanded:Set(not Expanded:Get())
end
local function OnEditorButtonClicked()
    EditorWidget.Enabled = not EditorWidget.Enabled
end

Editor.Initialize()
Expanded:OnChange(function(Value)
    PlayTweens(Value and Tweens.Editor.Expand or Tweens.Editor.Retract)
end)
Selected:OnChange(function(Value)
    Generate.TextTransparency = Value and 0 or 0.5
    Hint.Text = Value and `<b>Selected</b>\n{Value:GetFullName()}` or 
[[Select the location in which to generate the output scripts.]]
end)
Generating:OnChange(function(File)
    GeneratePrompt.Visible = (File ~= nil)
end)
Selection.SelectionChanged:Connect(function()
    local Instances = Selection:Get()

    Selected:Set(Instances[1])
end)
Generate.Activated:Connect(function()
    local File = Generating:Get()

    if not File then
        return
    end

    local Directory = Selected:Get()

    if not Directory then
        return
    end

    Generating:Set()
    GenerateFile(File, Directory)
end)
CancelGenerate.Activated:Connect(function()
    Generating:Set()
end)
Search.FocusLost:Connect(OnSearch)
Save.Activated:Connect(OnSaveActivated)
Cancel.Activated:Connect(OnSaveCompleted)
Expand.Activated:Connect(OnExpandActivated)
EditorButton.Click:Connect(OnEditorButtonClicked)
