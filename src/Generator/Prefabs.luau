--!native
--!optimize 2

local Parser = require("../Parser")
local Builder = require("../Modules/Builder")

type Reader = (Variable: string, Range: NumberRange?) -> string
type Writer = (Value: string, Range: NumberRange?) -> string
type Generate = (Declaration: Parser.TypeDeclaration, Value: string?) -> (string, string)

type TypePrefab = {
	Read: Reader,
	Write: Writer,
}

type AssertPrefab = {
	Lower: string,
	Upper: string,
	Exact: string?
}

type AssertGenerator = ((Variable: string, Min: number, Max: number) -> AssertPrefab) & ((Variable: string, Class: string) -> AssertPrefab)

local SEND_BUFFER = "SendBuffer"
local RECIEVE_BUFFER = "RecieveBuffer"

local BYTE = 1
local SHORT = 2
local INTEGER = 4
local FLOAT = 4
local DOUBLE = 8

--> Used to catch any issues in prefab bodies
local FORBIDDEN_KEYWORDS = {
	Read = {"Allocate", SEND_BUFFER},
	Write = {"Read", RECIEVE_BUFFER}
}

local Numbers = {
	u8 = BYTE,
	i8 = BYTE,
	u16 = SHORT,
	i16 = SHORT,
	u32 = INTEGER,
	i32 = INTEGER,
	f32 = FLOAT,
	f64 = DOUBLE
}

local Types = {}
local Asserts = {
	number = function(Variable: string, Min: number, Max: number): AssertPrefab
		return {
			Lower = `if {Variable} < {Min} then error(\`Expected "{Variable}" to be larger than {Min}, got \{{Variable}} instead.\`) end`,
			Upper = `if {Variable} > {Max} then error(\`Expected "{Variable}" to be smaller than {Max}, got \{{Variable}} instead.\`) end`,
			Exact = `if {Variable} ~= {Max} then error(\`Expected "{Variable}" to be equal to {Max}, got \{{Variable}\} instead.\`)`
		}
	end,

	string = function(Variable: string, Min: number, Max: number): AssertPrefab
		return {
			Lower = `if #{Variable} < {Min} then error(\`Expected length of "{Variable}" to be larger than {Min}, got \{#{Variable}} instead.\`) end`,
			Upper = `if #{Variable} > {Max} then error(\`Expected length of "{Variable}" to be smaller than {Max}, got \{#{Variable}} instead.\`) end`,
			Exact = `if #{Variable} ~= {Max} then error(\`Expected length of "{Variable}" to equal to {Max}, got \{#{Variable}} instead.\`) end`
		}
	end,

	vector = function(Variable: string, Min: number, Max: number): AssertPrefab
		return {
			Lower = `if {Variable}.Magnitude < {Min} then error(\`Expected magnitude of "{Variable}" to be larger than {Min}, got \{{Variable}.Magnitude} instead.\`) end`,
			Upper = `if {Variable}.Magnitude > {Max} then error(\`Expected magnitude of "{Variable}" to be smaller than {Max}, got \{{Variable}.Magnitude} instead.\`) end`,
			Exact = `if {Variable}.Magnitude ~= {Max} then error(\`Expected magnitude of "{Variable}" to equal to {Max}, got \{{Variable}.Magnitude} instead.\`) end`
		}
	end,

	buffer = function(Variable: string, Min: number, Max: number): AssertPrefab
		return {
			Lower = `if buffer.len({Variable}) < {Min} then error(\`Expected size of "{Variable}" to be larger than {Min}, got \{buffer.len({Variable})} instead.\`) end`,
			Upper = `if buffer.len({Variable}) > {Max} then error(\`Expected size of "{Variable}" to be smaller than {Max}, got \{buffer.len({Variable})} instead.\`) end`,
			Exact = `if buffer.len({Variable}) ~= {Max} then error(\`Expected size of "{Variable}" to equal to {Max}, got \{buffer.len({Variable})} instead.\`) end`
		}
	end,

	Instance = function(Variable: string, Class: string): AssertPrefab
		return {
			Lower = `error("Something has gone wrong")`,
			Upper = `error("Something has gone wrong")`,
			Exact = `if typeof({Variable}) ~= "Instance" then error(\`Expected an Instance, got \{typeof({Variable})} instead.\`) end\nif not {Variable}:IsA("{Class}") then error(\`Expected an Instance of type "{Class}", got "\{{Variable}.ClassName}" instead.\`) end`,
		}
	end
}
local Structures = {
	Array = nil :: any
}
local Primitives = {}

