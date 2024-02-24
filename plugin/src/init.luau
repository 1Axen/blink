--!strict

-- ******************************* --
-- 			AX3NX / AXEN		   --
-- ******************************* --

---- Services ----

local ServerStorage = game:GetService("ServerStorage")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local TextService = game:GetService("TextService")
local RunService = game:GetService("RunService")
local Selection = game:GetService("Selection")

---- Imports ----

local State = require("./State")
local Lexer = require("../../src/Lexer")
local Parser = require("../../src/Parser")
local Generator = require("../../src/Generator")

---- Settings ----

type A = {
    Identifier: number,
}

local EDITOR_COLORS = {
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
}

local FILES_FOLDER = "BLINK_CONFIGURATION_FILES"
local TEMPLATE_FILE = {
    Name = "Template",
    Source = [[type Example = u8
event MyEvent = {
    From = Server,
    Type = Reliable,
    Call = SingleSync,
    Data = Example
}]]
}

local ERROR_WIDGET = DockWidgetPluginGuiInfo.new(
    Enum.InitialDockState.Float,
    false,
    true,
    500,
    240,
    300,
    240
)

local EDITOR_WIDGET = DockWidgetPluginGuiInfo.new(
    Enum.InitialDockState.Left,
    false,
    false,
    360,
    400,
    300,
    400
)

local SAVE_COLOR = Color3.fromRGB(0, 100, 0)
local BUTTON_COLOR = Color3.fromRGB(30, 30, 30)
local EXPAND_TWEEN = TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut)

local SCROLL_LINES = 2
local CURSOR_BLINK_RATE = 0.5

local FIELDS_TYPES = {
    struct = true,
    event = true,
    ["function"] = true,
}

local BRACKETS_TYPES = {
    OpenBrackets = true,
    CloseBrackets = true,
    OpenCurlyBrackets = true,
    CloseCurlyBrackets = true,
    OpenSquareBrackets = true,
    CloseSquareBrackets = true
}

---- Constants ----

local Toolbar = plugin:CreateToolbar("Blink Suite")
local EditorButton = Toolbar:CreateButton("Editor", "Opens the configuration editor", "rbxassetid://16468561002")
EditorButton.ClickableWhenViewportHidden = true

local Template = script.Widget
local LineTemplate: TextLabel = Template.Editor.Lines.Line:Clone()
local FileTemplate = Template.Side.Content.Top.Files.File:Clone()

--> Remove templates
--Template.Editor.Text.Line:Destroy()
Template.Editor.Lines.Line:Destroy()
Template.Side.Content.Top.Files.File:Destroy()

local ErrorWidget = plugin:CreateDockWidgetPluginGui("Generation Error", ERROR_WIDGET)
ErrorWidget.Name = "Generation Error"
ErrorWidget.Title = "Error"
ErrorWidget.ZIndexBehavior = Enum.ZIndexBehavior.Sibling

local ErrorInterface = script.Error:Clone()
ErrorInterface.Parent = ErrorWidget

local ErrorText: TextLabel = ErrorInterface.Text

local EditorWidget = plugin:CreateDockWidgetPluginGui("Configuration Editor", EDITOR_WIDGET)
EditorWidget.Name = "Blink Editor"
EditorWidget.Title = "Configuration Editor"
EditorWidget.ZIndexBehavior = Enum.ZIndexBehavior.Sibling

local EditorInterface = Template:Clone()
EditorInterface.Size = UDim2.fromScale(1, 1)
EditorInterface.Parent = EditorWidget

local Side = EditorInterface.Side
local Editor = EditorInterface.Editor
local Overlay: Frame = EditorInterface.Overlay

local Content = Side.Content
local Expand: ImageButton = Side.Expand

local Top = Content.Top
local Bottom = Content.Bottom

local Files: Frame = Top.Files
local Search: TextBox = Top.Title.Search.Input

local Prompt: Frame = Bottom.Save
local Buttons = Bottom.Buttons

