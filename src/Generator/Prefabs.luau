--!native
--!optimize 2

local Blocks = require("./Blocks")
local Parser = require("../Parser")
local Builder = require("../Modules/Builder")

type Block = Blocks.Block
type Writer = (Value: string, Block: Block, Range: NumberRange?) -> ()
type Reader = (Variable: string, Block: Block, Range: NumberRange?) -> ()
type Generate = (Declaration: Parser.TypeDeclaration, Variable: string?, Read: Block, Write: Block) -> ()

type TypePrefab = {
	Read: Reader,
	Write: Writer,
}

type AssertPrefab = {
	Lower: string,
	Upper: string,
	Exact: string?
}

type AssertGenerator = ((Variable: string, ...any) -> AssertPrefab)

local SEND_BUFFER = "SendBuffer"
local RECIEVE_BUFFER = "RecieveBuffer"
local SEND_POSITION = "SendOffset"

local BYTE = 1
local SHORT = 2
local INTEGER = 4
local HALF_FLOAT = 2
local FLOAT = 4
local DOUBLE = 8

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
			Exact = `if (not {Variable}) or typeof({Variable}) ~= "Instance" then error(\`Expected an Instance, got \{typeof({Variable})} instead.\`) end\nif not {Variable}:IsA("{Class}") then error(\`Expected an Instance of type "{Class}", got "\{{Variable}.ClassName}" instead.\`) end`,
		}
	end,
}
local Structures = {
	Array = nil :: any
}
local Primitives: {[string]: {
	Type: string | (Declaration: Parser.TypeDeclaration) -> string,
	Generate: Generate
}} = {}

local function GeneratePrimitivePrefab(Prefab: TypePrefab, AssertGenerator: AssertGenerator?): Generate
	return function(Declaration: Parser.TypeDeclaration, Variable: string?, Read: Block, Write: Block)
		local Value = Declaration.Value
		local Variable = Variable or "Value"

		local Range = Value.Range
		local Array = Value.Array
		local Class = Value.Class
		local Primitive = Value.Primitive

		local ReadVariable = (Array and "Item" or Variable)
		local WriteVariable = (Array and `{Variable}[Index]` or Variable)
		local IsVariableSize = (Range and Range.Max ~= Range.Min)

		local function GenerateValidation(Block: Block, Variable: string)
			if not AssertGenerator then
				return
			end

			if Range then
				local Assert = AssertGenerator(Variable, Range.Min, Range.Max)
				if not IsVariableSize and Assert.Exact then
					Block:Line(Assert.Exact)
				else
					Block:Line(Assert.Lower)
					Block:Line(Assert.Upper)
				end
			elseif Primitive == "Instance" then
				local Assert = AssertGenerator(Variable, Class)
				if Value.Optional and Block == Write then
					Block:Compare(Variable, "nil", "Not")
						:Multiline(Assert.Exact, Block.Indent + 1)
					:End()
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

local function GenerateNumberGenerator(Type: string, Size: number): (TypePrefab, {Type: string, Generate: Generate})
	local Prefab = {
		Read = function(Variable: string, Block: Block)
			Block:Line(`{Variable} = buffer.read{Type}({RECIEVE_BUFFER}, {Block:Read(Size)})`)
		end,
		Write = function(Value: string, Block: Block)
			Block:Line(`buffer.write{Type}({SEND_BUFFER}, {Block:Allocate(Size)}, {Value})`)
		end
	}

	local Primitive = {
		Type = "number",
		Generate = GeneratePrimitivePrefab(Prefab, Asserts.number)
	}

	return Prefab, Primitive
end

--> Numbers
Types.u8, Primitives.u8 = GenerateNumberGenerator("u8", BYTE)
Types.u16, Primitives.u16 = GenerateNumberGenerator("u16", SHORT)
Types.u32, Primitives.u32 = GenerateNumberGenerator("u32", INTEGER)

Types.i8, Primitives.i8 = GenerateNumberGenerator("i8", BYTE)
Types.i16, Primitives.i16 = GenerateNumberGenerator("i16", SHORT)
Types.i32, Primitives.i32 = GenerateNumberGenerator("i32", INTEGER)

Types.f32, Primitives.f32 = GenerateNumberGenerator("f32", FLOAT)
Types.f64, Primitives.f64 = GenerateNumberGenerator("f64", DOUBLE)