local function GeneratePrimitivePrefab(Prefab: TypePrefab, AssertGenerator: AssertGenerator?): Generate
	return function(Declaration: Parser.TypeDeclaration, Variable: string?): (string, string)
		local Read = Builder.new()
		local Write = Builder.new()

		local Value = Declaration.Value
		local Variable = Variable or "Value"

		local Range = Value.Range
		local Array = Value.Array
		local Class = Value.Class
		local Primitive = Value.Primitive

		local Tabs = (Array and 0 or 1)
		local ReadVariable = (Array and "Item" or Variable)
		local IsVariableSize = (Range and Range.Max ~= Range.Min)

		Read.PushMultiline(Prefab.Read(Array and `local {ReadVariable}` or Variable, Range), 0, Tabs, true)
		Write.PushMultiline(Prefab.Write(Array and `{Variable}[Index]` or Variable, Range), 0, Tabs, true)

		if Range and AssertGenerator then
			local Assert = AssertGenerator(ReadVariable, Range.Min, Range.Max)
			if not IsVariableSize and Assert.Exact then
				Read.Push(Assert.Exact, 1, Tabs)
			else
				Read.Push(Assert.Lower, 1, Tabs)
				Read.Push(Assert.Upper, 1, Tabs)
			end
		elseif Primitive == "Instance" and AssertGenerator then
			local Assert = AssertGenerator(ReadVariable, Class)
			Read.PushMultiline(Assert.Exact, 0, Tabs)
		end

		if Array then
			Structures.Array(
				Variable, 
				{
					Type = "Inline",
					Read = Read.Dump(),
					Write = Write.Dump(),
				}, 
				Array, Read, Write, 1
			)
		end

		--> TODO: Move to a dedicate test
		--> Used to detect any issues with prefabs, should only run when running from source code
		if not _G.BUNDLED then
			local Dictionary = {
				Read = Read.DumpNoClear(),
				Write = Write.DumpNoClear()
			}

			for Key, Text in Dictionary do
				local Keywords = FORBIDDEN_KEYWORDS[Key]
				for _, Pattern in Keywords do
					if string.find(Text, Pattern, 0, true) then
						local Type;
						for Key, Value in Types do
							if Value == Prefab then
								Type = Key
								break
							end
						end

						error(`Forbidden keyword: "{Pattern}", found in {Key} body of {Type}.`)
					end
				end
			end
		end

		return Read.Dump(), Write.Dump()
	end
end

--> Numbers
for Index, Size in Numbers do
	Types[Index] = {
		Read = function(Variable: string): string
			return `{Variable} = buffer.read{Index}({RECIEVE_BUFFER}, Read({Size}))`
		end,
		Write = function(Value: string): string
			return `buffer.write{Index}({SEND_BUFFER}, Allocate({Size}), {Value})`
		end
	}
	Primitives[Index] = {
		Type = "number",
		Generate = GeneratePrimitivePrefab(Types[Index], Asserts.number)
	}
end

