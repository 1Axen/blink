--!strict

-- ******************************* --
-- 			AX3NX / AXEN		   --
-- ******************************* --

---- Services ----

local UserInputService = game:GetService("UserInputService")
local ContentProvider = game:GetService("ContentProvider")
local TextService = game:GetService("TextService")
local RunService = game:GetService("RunService")

---- Imports ----

local Table = require("../Table")
local State = require("../State")
local Utility = require("./Utility")

local Profiler = require("../Profiler")

local Lexer = require("../../../src/Lexer")
local Parser = require("../../../src/Parser")
local Settings = require("../../../src/Settings")

local Error = require("../../../src/Modules/Error")

local StylingHooks: {{OnSourceChanged: (Text: string, PreviousText: string, Cursor: number, Gain: number) -> (string, number)}} = {
   require("./Styling/AutoIndent"),
   require("./Styling/AutoBracket"),
}

---- Settings ----

local ICONS = {
    Event = "rbxassetid://16506730516",
    Field = "rbxassetid://16506725096",
    Snippet = "rbxassetid://16506712161",
    Keyword = "rbxassetid://16506695241",
    Variable = "rbxassetid://16506719167",
    Primitive = "rbxassetid://16506695241"
}

local THEME = {
    Text = Color3.fromHex("#FFFFFF"),
    Keyword = Color3.fromHex("#6796E6"),
    Primitive = Color3.fromHex("#4EC9B0"),
    Identifier = Color3.fromHex("#9CDCFE"),

    Class = Color3.fromHex("#B5CEA8"),
    Number = Color3.fromHex("#B5CEA8"),
    String = Color3.fromHex("#ADF195"),
    Bracket = Color3.fromHex("#FFFFFF"),
    Boolean = Color3.fromHex("#B5CEA8"),
    Comment = Color3.fromHex("#529955"),

    Error = Color3.fromHex("#FF5050"),
    Warning = Color3.fromHex("#FF5050"),

    Complete = Color3.fromHex("#04385f"),

    Line = {
        Active = Color3.fromHex("FFFFFF"),
        Inactive = Color3.fromHex("787878")
    }
}
-- This is a comment
local PRIMITIVES = {}
for Primitive in Settings.Primtives do
    table.insert(PRIMITIVES, {Label = Primitive, Insert = Primitive})
end

local SYMBOLS: {[string]: {{Label: string, Insert: string}}} = {
    Event = {},
    Field = {},
    Snippet = {},
    Keyword = {
        {Label = "set", Insert = "set %s = {}"},
        {Label = "map", Insert = "map %s = {[]: }"},
        {Label = "type", Insert = "type %s = "},
        {Label = "enum", Insert = "enum %s = {}"},
        {Label = "struct", Insert = "struct %s {}"},
        {Label = "event", Insert = "event %s {}"},
        {Label = "function", Insert = "function %s {}"},
        {Label = "import", Insert = "import %s as "},
        {Label = "scope", Insert = "scope %s {}"},
        {Label = "export", Insert = "export "}
    },
    Variable = {},
    Primitive = PRIMITIVES
}

local BRACKETS = {
    OpenParentheses = true,
    CloseParentheses = true,
    OpenBraces = true,
    CloseBraces = true,
    OpenBrackets = true,
    CloseBrackets = true,
}

local RICH_TEXT_ESCAPES: {[string]: string} = {
    --["&"] = "&amp;",
    ["<"] = "&lt;",
    [">"] = "&gt;",
    --["\""] = "&quot;",
    --["\'"] = "&apos;",
}

local SCROLL_LINES = 2
local CURSOR_BLINK_RATE = 0.5

type CompletionItem = {
    Icon: string,
    Label: string,
    Insert: string
}

---- Constants ----

local Editor = {}

--> Interface Instances
local Container: typeof(script.Parent.Widget) = script.Widget
local EditorContainer = Container.Editor
local CompletionContainer = Container.Completion

local TextContainer = EditorContainer.Text
local LinesContainer = EditorContainer.Lines

local Input = TextContainer.Input
local Cursor = TextContainer.Cursor
local Display = TextContainer.Display
local Selection = TextContainer.Selection
local ErrorSelection = TextContainer.Error

local ErrorContainer = Container.Error
local ErrorText = ErrorContainer.Text