local GeneratePrompt: Frame = Bottom.Generate
local GenerateButtons: Frame = GeneratePrompt:FindFirstChild("Buttons") :: Frame
local Hint: TextLabel = GeneratePrompt:FindFirstChild("Hint") :: TextLabel
local Generate: TextButton = GenerateButtons:FindFirstChild("Generate") :: TextButton
local CancelGenerate: TextButton = GenerateButtons:FindFirstChild("Cancel") :: TextButton

local Input: TextBox = Prompt:FindFirstChild("Input") :: TextBox
local Save: TextButton = Buttons.Save
local Cancel: TextButton = Buttons.Cancel

local TextInput: TextBox = Editor.Text.Input
local TextCursor: Frame = Editor.Text.Cursor
local TextDisplay: TextLabel = Editor.Text.Display
local NumberLines: Frame = Editor.Lines

local TextLineHeight = (TextInput.TextSize + 3)

--> Tweens
local Tweens = {
    Editor = {
        Expand = {
            Side = TweenService:Create(Side, EXPAND_TWEEN, {Position = UDim2.new()}),
            Content = TweenService:Create(Content, EXPAND_TWEEN, {GroupTransparency = 0}),
            Overlay = TweenService:Create(Overlay, EXPAND_TWEEN, {BackgroundTransparency = 0.5}),
        },

        Retract = {
            Side = TweenService:Create(Side, EXPAND_TWEEN, {Position = Side.Position}),
            Content = TweenService:Create(Content, EXPAND_TWEEN, {GroupTransparency = 1}),
            Overlay = TweenService:Create(Overlay, EXPAND_TWEEN, {BackgroundTransparency = 1}),
        }
    }
}

local SourceLexer = Lexer.new("Highlighting")

---- Variables ----

local Saving = false
local Scroll = State.new(0)
local Expanded = State.new(false)
local Selected: State.Class<Instance?> = State.new(nil :: any)
local Generating: State.Class<StringValue?> = State.new(nil :: any)

local WasOpened = false

local Lines = 0
local Editing: string?;

local CursorTimer = 0

---- Private Functions ----

--> Interface utility functions