Structures.Array = function(Variable: string, Body: {Type: "Inline" | "Reference", Read: string, Write: string}, Length: NumberRange, Read: Builder.Builder, Write: Builder.Builder, Tabs: number)
	local Lower = Length.Min
	local Upper = Length.Max

	local IsInlined = (Body.Type == "Inline")
	local IsVariableSize = (Lower ~= Upper)

	--> Length
	if IsVariableSize then
		Read.Push(Types.u16.Read("local Length"), 1, Tabs)
		local Assert = Asserts.number("Length", Lower, Upper)

		if IsVariableSize then
			Read.Push(Assert.Lower, 1, Tabs)
			Read.Push(Assert.Upper, 1, Tabs)
		else
			Read.Push(Assert.Exact, 1, Tabs)
		end

		Write.Push(Types.u16.Write(`#{Variable}`, Upper), 1, Tabs)
	else
		Read.Push(`local Length = {Upper}`, 1, Tabs)
	end

	--> Array
	Read.Push(`{Variable} = table.create(Length)`, 1, Tabs)

	--> Body
	if Upper > 0 then
		Read.Push(`for Index = 1, Length do`, 1, Tabs)

		if IsInlined then
			Read.PushMultiline(Body.Read, 0, Tabs + 1)
		end

		Read.Push(`table.insert({Variable}, {IsInlined and "Item" or Body.Read .. "()"})`, 1, Tabs + 1)
		Read.Push(`end`, 1, Tabs)

		if IsVariableSize then
			Write.Push(`for Index = 1, math.min(#{Variable}, {Upper}) do`, 1, Tabs)
		else
			Write.Push(`for Index = 1, {Upper} do`, 1, Tabs)
		end

		if IsInlined then
			Write.PushMultiline(Body.Write, 0, Tabs + 1)
		else
			Write.Push(`{Body.Write}({Variable}[Index])`, 1, Tabs + 1)
		end

		Write.Push("end", 1, Tabs)
	end
end

--> Boolean
do
	Types.boolean = {
		Read = function(Variable: string): string
			return `{Variable} = (buffer.readu8({RECIEVE_BUFFER}, Read({BYTE})) == 1)`
		end,
		Write = function(Value: string): string
			return `buffer.writeu8({SEND_BUFFER}, Allocate({BYTE}), {Value} and 1 or 0)`
		end
	}
	
	Primitives.boolean = {
		Type = "boolean",
		Generate = GeneratePrimitivePrefab(Types.boolean)
	}
end

--> String
do
	Types.string = {
		Read = function(Variable: string, Range: NumberRange?): string
			--> Fixed size string
			if Range and Range.Min == Range.Max then
				return `{Variable} = buffer.readstring({RECIEVE_BUFFER}, Read({Range.Min}), {Range.Min})`
			end
	
			return `{Types.u16.Read("local Length")}\n{Variable} = buffer.readstring({RECIEVE_BUFFER}, Read(Length), Length)`
		end,
		Write = function(Value: string, Range: NumberRange?): string
			if Range and Range.Min == Range.Max then
				return `buffer.writestring({SEND_BUFFER}, Allocate({Range.Min}), {Value}, {Range.Min})`
			end
			
			return `local Length = #{Value}\n{Types.u16.Write("Length")}\nbuffer.writestring({SEND_BUFFER}, Allocate(Length), {Value}, Length)`
		end
	}
	
	Primitives.string = {
		Type = "string",
		Generate = GeneratePrimitivePrefab(Types.string, Asserts.string)
	}
end

--> Vector
do
	Types.vector = {
		Read = function(Variable: string)
			return `{Variable} = Vector3.new(buffer.readf32({RECIEVE_BUFFER}, Read({FLOAT})), buffer.readf32({RECIEVE_BUFFER}, Read({FLOAT})), buffer.readf32({RECIEVE_BUFFER}, Read({FLOAT})))`
		end,
		Write = function(Value: string)
			return `local Vector = {Value}\nbuffer.writef32({SEND_BUFFER}, Allocate({FLOAT}), Vector.X)\nbuffer.writef32({SEND_BUFFER}, Allocate({FLOAT}), Vector.Y)\nbuffer.writef32({SEND_BUFFER}, Allocate({FLOAT}), Vector.Z)`
		end
	}
	
	Primitives.vector = {
		Type = "Vector3",
		Generate = GeneratePrimitivePrefab(Types.vector, Asserts.vector)
	}
end