Types.f16 = {
	Read = function(Variable: string, Block: Block)
		Types.u16.Read("local Encoded", Block)
		Block:Line(`local MantissaExponent = Encoded % 0x8000`)
		Block:Compare("MantissaExponent", "0b0_11111_0000000000 ", "Equals")
			:Compare("Encoded // 0x8000", "1", "Equals")
				:Line(`{Variable} = -math.huge`)
			:Branch("Default")
				:Line(`{Variable} = math.huge`)
			:End()
		:Branch("Conditional", "MantissaExponent", "0b1_11111_0000000000  ", "Equals")
			:Line(`{Variable} = 0 / 0`)
		:Branch("Conditional", "MantissaExponent", "0b0_00000_0000000000  ", "Equals")
			:Line(`{Variable} = 0`)
		:Branch("Default")
			:Multiline([[local Mantissa = MantissaExponent % 0x400
local Exponent = MantissaExponent // 0x400
	
local Fraction;
if Exponent == 0 then
	Fraction = Mantissa / 0x400
else
	Fraction = Mantissa / 0x800 + 0.5
end
	
local Result = math.ldexp(Fraction, Exponent - 14)]], Block.Indent + 1)
			:Line(`{Variable} = if Encoded // 0x8000 == 1 then -Result else Result`)
		:End()
	end,
	Write = function(Value: string, Block: Block)
		local Allocation = Block:Allocate(HALF_FLOAT)
		Block:Compare(Value, "65504", "Greater")
			:Line(`buffer.writeu16({SEND_BUFFER}, {Allocation}, 0b0_11111_0000000000)`)
		:Branch("Conditional", Value, "-65504", "Less")
			:Line(`buffer.writeu16({SEND_BUFFER}, {Allocation}, 0b1_11111_0000000000)`)
		:Branch("Conditional", Value, Value, "Not")
			:Line(`buffer.writeu16({SEND_BUFFER}, {Allocation}, 0b1_11111_0000000001)`)
		:Branch("Conditional", Value, "0", "Equals")
			:Line(`buffer.writeu16({SEND_BUFFER}, {Allocation}, 0)`)
		:Branch("Default")
			:Line(`local float = {Value}`)
			:Multiline([[local Abosulte = math.abs(float)
local Interval = math.ldexp(1, math.floor(math.log(Abosulte, 2)) - 10) 
local RoundedValue = (Abosulte // Interval) * Interval

local Fraction, Exponent = math.frexp(RoundedValue)
Exponent += 14

local Mantissa = math.round(if Exponent <= 0
	then Fraction * 0x400 / math.ldexp(1, math.abs(Exponent))
	else Fraction * 0x800) % 0x400

local Result = Mantissa
	+ math.max(Exponent, 0) * 0x400
	+ if float < 0 then 0x8000 else 0]], Block.Indent + 1)
			:Line(`buffer.writeu16({SEND_BUFFER}, {Allocation}, Result)`)
		:End()
	end
}

Primitives.f16 = {
	Type = "number",
	Generate = GeneratePrimitivePrefab(Types.f16, Asserts.number)
}

--> Structures
Structures.Array = function(Variable: string, Read: Block, Write: Block, Length: NumberRange): (Block, Block)
	local Lower = Length.Min
	local Upper = Length.Max
	local ReadArray, WriteArray;

	local IsVariableSize = (Lower ~= Upper)

	--> Length
	if IsVariableSize then
		Types.u16.Read("local Length", Read)
		local Assert = Asserts.number("Length", Lower, Upper)

		Read:Line(Assert.Lower)
		Read:Line(Assert.Upper)
		Types.u16.Write(`#{Variable}`, Write)
	else
		Read:Line(`local Length = {Upper}`)
	end

	--> Array
	Read:Line(`{Variable} = table.create(Length)`)

	--> Body
	ReadArray = Read:Loop("Index = 1", "Length")
	WriteArray = Write:Loop("Index = 1", IsVariableSize and `math.min(#{Variable}, {Upper})` or Upper)

	return ReadArray, WriteArray
end

--> Boolean
do
	Types.boolean = {
		Read = function(Variable: string, Block: Block)
			Block:Line(`{Variable} = (buffer.readu8({RECIEVE_BUFFER}, {Block:Read(BYTE)}) == 1)`)
		end,
		Write = function(Value: string, Block: Block)
			Block:Line(`buffer.writeu8({SEND_BUFFER}, {Block:Allocate(BYTE)}, {Value} and 1 or 0)`)
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
		Read = function(Variable: string, Block: Block, Range: NumberRange?)
			--> Fixed size string
			if Range and Range.Min == Range.Max then
				Block:Line(`{Variable} = buffer.readstring({RECIEVE_BUFFER}, {Block:Read(Range.Min)}, {Range.Min})`)
				return
			end
	
			Types.u16.Read("local Length", Block)
			Block:Line(`{Variable} = buffer.readstring({RECIEVE_BUFFER}, Read(Length), Length)`)
		end,
		Write = function(Value: string, Block: Block, Range: NumberRange?)
			if Range and Range.Min == Range.Max then
				Block:Line(`buffer.writestring({SEND_BUFFER}, {Block:Allocate(Range.Min)}, {Value}, {Range.Min})`)
			else
				Block:Line(`local Length = #{Value}`)
				Types.u16.Write("Length", Block)
				Block:Line(`Allocate(Length)`)
				Block:Line(`buffer.writestring({SEND_BUFFER}, {SEND_POSITION}, {Value}, Length)`)
			end
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
		Read = function(Variable: string, Block: Block)
			local X = Block:Read(FLOAT)
			local Y = Block:Read(FLOAT)
			local Z = Block:Read(FLOAT)
			Block:Line(`{Variable} = Vector3.new(buffer.readf32({RECIEVE_BUFFER}, {X}), buffer.readf32({RECIEVE_BUFFER}, {Y}), buffer.readf32({RECIEVE_BUFFER}, {Z}))`)
		end,
		Write = function(Value: string, Block: Block)
			Block:Line(`local Vector = {Value}`)
			Types.f32.Write("Vector.X", Block)
			Types.f32.Write("Vector.Y", Block)
			Types.f32.Write("Vector.Z", Block)
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
		Read = function(Variable: string, Block: Block, Range: NumberRange?)
			if Range and Range.Min == Range.Max then
				Block:Line(`local Length = {Range.Min}`)
			else
				Types.u16.Read("local Length", Block)
			end
			
			Block:Line(`{Variable} = buffer.create(Length)`)
			Block:Line(`buffer.copy({Variable}, 0, {RECIEVE_BUFFER}, Read(Length))`)
		end,
		Write = function(Value: string, Block: Block, Range: NumberRange?)
			if Range and Range.Min == Range.Max then
				Block:Line(`local Length = {Range.Max}`)
			else
				Block:Line(`local Length = buffer.len({Value})`)
				Types.u16.Write("Length", Block)
			end
			
			Block:Line(`Allocate(Length)`)
			Block:Line(`buffer.copy({SEND_BUFFER}, {SEND_POSITION}, {Value}, 0, Length)`)
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
		Read = function(Variable: string, Block: Block)
			Types.vector.Read("local Position", Block)
			Types.f32.Read("local rX", Block)
			Types.f32.Read("local rY", Block)
			Types.f32.Read("local rZ", Block)
			Block:Line(`{Variable} = CFrame.new(Position) * CFrame.fromOrientation(rX, rY, rZ)`)
		end,
		Write = function(Value: string, Block: Block)
			Types.vector.Write(`{Value}.Position`, Block)
			Block:Line(`local rX, rY, rZ = {Value}:ToOrientation()`)
			Types.f32.Write("rX", Block)
			Types.f32.Write("rY", Block)
			Types.f32.Write("rZ", Block)
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
		Read = function(Variable: string, Block: Block)
			local R = Block:Read(BYTE)
			local G = Block:Read(BYTE)
			local B = Block:Read(BYTE)
			Block:Line(`{Variable} = Color3.new(buffer.readu8({RECIEVE_BUFFER}, {R}), buffer.readu8({RECIEVE_BUFFER}, {G}), buffer.readu8({RECIEVE_BUFFER}, {B}))`)
		end,
		Write = function(Value: string, Block: Block)
			Block:Line(`local Color = {Value}`)
			Types.u8.Write("Color.R * 255", Block)
			Types.u8.Write("Color.G * 255", Block)
			Types.u8.Write("Color.B * 255", Block)
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
		Read = function(Variable: string, Block: Block)
			--Block:Line("RecieveInstanceCursor += 1")
			Block:Line(`{Variable} = RecieveInstances[RecieveInstanceCursor]`)
		end,
		Write = function(Value: string, Block: Block)
			Block:Line(`table.insert(SendInstances, {Value} or false :: any)`)
		end,
	}

	Primitives.Instance = {
		Type = function(Declaration)
			return Declaration.Value.Class
		end,
		Generate = GeneratePrimitivePrefab(Types.Instance, Asserts.Instance)
	}
end

--> unknown
do
	Types.unknown = {
		Read = function(Variable: string, Block: Block)
			Block:Line("RecieveInstanceCursor += 1")
			Block:Line(`{Variable} = RecieveInstances[RecieveInstanceCursor]`)
		end,
		Write = function(Value: string, Block: Block)
			Block:Line(`table.insert(SendInstances, {Value})`)
		end,
	}

	Primitives.unknown = {
		Type = "any",
		Generate = GeneratePrimitivePrefab(Types.unknown)
	}
end

return {
	Types = Types,
	Asserts = Asserts,
	Primitives = Primitives,
	Structures = Structures
}