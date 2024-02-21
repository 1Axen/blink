local stdio = require("@lune/stdio")

local Colors: {stdio.Color} = {
    "cyan", "green", "purple", "red", "white", "yellow"
}
local ColorIndex = 0

type BranchType = "Conditional" | "Default"
type EqualityOperator = "Not" | "Equals" | "Greater" | "Less" | "GreaterOrEquals" | "LessOrEquals"

local Branches = {
    Conditional = "elseif",
    Default = "else"
}

local Operators = {
    Not = "~=",
    Equals = "==",
    Greater = ">",
    Less = "<",
    GreaterOrEquals = ">=",
    LessOrEquals = "<=",
}

local function GetConsoleColor(): stdio.Color
    ColorIndex += 1
    if ColorIndex > #Colors then
        ColorIndex = 1
    end

    return Colors[ColorIndex]
end

local function SetConsoleColor(Color: stdio.Color)
    stdio.write(stdio.color(Color))
end

local Block = {}
Block.__index = Block

export type Block = typeof(setmetatable({} :: {
    Color: stdio.Color?,
    Parent: Block?,
    Indent: number,
    Content: string
}, Block))

function Block.new<Parent>(Parent: Block?, Debug: boolean?): Block
    local Color: stdio.Color?;
    local Indent = (Parent and Parent.Indent + 1 or 1)

    if Debug or (Parent and Parent.Color) then
        Color = GetConsoleColor()
        SetConsoleColor(Color :: stdio.Color)
        print(`BLOCK {Indent}`)
    end

    return setmetatable({
        Color = Color,
        Parent = Parent,
        Indent = Indent,
        Content = ""
    } :: any, Block)
end

function Block.Line(self: Block, Content: string, Indent: number?, Ignore: boolean?): Block
    local Indent = Indent or self.Indent
    local NewLine = self.Content ~= "" and "\n" or ""

    if self.Color and not Ignore then
        print(`{string.rep("\t", Indent)}{Content} {Indent}`)
    end

    self.Content ..= `{NewLine}{string.rep("\t", Indent)}{Content}`
    return self
end

function Block.Comment(self: Block, Content: string): Block
    self:Line(`-- {Content}`)
    return self
end

function Block.Multiline(self: Block, Content: string, Indent: number?): Block
    local Lines = string.split(Content, "\n")
    for _, Line in Lines do
        --> Don't include lines that are only control characters
        local NoControlCharacters = string.gsub(Line, "%c+", "")
        if NoControlCharacters == "" then
            continue
        end

        self:Line(Line, Indent or 0, true)
    end

    return self
end

function Block.Loop(self: Block, Counter: string, Length: string): Block
    self:Line(`for {Counter}, {Length} do`)
    return Block.new(self)
end

function Block.While(self: Block, Condition: string): Block
    self:Line(`while ({Condition}) do`)
    return Block.new(self)
end

function Block.Iterator(self: Block, Key: string, Value: string, Iterator: string): Block
    self:Line(`for {Key}, {Value} in {Iterator} do`)
    return Block.new(self)
end

function Block.Compare(self: Block, Left: string, Right: string, Operator: EqualityOperator): Block
    if self.Color then
        print("COMPARE")
    end
    self:Line(`if {Left} {Operators[Operator]} {Right} then`)
    return Block.new(self)
end

function Block.Branch(self: Block, Branch: BranchType, Left: string?, Right: string?, Operator: EqualityOperator?): Block
    local Parent = self.Parent
    assert(Parent, "Cannot branch the top level block.")

    --> Push previous branch content
    Parent:Multiline(self.Content)
    
    --> Create new branch
    if Branch == "Conditional" then
        Parent:Line(`elseif {Left} {Operators[Operator]} {Right} then`)
    else
        Parent:Line(`else`)
    end

    return Block.new(Parent)
end

function Block.Return(self: Block, Return: string): Block
    self:Line(`return {Return}`)
    return self
end

function Block.End(self: Block): Block
    local Parent = self.Parent

    if self.Color then
        print(`END {self.Indent}`)
        if Parent and Parent.Color then
            SetConsoleColor(Parent.Color)
        end
    end

    if Parent then
        Parent:Multiline(self.Content)
        Parent:Line("end")
        return Parent
    end

    self:Line("end", 0)
    return self
end

function Block.Unwrap(self: Block)
    return self.Content
end

local Function = {}
Function.__index = Function
setmetatable(Function, Block)

function Function.new(Name: string, Arguments: string, Return: string, IsInlined: boolean?, Debug: boolean?): Block
    local Block = Block.new(nil, Debug)
    setmetatable(Block, Function)
    
    if IsInlined then 
        Block:Line(`{Name} = function({Arguments}): {Return}`, 0)
    else
        Block:Line(`function {Name}({Arguments}): {Return}`, 0)
    end

    return Block
end

local Connection = {}
Connection.__index = Connection
setmetatable(Connection, Block)

function Connection.new(Signal: string, Arguments: string): Block
    local Block = Block.new()
    setmetatable(Block, Connection)
    Block.Content = `{Signal}:Connect(function({Arguments})`
    return Block
end

function Connection.End(self: Block, Return: string?): Block
    self:Line("end)", 0)
    return self 
end

return {
    Block = Block.new,
    Function = Function.new,
    Connection = Connection.new
}