local function ShowError(Error: string)
    local Start = string.find(Error, "<font", 1, true)
    ErrorText.Text = string.sub(Error, Start or 1, #Error)
    ErrorWidget.Enabled = true
end

local function PlayTweens(Tweens: {[string]: Tween})
    for _, Tween in Tweens do
        Tween:Play()
    end
end

local function CreateScript(Name: string, Source: string, RunContent: Enum.RunContext, Parent: Instance)
    local Script = Instance.new("Script")
    Script.Name = Name
    Script.Source = Source
    Script.RunContext = RunContent
    Script.Parent = Parent
end

local function RequestScriptPermissions(): boolean
    local Success = pcall(function()
        local Script = Instance.new("Script", script)
        Script:Destroy()
    end)

    return Success
end

local function ClearChildrenWhichAre(Parent: Instance, Class: string)
    for Index, Child in Parent:GetChildren() do
        if Child:IsA(Class) then
            Child:Destroy()
        end
    end
end

--> Files utility functions

local function GetSaveFolder(): Folder
    local SaveFolder = ServerStorage:FindFirstChild(FILES_FOLDER)
    if not SaveFolder then
        local Folder = Instance.new("Folder")
        Folder.Name = FILES_FOLDER
        Folder.Parent = ServerStorage
        SaveFolder = Folder
    end

    return SaveFolder
end

local function GenerateFile(File: StringValue, Directory: Instance)
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
        warn("[BLINK]: File generation failed, plugin doesn't have script inject permissions.")
        return
    end

    local ServerOutput = Generator("Server", AbstractSyntaxTree, UserOptions)
    local ClientOutput = Generator("Client", AbstractSyntaxTree, UserOptions)   

    local BlinkFolder: Folder = Directory:FindFirstChild("Folder") :: Folder
    if not BlinkFolder then
        local Folder = Instance.new("Folder")
        Folder.Name = "Blink"
        Folder.Parent = Directory
        BlinkFolder = Folder
    end

    BlinkFolder:ClearAllChildren()
    CreateScript("Server", ServerOutput, Enum.RunContext.Server, BlinkFolder)
    CreateScript("Client", ClientOutput, Enum.RunContext.Client, BlinkFolder)
end

local function LoadFile(File: StringValue)
    Scroll:Set(0)
    Expanded:Set(false)
    Editing = File.Name
    TextInput.Text = File.Value
end

local function LoadFiles()
    --> Remove previous files
    Generating:Set()
    ClearChildrenWhichAre(Files, "Frame")

    --> Load new files
    local FileInstances = GetSaveFolder():GetChildren()
    table.sort(FileInstances, function(a, b)
        return a.Name < b.Name
    end)

    for _, File: StringValue in FileInstances :: {any} do
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

local function SaveFile(Name: string, Source: string)
    local SaveFolder = GetSaveFolder()
    local SaveInstance: StringValue? = SaveFolder:FindFirstChild(Name) :: StringValue
    if not SaveInstance then
        local NewSaveInstance = Instance.new("StringValue")
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
    LoadFile(GetSaveFolder():FindFirstChild(TEMPLATE_FILE.Name) :: StringValue)
end

--> Editor utility functions
local function WrapColor(Text: string, Color: Color3): string
    return `<font color="#{Color:ToHex()}">{Text}</font>`
end

local function GetEditorSource(): string
    return TextInput.ContentText
end

local function DoLexerPass()
    local Source = GetEditorSource()
    local Display = ""

    --> Initiialize lexer
    SourceLexer:Initialize(Source)

    --> Highlight state
    local Keyword = "none"
    local IsField = false
    --local IsAssigning = false
    
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

        local Type: Lexer.Types = Token.Type
        local Value = Token.Value

        if Type == "Keyword" then
            Keyword = Value
            Display ..= WrapColor(Value, EDITOR_COLORS.Keyword)
        elseif Type == "Primitive" then
            Display ..= WrapColor(Value, EDITOR_COLORS.Primitive)
        elseif Type == "Identifier" then
            Display ..= WrapColor(Value, IsField and EDITOR_COLORS.Text or EDITOR_COLORS.Identifier)
        elseif Type == "Array" or Type == "Range" then
            --> Exact size array/range
            local Single = string.match(Value, "%[(%d+)%]") or string.match(Value, "%((%d+)%)")
            if Single then
                Display ..= string.gsub(Value, Single, WrapColor(Single, EDITOR_COLORS.Number))
                continue
            end

            --> Variable size array/range
            local Lower = string.match(Value, "%[(%d+)") or string.match(Value, "%((%d+)") 
            local Upper = string.match(Value, "(%d+)%]") or string.match(Value, "(%d+)%)")
            if Lower and Upper then
                Display ..= `{string.sub(Value, 1, 1)}{WrapColor(Lower, EDITOR_COLORS.Number)}..{WrapColor(Upper, EDITOR_COLORS.Number)}{string.sub(Value, #Value, #Value)}`
                continue
            end

            Display ..= Value
        elseif BRACKETS_TYPES[Type] then
            if Type == "CloseCurlyBrackets" then
                IsField = false
            end

            Display ..= WrapColor(Value, EDITOR_COLORS.Bracket)
        elseif Type == "Class" then
            Display ..= `({WrapColor(string.sub(Value, 2, #Value - 1), EDITOR_COLORS.Class)})`
        elseif Type == "String" then
            Display ..= WrapColor(Value, EDITOR_COLORS.String)
        elseif Type == "Boolean" then
            Display ..= WrapColor(Value, EDITOR_COLORS.Boolean)
        elseif Type == "Unknown" then
            --> Reset all state
            IsField = false
            Display ..= WrapColor(Value, EDITOR_COLORS.Error)
        else
            Display ..= Value
        end

        if Type == "Whitespace" then
            continue
        end

        IsField = (Type == "Comma" or Type == "OpenCurlyBrackets") and FIELDS_TYPES[Keyword]
        --IsAssigning = (Type == "Assign") 
    end

    TextDisplay.Text = Display
end

local function ScrollEditor(Direction: number)
    local Value = Scroll:Get()
    local Maximum = math.max(1, (TextInput.TextBounds.Y - Editor.AbsoluteSize.Y) // TextLineHeight + SCROLL_LINES)
    Scroll:Set(math.clamp(Value + (Direction * SCROLL_LINES), 0, Maximum))
end

---- Public Functions ----

local function OnScroll(Value: number)
    Editor.Position = UDim2.fromOffset(Editor.Position.X.Offset, TextLineHeight * -Value)
end

local function OnSearch(PressedEnter: boolean)
    if not PressedEnter then
        return
    end

    local Query = Search.Text
    for _, Frame in Files:GetChildren() do
        if not Frame:IsA("Frame") then
            continue
        end

        if Query == "" then
            Frame.Visible = true
            continue
        end

        Frame.Visible = (string.find(Frame.Name, Query) ~= nil)
    end
end

local function OnCursorMoved()
    local CursorPosition = TextInput.CursorPosition
    if CursorPosition == -1 then
        TextCursor.Visible = false
        return
    end

    local Size = TextInput.TextSize
    local Text = string.sub(TextInput.ContentText, 1, CursorPosition - 1)
    local Slices = string.split(Text, "\n")
    local NewLines = math.max(#Slices, 1)

    --> Calculate current end line position
    local Line = Slices[#Slices] or ""
    local GetTextBoundsParams = Instance.new("GetTextBoundsParams")
    GetTextBoundsParams.Text = Line
    GetTextBoundsParams.Size = Size
    GetTextBoundsParams.Font = TextInput.FontFace
    local TextBounds = TextService:GetTextBoundsAsync(GetTextBoundsParams)

    --> Update cursor size and position
    --TextCursor.Visible = true
    TextCursor.Size = UDim2.fromOffset(2, Size)
    TextCursor.Position = UDim2.fromOffset(TextBounds.X - 1, TextLineHeight * (NewLines - 1))
end

local function OnSourceChanged()
    --> Pressing enter inserts a carriage return (ROBLOX please fix)
    local ContentText = TextInput.ContentText
    ContentText = string.gsub(ContentText, "\r", "")
    TextInput.Text = ContentText

    --> Update line counter
    local ContentLines = #string.split(ContentText, "\n")
    if ContentLines ~= Lines then
        Lines = ContentLines
        ClearChildrenWhichAre(NumberLines, "TextLabel")

        for Index = 1, Lines do
            local Line = LineTemplate:Clone()
            Line.Text = tostring(Index)
            Line.Parent = NumberLines
        end
    end

    --> Perform lexer pass
    DoLexerPass()
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
        if Name == "" then
            return
        end

        SaveFile(Name, GetEditorSource())
        LoadFiles()
        OnSaveCompleted()

        return
    end

    Saving = true
    Input.Text = Editing or ""
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

local function OnPreRender(DeltaTime: number)
    if TextInput.CursorPosition == -1 then
        return
    end

    CursorTimer += DeltaTime
    if CursorTimer < CURSOR_BLINK_RATE then
        return
    end

    CursorTimer -= CURSOR_BLINK_RATE
    TextCursor.Visible = not TextCursor.Visible
end

---- Initialization ----

---- Connections ----

Scroll:OnChange(OnScroll)

Expanded:OnChange(function(Value)
    PlayTweens(Value and Tweens.Editor.Expand or Tweens.Editor.Retract)
end)

Selected:OnChange(function(Value: Instance?)
    Generate.TextTransparency = Value and 0 or 0.5
    Hint.Text = Value 
        and `<b>Selected</b>\n{Value:GetFullName()}` 
        or "Select the location in which to generate the output scripts."
end)

Generating:OnChange(function(File: StringValue?)
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

TextInput:GetPropertyChangedSignal("Text"):Connect(OnSourceChanged)
TextInput:GetPropertyChangedSignal("CursorPosition"):Connect(OnCursorMoved)
TextInput.InputChanged:Connect(function(InputObject)
    if not Editing then
        return
    end

    if InputObject.UserInputType == Enum.UserInputType.MouseWheel then
        ScrollEditor(-InputObject.Position.Z)
    end
end)

RunService.PreRender:Connect(OnPreRender)
