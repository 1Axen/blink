type EqualityOperator = "Not" | "Equals" | "Greater" | "Less" | "GreaterOrEquals" | "LessOrEquals"

export type Block<Parent> = {
    Parent: Parent,
    Indent: number,
    Content: string,

    Line: (Block<Parent>, Content: string) -> Block<Parent>,
    Multiline: (Block<Parent>, Content: string) -> Block<Parent>,
    Loop: (Block<Parent>, Counter: string, Length: string) -> Block<Parent>,
    Compare: (Block<Parent>, Left: string, Right: string, Operator: EqualityOperator) -> Block<Parent>,

    End: (Block<Parent>) -> Parent,
}

export type Function = {
    Parent: nil,
    Indent: nil,

    End: (Function, Return: string?) -> string
} & Block<Function>

export type Connection = {
    Parent: nil,
    Indent: nil,
    End: (Connection) -> string
}

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

function Block.new<Parent>(Parent: Block<unknown>?): Block<Parent>
    print(`Opened a block, parent: {Parent}`)
    return setmetatable({
        Parent = Parent,
        Indent = Parent and Parent.Indent + 1 or 1,
        Content = ""
    } :: any, Block)
end

function Block.Line(self: Block<unknown>, Content: string): Block<unknown>
    local NewLine = Content ~= "" and "\n" or ""
    self.Content ..= `{NewLine}{string.rep("\t", self.Indent)}{Content}`
    return self
end

function Block.Multiline(self: Block<unknown>, Content: string): Block<unknown>
    local Lines = string.split(Content, "\n")
    for _, Line in Lines do
        self:Line(Line)
    end

    return self
end

function Block.Loop(self: Block<unknown>, Counter: string, Length: string): Block<unknown>
    self:Line(`for {Counter}, {Length} do`)
    return Block.new(self)
end

function Block.Compare(self: Block<unknown>, Left: string, Right: string, Operator: EqualityOperator): Block<unknown>
    self:Line(`if {Left} {Operators[Operator]} {Right} then`)
    return Block.new(self)
end

function Block.End(self: Block<unknown>)
    local Parent = self.Parent
    if Parent then
        Parent:Multiline(self.Content)
        Parent:Line("end")
        return Parent
    end

    return self
end

local Function = {}
Function.__index = Function
setmetatable(Function, Block)

function Function.new(Name: string, Arguments: string, Return: string): Function
    local Block = Block.new()
    setmetatable(Block, Function)
    Block.Content = `function {Name}({Arguments}): {Return}`
    return Block
end

function Function.End(self: Function, Return: string?): string
    if Return then
        self:Line(`return {Return}`)
    end

    self.Content ..= "\nend"
    return self.Content 
end

local Connection = {}
Connection.__index = Connection
setmetatable(Connection, Block)

function Connection.new(Signal: string, Arguments: string): Connection
    local Block = Block.new()
    setmetatable(Block, Connection)
    Block.Content = `{Signal}:Connect(function({Arguments})`
    return Block
end

function Connection.End(self: Function, Return: string?): string
    self.Content ..= "\nend)"
    return self.Content 
end

return {
    Block = Block.new,
    Function = Function.new,
    Connection = Connection.new
}