--> Buffer
do
	Types.buffer = {
		Read = function(Variable: string, Range: NumberRange?): string
			local Read = Builder.new()
			if Range and Range.Min == Range.Max then
				Read.Push(`local Length = {Range.Min}`, 1)
			else
				Read.Push(`{Types.u16.Read("local Length")}`, 1)
			end
			
			Read.Push(`local Buffer = buffer.create(Length)`, 1, 1)
			Read.Push(`buffer.copy(Buffer, 0, {RECIEVE_BUFFER}, Read(Length))`, 1, 1)
			Read.Push(`{Variable} = Buffer`, 0, 1)

			return Read.Dump()
		end,
		Write = function(Value: string, Range: NumberRange?): string
			local Write = Builder.new()
			if Range and Range.Min == Range.Max then
				Write.Push(`local Length = {Range.Max}`, 1)
			else
				Write.Push(`local Length = buffer.len({Value})`, 1)
				Write.Push(`{Types.u16.Write("Length")}`, 1, 1)
			end
			
			Write.Push(`buffer.copy({SEND_BUFFER}, Allocate(Length), {Value}, 0, Length)`, 0, 1)
			
			return Write.Dump()
		end
	}

	Primitives.buffer = {
		Type = "buffer",
		Generate = GeneratePrimitivePrefab(Types.buffer, Asserts.buffer)
	}
end

--> CFrame
do
	Types.CFrame = {
		Read = function(Variable: string): string
			local Read = Builder.new()
			Read.Push(`local {Types.vector.Read("Position")}`, 1)
			Read.Push(`local {Types.f32.Read("rX")}`, 1)
			Read.Push(`local {Types.f32.Read("rY")}`, 1)
			Read.Push(`local {Types.f32.Read("rZ")}`, 1)
			Read.Push(`{Variable} = CFrame.new(Position) * CFrame.fromOrientation(rX, rY, rZ)`, 0)
			return Read.Dump()
		end,
		Write = function(Value: string): string
			local Write = Builder.new()
			Write.Push(Types.vector.Write(`{Value}.Position`), 1)
			Write.Push(`local rX, rY, rZ = {Value}:ToOrientation()`, 1)
			Write.Push(Types.f32.Write("rX"), 1)
			Write.Push(Types.f32.Write("rY"), 1)
			Write.Push(Types.f32.Write("rZ"), 0)
			return Write.Dump()
		end
	}

	Primitives.CFrame = {
		Type = "CFrame",
		Generate = GeneratePrimitivePrefab(Types.CFrame)
	}
end

--> Color3
do
	Types.Color3 = {
		Read = function(Variable: string)
			return `{Variable} = Color3.new(buffer.readu8({RECIEVE_BUFFER}, Read({BYTE})), buffer.readu8({RECIEVE_BUFFER}, Read({BYTE})), buffer.readu8({RECIEVE_BUFFER}, Read({BYTE})))`
		end,
		Write = function(Value: string)
			return `local Color = {Value}\nbuffer.writeu8({SEND_BUFFER}, Allocate({BYTE}), Color.R * 8)\nbuffer.writeu8({SEND_BUFFER}, Allocate({BYTE}), Color.G * 8)\nbuffer.writeu8({SEND_BUFFER}, Allocate({BYTE}), Color.B * 8)`
		end
	}
	
	Primitives.Color3 = {
		Type = "Color3",
		Generate = GeneratePrimitivePrefab(Types.Color3)
	}
end

--> Instance
do
	Types.Instance = {
		Read = function(Variable: string)
			return `RecieveInstanceCursor += 1\n{Variable} = RecieveInstances[RecieveInstanceCursor]`
		end,
		Write = function(Value: string)
			return `table.insert(SendInstances, {Value})`
		end,
	}

	Primitives.Instance = {
		Type = function(Declaration)
			return Declaration.Value.Class
		end,
		Generate = GeneratePrimitivePrefab(Types.Instance, Asserts.Instance)
	}
end

return {
	Types = Types,
	Asserts = Asserts,
	Primitives = Primitives,
	Structures = Structures
}