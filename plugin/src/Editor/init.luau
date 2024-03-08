--!strict

-- ******************************* --
-- 			AX3NX / AXEN		   --
-- ******************************* --

---- Services ----

local TextService = game:GetService("TextService")
local RunService = game:GetService("RunService")

---- Imports ----

local Table = require("../Table")
local State = require("../State")
local Utility = require("./Utility")

local Lexer = require("../../../src/Lexer")
local Parser = require("../../../src/Parser")
local Settings = require("../../../src/Settings")

local Error = require("../../../src/Modules/Error")

local StylingHooks: {{OnSourceChanged: (Text: string, Cursor: number, Gain: number) -> (string, number)}} = {
   require("./Styling/AutoIndent"),
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

    Error = Color3.fromHex("#FF5050"),

    Complete = Color3.fromHex("#04385f"),

    Line = {
        Active = Color3.fromHex("FFFFFF"),
        Inactive = Color3.fromHex("787878")
    }
}

local SYMBOLS: {[string]: {string}} = {
    Event = {},
    Field = {},
    Snippet = {},
    Keyword = Table.GetDictionaryKeys(Settings.Keywords),
    Variable = {},
    Primitive = Table.GetDictionaryKeys(Settings.Primtives)
}

local FIELDS = {
    struct = true,
    event = true,
    ["function"] = true,
}

local BRACKETS = {
    OpenBrackets = true,
    CloseBrackets = true,
    OpenCurlyBrackets = true,
    CloseCurlyBrackets = true,
    OpenSquareBrackets = true,
    CloseSquareBrackets = true
}

local RICH_TEXT_ESCAPES: {[string]: string} = {
    ["&"] = "&amp;",
    ["<"] = "&lt;",
    [">"] = "&gt;",
    ["\""] = "&quot;",
    ["\'"] = "&apos;",
}

local SCROLL_LINES = 2
local CURSOR_BLINK_RATE = 0.5

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

local LineTemplate = LinesContainer.Line:Clone()
local SelectionTemplate = Selection.Line:Clone()
local CompletionTemplate = CompletionContainer.Option:Clone()

local TextSize = Input.TextSize
local TextHeight = (Input.TextSize + 3)

--> Objects
local SourceLexer = Lexer.new("Highlighting")
local SourceParser = Parser.new()

---- Variables ----

local Lines = State.new(0)
local Scroll = State.new(0)
local Errors: State.Class<{Error.Label}> = State.new({})

local CursorTimer = 0
local PreviousText = Input.Text
local PreviousLine: TextLabel?;

---- Private Functions ----