local LineTemplate = LinesContainer.Line:Clone()
local ErrorTemplate = ErrorSelection.Line:Clone()
local SelectionTemplate = Selection.Line:Clone()
local CompletionTemplate = CompletionContainer.Option:Clone()

local TextSize = Input.TextSize
local TextHeight = (Input.TextSize + 3)

--> Objects
local SourceLexer = Lexer.new("Highlighting")
local SourceParser = Parser.new()

local EditorWidget: DockWidgetPluginGui;

---- Variables ----

local Lines = 0
local Scroll = State.new(0)
local Predictions: State.Class<{Index: number, Items: {CompletionItem}}> = State.new({Index = 1, Items = {}})

local CursorTimer = 0
local PreviousText = Input.Text
local PreviousLine: TextLabel?;

local AnalysisError: State.Class<Error.Class?> = State.new(nil :: any)
local AbstractSyntaxTree: Parser.Body?;

local EditorAbsoluteSize = EditorContainer.AbsoluteSize
local CursorAbsolutePosition = Cursor.AbsolutePosition

---- Private Functions ----

local function ScrollTowards(Direction: number)
    local Value = Scroll:Get()
    local Maximum = math.max(1, (Input.TextBounds.Y - EditorContainer.AbsoluteSize.Y) // TextHeight + SCROLL_LINES)
    Scroll:Set(math.clamp(Value + (Direction * SCROLL_LINES), 0, Maximum))
end

local function Color(Text: string, Color: Color3): string
    return `<font color="#{Color:ToHex()}">{Text}</font>`
end

local function Escape(Text: string)
    for Symbol, Escape in RICH_TEXT_ESCAPES do
        Text = string.gsub(Text, Symbol, Escape)
    end

    return Text
end

local function ClearChildrenWhichAre(Parent: Instance, Class: string)
    for Index, Child in Parent:GetChildren() do
        if Child:IsA(Class) then
            Child:Destroy()
        end
    end
end

local function GetPrediction(): CompletionItem?
    local Items = Predictions:Get()
    local Item = Items.Items[Items.Index]
    if not Item then
        return
    end

    return Item
end

local function UpdateColors()
    local Source = Input.Text
    local RichText = {}

    --> Initiialize lexer
    SourceLexer:Initialize(Source)

    --> Highlight state
    local Keyword = "none"
    local Token = SourceLexer:GetNextToken()
    
    while Token and (Token.Type ~= "EndOfFile") do
        local Type: Lexer.Types = Token.Type
        local Value = Token.Value

        local String = Escape(Value)
        if Type == "Keyword" or Type == "Import" or Type == "As" then
            Keyword = Value
            String = Color(Value, THEME.Keyword)
        elseif Type == "Primitive" then
            String = Color(Value, THEME.Primitive)
        elseif Type == "Identifier" then
            local LookAhead = SourceLexer:GetNextToken(true)
            local IsField = (LookAhead and LookAhead.Type == "FieldAssign" and Keyword ~= "map")
            String = Color(Value, IsField and THEME.Text or THEME.Identifier)
        elseif Type == "Array" or Type == "Range" then
            --> Exact size array/range
            local Single = string.match(Value, "%[(%d+)%]") or string.match(Value, "%((%d+)%)")
            local Lower = string.match(Value, "%[(%d+)") or string.match(Value, "%((%d+)") 
            local Upper = string.match(Value, "(%d+)%]") or string.match(Value, "(%d+)%)")

            if Single then
                String = string.gsub(Value, Single, Color(Single, THEME.Number))
            elseif Lower and Upper then
                String = `{string.sub(Value, 1, 1)}{Color(Lower, THEME.Number)}..{Color(Upper, THEME.Number)}{string.sub(Value, #Value, #Value)}`
            end
        elseif Type == "Component" then
            local Primitive = string.match(Value, "(%w+)") or ""
            String = `{Color("<", THEME.Bracket)}{Color(Primitive, THEME.Primitive)}{Color(">", THEME.Bracket)}`
        elseif BRACKETS[Type] then
            String = Color(Value, THEME.Bracket)
        elseif Type == "Class" then
            String = `({Color(string.sub(Value, 2, #Value - 1), THEME.Class)})`
        elseif Type == "String" then
            String = Color(Value, THEME.String)
        elseif Type == "Boolean" then
            String = Color(Value, THEME.Boolean)
        elseif Type == "Comment" then
            String = Color(Value, THEME.Comment)
        elseif Type == "Unknown" then
            String = Color(Value, THEME.Error)
        end

        table.insert(RichText, String)
        Token = SourceLexer:GetNextToken()
    end

    Display.Text = table.concat(RichText)
    Display.TextColor3 = THEME.Text
end

local function UpdateAnalysis()
    local Success, Result = pcall(function()
        return SourceParser:Parse(Editor.GetSource())
    end)

    if Success then
        AnalysisError:Set(nil)
        AbstractSyntaxTree = Result
    end
end

local function UpdateCompletion()
    local Line = Utility.GetLineRangeAtPosition(Input.Text, Input.CursorPosition)
    local Items: {CompletionItem} = {}

    --> Match Keywords
    local function MatchSymbols()
        local Word = Utility.GetWordRangeAtPosition(Line.Text, Input.CursorPosition - Line.Start)
        local Text = Word.Text
        if #Text == 0 then
            return
        end

        --> Match keywords
        if Word.Index == 1 then
            for _, Symbol in SYMBOLS.Keyword do
                local Label = Symbol.Label
                local Stub = string.sub(Label, 1, #Text)
                if Stub ~= Text or Stub == Label then
                    continue
                end
    
                table.insert(Items, {
                    Icon = ICONS.Keyword,
                    Label = Label,
                    Insert = Symbol.Insert
                })
            end
        end

        --> Match symbols
        local Previous = Utility.GetWordRangeBeforePosition(Line.Text, Word.Start - 1)
        if Previous.Text == "" then
            return
        end

        if string.match(Previous.Text, ":$") or Previous.Text == "=" then
            for _, Symbol in SYMBOLS.Primitive do
                local Label = Symbol.Label
                local Stub = string.sub(Label, 1, #Text)
                if Stub ~= Text or Stub == Label then
                    continue
                end
    
                table.insert(Items, {
                    Icon = ICONS.Primitive,
                    Label = Label,
                    Insert = Label
                })
            end

            if AbstractSyntaxTree then
                for Symbol in AbstractSyntaxTree.Value.Symbols do
                    local Stub = string.sub(Symbol, 1, #Text)
                    if Stub ~= Text or Stub == Symbol then
                        continue
                    end
            
                    table.insert(Items, {
                        Icon = ICONS.Variable,
                        Label = Symbol,
                        Insert = Symbol
                    })
                end
            end
        end
    end

    MatchSymbols()

    --> Update predictions
    Predictions:Set({
        Index = 1,
        Items = Items
    })
end

local function UpdateHighlightedLine()
    local Line = Utility.GetCurrentLine(Input.Text, Input.CursorPosition)
    local Label: TextLabel = LinesContainer[tostring(Line)]

    if PreviousLine then
        PreviousLine.TextColor3 = THEME.Line.Inactive
    end

    PreviousLine = Label
    Label.TextColor3 = THEME.Line.Active
end

---- Event Functions -----

local function OnErrorEmitted(Object: Error.Class)
    AnalysisError:Set(Object)
end

local function OnPreRender(DeltaTime: number)
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

--> State functions
local function OnLinesChanged(Value: number)
    --> Insert new or delete lines
    local Difference = (Value - Lines)

    if Difference > 0 then
        for Index = (Lines + 1), Value do
            local Name = tostring(Index)
            local Line = LinesContainer[Name]
            Line.TextTransparency = 0
        end
    elseif Difference < 0 then
        for Index = Lines, (Value + 1), - 1 do
            local Name = tostring(Index)
            local Line = LinesContainer[Name]
            Line.TextTransparency = 1
        end
    end

    Lines = Value

    --> Update highlighted line
    UpdateHighlightedLine()
end

local function OnScrollChanged(Value: number)
    EditorContainer.Position = UDim2.fromOffset(EditorContainer.Position.X.Offset, TextHeight * -Value)
end

local function OnPredictionsChanged()
    local Value = Predictions:Get()
    local Items = Value.Items
    if #Items == 0 then
        CompletionContainer.Visible = false
        return
    end

    CompletionContainer.Visible = true
    ClearChildrenWhichAre(CompletionContainer, "Frame")

    for Index, Item in Items do
        local Frame = CompletionTemplate:Clone()
        Frame.Icon.Image = Item.Icon
        Frame.Text.Text = Item.Label

        if Index == Value.Index then
            Frame.BackgroundColor3 = THEME.Complete
        end

        Frame.Parent = CompletionContainer
    end
end

local function OnAnalysisErrorChanged()
    local Error = AnalysisError:Get()

    --> Clear previous error
    ErrorContainer.Visible = false
    ClearChildrenWhichAre(ErrorSelection, "Frame")
    
    --> No errors
    if not Error then
        return
    end

    local Labels = Error.Labels
    if #Labels == 0 then
        return
    end

    --> Error message
    local Message = `{Error.GetNameFromCode(Error.Code)}: {Error.RawMessage} <font transparency="0.5"><i>Blink({Error.Code})</i></font>`
    for _, Label in Labels do
        local Line = Utility.GetCurrentLine(Input.Text, Label.Span.Start)
        Message ..= `\n{Label.Text} [L{Line}]`
    end

    ErrorText.Text = Message

    --> Highlight error
    local Primary = Labels[#Labels]

    local Span = Primary.Span
    local Start = Span.Start
    local Finish = Span.End

    local Text = string.sub(Input.ContentText, 1, Finish)
    local Slices = string.split(Text, "\n")

    local Offset = 0
    for Index, Slice in Slices do
        local First = Offset
        Offset += (#Slice + 1)
        
        local Line = ErrorTemplate:Clone()
        local Fill = Line.Fill

        if Offset < Start then
            Line.Fill.MaxVisibleGraphemes = 0
            Line.Parent = ErrorSelection
            continue
        end

        --> Calculate selection bounds
        local Substring = Slice
        if First < Start then
            Substring = string.sub(Slice, (Start - First), #Slice)
        elseif Index == #Slices then
            Substring = string.sub(Slice, 1, math.max(1, Finish - First))
        end

        --> Empty lines should appear as one space thick selections
        if Substring == "" then
            Substring = " "
        end
            
        local SelectionBoundsParams = Instance.new("GetTextBoundsParams")
        SelectionBoundsParams.Text = Substring
        SelectionBoundsParams.Size = TextSize
        SelectionBoundsParams.Font = Display.FontFace
        
        local SelectionBounds = TextService:GetTextBoundsAsync(SelectionBoundsParams)
        Fill.Size = UDim2.new(0, SelectionBounds.X, 1, 0)

        --> Calculate selection offset
        if Start > First then
            local Prefix = string.sub(Slice, 1, (Start - First) - 1)
            if Prefix ~= "" then
                local OffsetBoundsParams = Instance.new("GetTextBoundsParams")
                OffsetBoundsParams.Text = Prefix
                OffsetBoundsParams.Size = TextSize
                OffsetBoundsParams.Font = Input.FontFace

                local OffsetBounds = TextService:GetTextBoundsAsync(OffsetBoundsParams)
                Fill.Position = UDim2.new(0, OffsetBounds.X, 0, 10)
            end
        end

        Line.MouseEnter:Connect(function()
            local Position = EditorWidget:GetRelativeMousePosition()
            ErrorContainer.Visible = true
            ErrorContainer.Position = UDim2.fromOffset(Position.X + 4, Position.Y)
        end)

        Line.MouseLeave:Connect(function()
            ErrorContainer.Visible = false
        end)

        Line.Fill.MaxVisibleGraphemes = #Substring
        Line.Parent = ErrorSelection

        break
    end
end

--> RBXScriptSignal functions

local function OnCursorPositionChanged()
    local CursorPosition = Input.CursorPosition
    if CursorPosition == -1 then
        Cursor.Visible = false
        return
    end

    Profiler.profileBegin("Cursor")
    Profiler.profileBegin("Slice")

    local Text = string.sub(Input.Text, 1, CursorPosition - 1)
    local Slices = string.split(Text, "\n")

    Profiler.profileEnd()

    --> Calculate current end line position
    Profiler.profileBegin("BoundsParams")

    local Line = Slices[#Slices] or ""
    local GetTextBoundsParams = Instance.new("GetTextBoundsParams")
    GetTextBoundsParams.Text = Line
    GetTextBoundsParams.Size = TextSize
    GetTextBoundsParams.Font = Display.FontFace

    local TextBounds = TextService:GetTextBoundsAsync(GetTextBoundsParams)

    Profiler.profileEnd()

    --> Update cursor size and position
    Cursor.Size = UDim2.fromOffset(2, TextSize)
    Cursor.Position = UDim2.fromOffset(TextBounds.X - 1, TextHeight * (#Slices - 1))

    --> Update highlighted line
    Profiler.profileBegin("Highlight line")
    UpdateHighlightedLine()
    Profiler.profileEnd()

    --> Update completion position
    Profiler.profileBegin("Position")

    local HorisontalWidth = math.max(0, (EditorAbsoluteSize.X - CompletionContainer.Size.X.Offset) - 10)
    CompletionContainer.Position = UDim2.fromOffset(
        math.clamp(CursorAbsolutePosition.X, 0, HorisontalWidth), 
        CursorAbsolutePosition.Y + TextSize
    )

    Profiler.profileEnd()

    Profiler.profileEnd()
end

local function OnSelectionChanged()
    --> Clear previous selection
    ClearChildrenWhichAre(Selection, "Frame")

    --> Nothing is selected
    local CursorPosition = Input.CursorPosition
    local SelectionStart = Input.SelectionStart
    if CursorPosition == -1 or SelectionStart == -1 then
        return
    end

    local Start = math.min(CursorPosition, SelectionStart)
    local Finish = math.max(CursorPosition, SelectionStart)

    local Text = string.sub(Input.ContentText, 1, Finish - 1)
    local Slices = string.split(Text, "\n")

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

        --> Calculate selection bounds
        local Substring = Slice
        if First < Start then
            Substring = string.sub(Slice, (Start - First), #Slice)
        elseif Index == #Slices then
            Substring = string.sub(Slice, 1, math.max(1, Finish - First))
        end

        --> Empty lines should appear as one space thick selections
        if Substring == "" then
            Substring = " "
        end
            
        local SelectionBoundsParams = Instance.new("GetTextBoundsParams")
        SelectionBoundsParams.Text = Substring
        SelectionBoundsParams.Size = TextSize
        SelectionBoundsParams.Font = Display.FontFace
        
        local SelectionBounds = TextService:GetTextBoundsAsync(SelectionBoundsParams)
        Fill.Size = UDim2.new(0, SelectionBounds.X, 1, 0)

        --> Calculate selection offset
        if Start > First then
            local Prefix = string.sub(Slice, 1, (Start - First) - 1)
            if Prefix ~= "" then
                local OffsetBoundsParams = Instance.new("GetTextBoundsParams")
                OffsetBoundsParams.Text = Prefix
                OffsetBoundsParams.Size = TextSize
                OffsetBoundsParams.Font = Display.FontFace

                local OffsetBounds = TextService:GetTextBoundsAsync(OffsetBoundsParams)
                Fill.Position = UDim2.new(0, OffsetBounds.X, 0, 0)
            end
        end

        Line.Parent = Selection
    end
end

local function OnSourceChanged()
    --> Pressing enter inserts a carriage return (ROBLOX please fix)
    local Text = Input.Text
    local Gain = math.sign(#Text - #PreviousText)

    local NoReturnCarriage = string.gsub(Text, "\r", "")
    if NoReturnCarriage ~= Text then
        Input.Text = NoReturnCarriage
        return
    end

    --> Auto complete
    if Gain == 1 then
        Profiler.profileBegin("Insertion")

        local Item = GetPrediction()
        local Cursor = (Input.CursorPosition - 1)
        local Character = string.sub(Text, Cursor, Cursor)

        if Item and Character == "\t" then
            local Insert = Item.Insert
            local Offset = (#Insert + 1)

            local Start, End = string.find(Insert, "%s", 1, true)
            if Start and End then
                Offset = Start
                Insert = string.sub(Insert, 1, Start - 1) .. string.sub(Insert, End + 1)
            end
            
            --> Move cursor behind tab character
            Cursor -= 1

            local Line = Utility.GetLineRangeAtPosition(Text, Cursor)
            local Position = (Cursor - Line.Start + 1)

            local Word = Utility.GetWordRangeAtPosition(Line.Text, Position)
            local Length = #Word.Text

            Cursor -= Length
            
            --> Match characters before replacement and after tab (2)
            Text = (string.sub(Text, 1, Cursor) .. Insert .. string.sub(Text, Cursor + Length + 2))

            PreviousText = Text
            Input.Text = Text

            Input.CursorPosition = -1
            Input.CursorPosition = (Cursor + Offset)

            Profiler.profileEnd()
            return
        end

        Profiler.profileEnd()
    end

    --> Run styling hooks
    Profiler.profileBegin("Styling")

    local FinalText, FinalCursor = Text, Input.CursorPosition
    for Index, Hook in StylingHooks do
        FinalText, FinalCursor = Hook.OnSourceChanged(FinalText, PreviousText, FinalCursor, Gain)
    end

    Profiler.profileEnd()

    --> Update previous text
    PreviousText = FinalText

    --> If a styling hook altered the final text then don't do any additional work
    if FinalText ~= Text then
        Input.Text = FinalText
        Input.CursorPosition = FinalCursor

        return
    end

    --> Update line counter
    Profiler.profileBegin("Line counter")

    local Slices = string.split(Text, "\n")
    if #Slices ~= Lines then
        OnLinesChanged(#Slices)
    end

    Profiler.profileEnd()

    --> Perform lexer pass
    Profiler.profileBegin("Analysis")
    UpdateAnalysis()
    Profiler.profileEnd()

    Profiler.profileBegin("Completion")
    UpdateCompletion()
    Profiler.profileEnd()

    Profiler.profileBegin("Highlighting")
    UpdateColors()
    Profiler.profileEnd()
end

--> Create lines in the background
local function GenerateLinesAsync()
    local Tick = os.clock()
    for Index = 1, 2_000 do
        local Elapsed = (os.clock() - Tick)
        if Elapsed > (1 / 120) then
            task.wait()
            Tick = os.clock()
        end

        local Line = LineTemplate:Clone()
        Line.Name = tostring(Index)
        Line.Text = tostring(Index)
        Line.TextColor3 = THEME.Line.Inactive
        Line.TextTransparency = 1
        Line.Position = UDim2.fromOffset(0, 19 * (Index - 1))
        Line.Parent = LinesContainer
    end
end

---- Public Functions ----

function Editor.GetSource(): string
    return Input.Text
end

function Editor.SetSource(Source: string)
    Scroll:Set(0)
    Input.Text = Source
end

---- Initialization ----

function Editor.Initialize(Widget: DockWidgetPluginGui)
    EditorWidget = Widget
    task.spawn(GenerateLinesAsync)

    --> Preload fira sans
    ContentProvider:PreloadAsync({Display}, function(AssetId: string, AssetFetchStatus: Enum.AssetFetchStatus) 
        if AssetId ~= "" and AssetFetchStatus ~= Enum.AssetFetchStatus.Success then
            warn("[BLINK] There was an issue preloading the editors font.")
        end
    end)

    --> Remove templates
    Selection.Line:Destroy()
    ErrorSelection.Line:Destroy()
    LinesContainer.Line:Destroy()
    CompletionContainer.Option:Destroy()

    --> Sort auto complete symbols
    for _, Symbols in SYMBOLS do
        table.sort(Symbols, function(a, b)
            return #a.Label < #b.Label
        end)
    end

    --> Connections
    Error.OnEmit = OnErrorEmitted

    Scroll:OnChange(OnScrollChanged)
    Predictions:OnChange(OnPredictionsChanged)
    AnalysisError:OnChange(OnAnalysisErrorChanged)

    Input:GetPropertyChangedSignal("Text"):Connect(function()
        Profiler.profileBegin("Total")
        OnSourceChanged()
        Profiler.profileEnd()
    end)

    Cursor:GetPropertyChangedSignal("AbsolutePosition"):Connect(function()
        CursorAbsolutePosition = Cursor.AbsolutePosition
    end)

    EditorContainer:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
        EditorAbsoluteSize = EditorContainer.AbsoluteSize
    end)

    Input:GetPropertyChangedSignal("SelectionStart"):Connect(OnSelectionChanged)
    Input:GetPropertyChangedSignal("CursorPosition"):Connect(OnSelectionChanged)
    Input:GetPropertyChangedSignal("CursorPosition"):Connect(OnCursorPositionChanged)
    Input.InputChanged:Connect(function(InputObject)
        if InputObject.UserInputType == Enum.UserInputType.MouseWheel then
            ScrollTowards(-InputObject.Position.Z)
        end
    end)

    RunService.PreRender:Connect(OnPreRender)
end

---- Connections ----

return Editor