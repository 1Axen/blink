type BranchType = "Conditional" | "Default"
type EqualityOperator = "Not" | "Equals" | "Greater" | "Less" | "GreaterOrEquals" | "LessOrEquals"

local Operators = {
    Not = "~=",
    Equals = "==",
    Greater = ">",
    Less = "<",
    GreaterOrEquals = ">=",
    LessOrEquals = "<=",
}

local Block = {}
Block.__index = Block

export type Block = typeof(setmetatable({} :: {
    Unique: string,
    Parent: Block?,
    Indent: number,
    Content: string,
    Reads: number,
    Allocations: number,
}, Block))

function Block.new<Parent>(Parent: Block?): Block
    local Indent = (Parent and Parent.Indent + 1 or 1)
    local Unique = `BLOCK_START`
    return setmetatable({
        Unique = Unique,
        Parent = Parent,
        Indent = Indent,
        Content = "",
        Reads = 0,
        Allocations = 0
    } :: any, Block)
end

function Block.Read(self: Block, Bytes: number): string
    local Offset = self.Reads
    self.Reads += Bytes
    return `{self.Unique} + {Offset}`
end

function Block.Allocate(self: Block, Bytes: number): string
    local Offset = self.Allocations
    self.Allocations += Bytes
    return `{self.Unique} + {Offset}`
end

function Block._lineFront(self: Block, Text: string): Block
    if self.Parent == nil then
        local Lines = string.split(self.Content, "\n")
        local First = table.remove(Lines, 1)
        self.Content = First .. `\n{string.rep("\t", self.Indent)}{Text}\n` .. table.concat(Lines, "\n")
    else
        self.Content = `{string.rep("\t", self.Indent)}{Text}\n` .. self.Content
    end

    return self
end

function Block._appendOperations(self: Block): Block
    if self.Reads > 0 then
        self:_lineFront(`local {self.Unique} = Read({self.Reads})`)
    end

    if self.Allocations > 0 then
        self:_lineFront(`local {self.Unique} = Allocate({self.Allocations})`)
    end

    return self
end

function Block.Line(self: Block, Text: string, Indent: number?, Ignore: boolean?): Block
    local Indent = Indent or self.Indent
    local NewLine = self.Content ~= "" and "\n" or ""
    self.Content ..= `{NewLine}{string.rep("\t", Indent)}{Text}`
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
    self:_appendOperations()
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
    self:_appendOperations()

    local Parent = self.Parent
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

function Function.new(Name: string, Arguments: string, Return: string?, IsInlined: boolean?): Block
    local Block = Block.new(nil)
    setmetatable(Block, Function)

    local Suffix = Return and `: {Return}` or ""
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