local function ScrollTowards(Direction: number)
    local Value = Scroll:Get()
    local Maximum = math.max(1, (Input.TextBounds.Y - EditorContainer.AbsoluteSize.Y) // TextHeight + SCROLL_LINES)
    Scroll:Set(math.clamp(Value + (Direction * SCROLL_LINES), 0, Maximum))
end

local function WrapColor(Text: string, Color: Color3): string
    --> Escape rich text
    for Symbol, Escape in RICH_TEXT_ESCAPES do
        Text = string.gsub(Text, Symbol, Escape)
    end

    --> Append color tags
    return `<font color="#{Color:ToHex()}">{Text}</font>`
end

local function ClearChildrenWhichAre(Parent: Instance, Class: string)
    for Index, Child in Parent:GetChildren() do
        if Child:IsA(Class) then
            Child:Destroy()
        end
    end
end

local function GetNextToken(DontAdvanceCursor: boolean?): Lexer.Token?
    local Success, Error, Token = pcall(function()
        return nil, SourceLexer:GetNextToken(DontAdvanceCursor)
    end)

    if Success then
        return Token
    else
        warn(`[BLINK]: Lexer encountered an exception, {Error}.`)
        return {
            Type = "Unknown",
            Value = "\0",
            Start = 1,
            End = 1,
        }
    end
end

local function Colorify()
    local Source = Input.Text
    local RichText = ""

    --> Initiialize lexer
    SourceLexer:Initialize(Source)

    --> Highlight state
    local Keyword = "none"
    local Token = GetNextToken()
    
    while Token do
        local Type: Lexer.Types = Token.Type
        local Value = Token.Value

        if Type == "EndOfFile" then
            break
        end

        if Type == "Keyword" then
            Keyword = Value
            RichText ..= WrapColor(Value, THEME.Keyword)
        elseif Type == "Primitive" then
            RichText ..= WrapColor(Value, THEME.Primitive)
        elseif Type == "Identifier" then
            local LookAhead = GetNextToken(true)
            local IsField = (LookAhead and LookAhead.Type == "FieldAssign" and Keyword ~= "map")
            RichText ..= WrapColor(Value, IsField and THEME.Text or THEME.Identifier)
        elseif Type == "Array" or Type == "Range" then
            --> Exact size array/range
            local Single = string.match(Value, "%[(%d+)%]") or string.match(Value, "%((%d+)%)")
            local Lower = string.match(Value, "%[(%d+)") or string.match(Value, "%((%d+)") 
            local Upper = string.match(Value, "(%d+)%]") or string.match(Value, "(%d+)%)")

            if Single then
                RichText ..= string.gsub(Value, Single, WrapColor(Single, THEME.Number))
            elseif Lower and Upper then
                RichText ..= `{string.sub(Value, 1, 1)}{WrapColor(Lower, THEME.Number)}..{WrapColor(Upper, THEME.Number)}{string.sub(Value, #Value, #Value)}`
            else
                RichText ..= Value
            end
        elseif BRACKETS[Type] then
            RichText ..= WrapColor(Value, THEME.Bracket)
        elseif Type == "Class" then
            RichText ..= `({WrapColor(string.sub(Value, 2, #Value - 1), THEME.Class)})`
        elseif Type == "String" then
            RichText ..= WrapColor(Value, THEME.String)
        elseif Type == "Boolean" then
            RichText ..= WrapColor(Value, THEME.Boolean)
        elseif Type == "Unknown" then
            RichText ..= WrapColor(Value, THEME.Error)
        else
            RichText ..= Value
        end

        Token = GetNextToken()
    end

    Display.Text = RichText
end

local function HighlightCurrentLine()
    local Line = Utility.GetCurrentLine(Input.Text, Input.CursorPosition)
    local Label: TextLabel = LinesContainer:FindFirstChild(tostring(Line))
    if not Label or Label == PreviousLine then
        return
    end

    if PreviousLine then
        PreviousLine.TextColor3 = THEME.Line.Inactive
    end

    PreviousLine = Label
    Label.TextColor3 = THEME.Line.Active
end

--[[local function DoCompletionPass()
    local Text = TextInput.ContentText
    local Lines = string.split(Text, "\n")
    local CursorPosition = TextInput.CursorPosition

    if CursorPosition == -1 then
        return
    end

    local Offset = 0
    for _, Line in Lines do
        local Start = Offset
        Offset += (#Line + 1)
        if Offset < CursorPosition then
            continue
        end
        
        local Substring = string.sub(Line, 1, math.max(1, CursorPosition - Start))
        local Words = string.split(Substring, " ")

        local Size = #Words
        local Token = Words[Size]
        local Previous = Words[Size - 1]

        print(`Token: {Token}`)

        --> Match categories
        local Items: {Prediction} = {}
        for Category, Symbols in EDITOR_AUTOCOMPLETE do
            if Token == "" then
                break
            end

            local Result: string?;
            for _, Symbol in Symbols do
                if Token == Symbol then
                    break
                end

                if string.find(Symbol, Token, 1, true) then
                    Result = Symbol
                    break
                end
            end

            --> Keywords should not follow assignment
            if Category == "Keyword" and Previous == "=" then
                continue
            end

            --> Primitives should only follow assignment
            if Category == "Primitive" and Previous ~= "=" then
                continue
            end

            if Result then
                table.insert(Items, {
                    Icon = EDITOR_ICONS[Category],
                    Prediction = Result
                })
            end

            print(`{Category}: {Result}`)
        end

        Predictions:Set({
            Item = math.min(
                Predictions:Get().Item, 
                math.max(1, #Items)
            ),
            Predictions = Items
        })

        break
    end
end]]

---- Event Functions -----

local function OnErrorEmitted(Labels)
    Errors:Set(Labels)
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
    --> Remove previous lines
    PreviousLine = nil
    ClearChildrenWhichAre(LinesContainer, "TextLabel")

    --> Insert new lines
    for Index = 1, Value do
        local Line = LineTemplate:Clone()
        Line.Name = tostring(Index)
        Line.Text = tostring(Index)
        Line.TextColor3 = THEME.Line.Inactive
        Line.Parent = LinesContainer
    end

    --> Update highlighted line
    HighlightCurrentLine()
end

local function OnScrollChanged(Value: number)
    EditorContainer.Position = UDim2.fromOffset(EditorContainer.Position.X.Offset, TextHeight * -Value)
end

--[[local function OnPredictionsChanged()
    local Value = Predictions:Get()
    if #Value.Predictions == 0 then
        Completion.Visible = false
        return
    end

    Completion.Visible = true
    ClearChildrenWhichAre(Completion, "Frame")

    for Index, Item in Value.Predictions do
        local Frame = CompletionItem:Clone()
        Frame.Icon.Image = Item.Icon
        Frame.Text.Text = Item.Prediction

        if Index == Value.Item then
            Frame.BackgroundColor3 = EDITOR_COLORS.Complete
        end

        Frame.Parent = Completion
    end
end]]

--> RBXScriptSignal functions
local function OnCursorPositionChanged()
    local CursorPosition = Input.CursorPosition
    if CursorPosition == -1 then
        Cursor.Visible = false
        return
    end

    local Text = string.sub(Input.Text, 1, CursorPosition - 1)
    local Slices = string.split(Text, "\n")

    --> Calculate current end line position
    local Line = Slices[#Slices] or ""
    local GetTextBoundsParams = Instance.new("GetTextBoundsParams")
    GetTextBoundsParams.Text = Line
    GetTextBoundsParams.Size = TextSize
    GetTextBoundsParams.Font = Input.FontFace
    local TextBounds = TextService:GetTextBoundsAsync(GetTextBoundsParams)

    --> Update cursor size and position
    Cursor.Size = UDim2.fromOffset(2, TextSize)
    Cursor.Position = UDim2.fromOffset(TextBounds.X - 1, TextHeight * (#Slices - 1))

    --> Update highlighted line
    HighlightCurrentLine()

    --> Perform auto completion pass
    --[[DoCompletionPass()

    --> Update completion position
    local AbsoluteSize = EditorInterface.AbsoluteSize
    local AbsolutePosition = TextCursor.AbsolutePosition

    Completion.Position = UDim2.fromOffset(
        math.clamp(AbsolutePosition.X, 0, (AbsoluteSize.X - Completion.Size.X.Offset) - 10), 
        AbsolutePosition.Y + TextSize
    )]]
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
        SelectionBoundsParams.Font = Input.FontFace
        
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

    PreviousText = Text

    --> Run styling hooks
    local FinalText, FinalCursor = Text, Input.CursorPosition
    for Index, Hook in StylingHooks do
        FinalText, FinalCursor = Hook.OnSourceChanged(FinalText, FinalCursor, Gain)
    end

    --> If a styling hook altered the final text then don't do any additional work
    if FinalText ~= Text then
        Input.CursorPosition = -1
        Input.Text = FinalText
        Input.CursorPosition = FinalCursor

        return
    end

    --> Update line counter
    local Slices = string.split(Text, "\n")
    if #Slices ~= Lines:Get() then
        Lines:Set(#Slices)
    end

    --> Perform lexer pass
    Colorify()
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

function Editor.Initialize()
    --> Remove templates
    Selection.Line:Destroy()
    LinesContainer.Line:Destroy()
    CompletionContainer.Option:Destroy()

    --> Sort auto complete symbols
    for _, Symbols in SYMBOLS do
        table.sort(Symbols, function(a, b)
            return #a < #b
        end)
    end

    --> Connections
    Error.OnEmit = OnErrorEmitted

    Lines:OnChange(OnLinesChanged)
    Scroll:OnChange(OnScrollChanged)

    Input:GetPropertyChangedSignal("Text"):Connect(OnSourceChanged)
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