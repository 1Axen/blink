type BranchType = "Conditional" | "Default"
type EqualityOperator = "Not" | "Equals" | "Greater" | "Less" | "GreaterOrEquals" | "LessOrEquals"

type Method = "Read" | "Allocate" | "None"
type Operation = {
    Method: Method,
    Bytes: number,
    Variable: string?
}

local DEFAULT_UNIQUE = "BLOCK_START"
local ARRAY_UNIQUE = "ARRAY_START"

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
    Content: {string},
    Operation: Operation
}, Block))

function Block.new<Parent>(Parent: Block?, Unique: string?): Block
    local Indent = (Parent and Parent.Indent + 1 or 1)
    return setmetatable({
        Unique = Unique or DEFAULT_UNIQUE,
        Parent = Parent,
        Indent = Indent,
        Content = table.create(64),
        Operation = {
            Method = "None",
            Bytes = 0
        }
    }, Block)
end

function Block._operation(self: Block, Method: Method, Bytes: number): string
    local Operation = self.Operation
    if Operation.Method ~= "None" and Operation.Method ~= Method then
        error(`Block can't both Allocate and Read`)
    end

    local Offset = Operation.Bytes
    Operation.Bytes += Bytes
    Operation.Method = Method

    if self.Unique ~= DEFAULT_UNIQUE then
        self:Comment(`{Method} {Bytes}`)
        self:Line(`local OPERATION_OFFSET = {self.Unique}`)
        self:Line(`{self.Unique} += {Bytes}`)
        return "OPERATION_OFFSET"
    end

    return `{self.Unique} + {Offset}` 
end

function Block.Read(self: Block, Bytes: number): string
    return self:_operation("Read", Bytes)
end

function Block.Allocate(self: Block, Bytes: number): string
    return self:_operation("Allocate", Bytes)
end

function Block._lineFront(self: Block, Text: string, Indent: number): Block
    local Index = 1
    if self.Parent == nil then
        Index = 2
    end

    table.insert(self.Content, Index, `{string.rep("\t", Indent or self.Indent)}{Text}\n`)

    return self
end

function Block._appendOperations(self: Block): Block
    local Operation = self.Operation
    local Variable = Operation.Variable
    if Operation.Method == "None" then
        return self
    end

    local Append = `local {self.Unique} = {Operation.Method}({Operation.Bytes}{Variable and ` * {Variable}` or ""})`
    self:_lineFront(Append, self.Unique ~= DEFAULT_UNIQUE and self.Indent - 1 or self.Indent)

    return self
end

function Block.Line(self: Block, Text: string, Indent: number?): Block
    table.insert(self.Content, `{string.rep("\t", Indent or self.Indent)}{Text}\n`)
    return self
end

function Block.Character(self: Block, Character: string): Block
    table.insert(self.Content, Character)
    return self
end

function Block.Comment(self: Block, Content: string): Block
    self:Line(`-- {Content}`)
    return self
end

function Block.Lines(self: Block, Lines: {string}, Indent: number?): Block
    local Indent = Indent or 0

    --> FAST PATH
    if Indent == 0 then
        table.move(Lines, 1, #Lines, #self.Content + 1, self.Content)
        return self
    end

    local Indentation = string.rep("\t", Indent)

    for Index, Line in Lines do
        table.insert(self.Content, `{Indentation}{Line}`)
    end

    return self
end

function Block.Multiline(self: Block, Content: string, Indent: number?): Block
    local Lines = string.split(Content, "\n")
    for Index, Line in Lines do
        table.insert(self.Content, `{string.rep("\t", Indent or 0)}{Line}\n`)
    end

    return self
end

function Block.Loop(self: Block, Counter: string, Length: string): Block
    local Loop = Block.new(self, `{ARRAY_UNIQUE}_{self.Indent}`)
    Loop:Line(`for {Counter}, {Length} do`, Loop.Indent - 1)
    Loop.Operation.Variable = Length
    return Loop
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
    self:Line(`if {Left} {Operators[Operator]} {Right} then`)
    return Block.new(self)
end

function Block.Branch(self: Block, Branch: BranchType, Left: string?, Right: string?, Operator: EqualityOperator?): Block
    local Parent = self.Parent
    assert(Parent, "Cannot branch the top level block.")

    --> Push previous branch content
    self:_appendOperations()
    Parent:Lines(self.Content)
    
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
        Parent:Lines(self.Content)
        Parent:Line("end")
        return Parent
    end

    self:Line("end", 0)
    return self
end

function Block.Wrap(self: Block, Front: string, Back: string): Block
    local First = self.Content[1]
    self.Content[1] = `{Front}{First}`

    local Last = self.Content[#self.Content]
    self.Content[#self.Content] = `{string.gsub(Last, "\n", "")}{Back}\n`

    return self
end

function Block.Unwrap(self: Block)
    return table.concat(self.Content)
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
    Block:Line(`{Signal}:Connect(function({Arguments})`, 0)
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