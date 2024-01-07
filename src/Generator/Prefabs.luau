--!native
--!optimize 2

local Builder = require("../Modules/Builder")

type Reader = (Variable: string, Range: NumberRange?) -> string
type Writer = (Value: string, Range: NumberRange?) -> string
type Generate = (Array: boolean, Range: NumberRange?, Value: string?) -> (string, string)

type TypePrefab = {
	Read: Reader,
	Write: Writer,
}

type AssertPrefab = {
	Lower: string,
	Upper: string,
	Exact: string?
}

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
	number = {
		Lower = "assert(%s >= %d)",
		Upper = "assert(%s <= %d)",
	},

	string = {
		Lower = "assert(#%s >= %d)",
		Upper = "assert(#%s <= %d)",
		Exact = "assert(#%s == %d)"
	},

	vector = {
		Lower = "assert(%s.Magnitude >= %d)",
		Upper = "assert(%s.Magnitude <= %d)",
		Exact = "assert(%s.Magnitude == %d)"
	},

	buffer = {
		Lower = "assert(buffer.len(%s) >= %d)",
		Upper = "assert(buffer.len(%s) <= %d)",
		Exact = "assert(buffer.len(%s) == %d)"
	}
}
local Primitives = {}

local function GeneratePrimitivePrefab(Prefab: TypePrefab, Assert: AssertPrefab?): Generate
	return function(Array: boolean, Range: NumberRange?, Variable: string?): (string, string)
		local Read = Builder.new()
		local Write = Builder.new()
		local Variable = Variable or "Value"

		if Array and Range then
			local Length = Range.Max
			if Range.Min ~= Range.Max then
				Read.Push(Prefab.Read("local Length"), 1, 1)

				if Assert then
					Read.Push(string.format(Assert.Lower, "Length", Range.Min), 1, 1)
					Read.Push(string.format(Assert.Upper, "Length", Range.Max), 1, 1)
				end

				Write.Push(Prefab.Write(`#{Variable}`, Range), 1, 1)
			else
				Read.Push(`local Length = {Length}`, 1, 1)
			end

			Read.Push(`{Variable} = table.create(Length)`, 1, 1)

			if Length > 0 then
				Read.Push(`for Index = 1, Length do`, 1, 1)
				Read.Push(Prefab.Read("local Item", Range), 1, 2)
				Read.Push(`table.insert({Variable}, Item)`, 1, 2)
				Read.Push(`end`, 1, 1)
			end

			Write.Push(`for _, Item in {Variable} do`, 1, 1)
			Write.Push(Prefab.Write("Item", Range), 1, 2)
			Write.Push("end", 1, 1)
		else
			Read.Push(Prefab.Read(Variable, Range), 1, 1)
			Write.Push(Prefab.Write(Variable, Range), 1, 1)

			if Range and Assert then
				if Range.Min == Range.Max and Assert.Exact then
					Read.Push(string.format(Assert.Exact, Variable, Range.Min), 1, 1)
				else
					Read.Push(string.format(Assert.Lower, Variable, Range.Min), 1, 1)
					Read.Push(string.format(Assert.Upper, Variable, Range.Max), 1, 1)
				end
			end
		end

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

--> Boolean
do
	Types.bool = {
		Read = function(Variable: string): string
			return `{Variable} = (buffer.readu8({RECIEVE_BUFFER}, Read({BYTE})) == 1)`
		end,
		Write = function(Value: string): string
			return `buffer.writeu8({SEND_BUFFER}, Allocate({BYTE}), {Value} and 1 or 0)`
		end
	}
	
	Primitives.bool = {
		Type = "boolean",
		Generate = GeneratePrimitivePrefab(Types.bool)
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
	
			return `local Length = buffer.readu16({RECIEVE_BUFFER}, Read({BYTE}))\n\t{Variable} = buffer.readstring({RECIEVE_BUFFER}, Read(Length), Length)`
		end,
		Write = function(Value: string, Range: NumberRange?): string
			if Range and Range.Min == Range.Max then
				return `buffer.writestring({SEND_BUFFER}, Allocate({Range.Min}), {Value}, {Range.Min})`
			end
			
			return `local Length = #{Value}\n\tbuffer.writeu16({SEND_BUFFER}, Allocate(Length), Length)\n\tbuffer.writestring({SEND_BUFFER}, Allocate(Length), {Value}, Length)`
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
			return `local Vector = {Value}\n\tbuffer.writef32({SEND_BUFFER}, Allocate({FLOAT}), Vector.X)\n\tbuffer.writef32({SEND_BUFFER}, Allocate({FLOAT}), Vector.Y)\n\tbuffer.writef32({SEND_BUFFER}, Allocate({FLOAT}), Vector.Z)`
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
				Read.Push(`local Length = buffer.readu16({RECIEVE_BUFFER}, Read({SHORT}))`, 1)
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
				Write.Push(`buffer.writeu16({SEND_BUFFER}, Allocate({SHORT}), Length)`, 1, 1)
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

--> CFrame
do
	Types.CFrame = {
		Read = function(Variable: string): string
			local Read = Builder.new()
			Read.Push(`local {Types.vector.Read("Position")}`, 1)
			Read.Push(`local {Types.f32.Read("rX")}`, 1, 1)
			Read.Push(`local {Types.f32.Read("rY")}`, 1, 1)
			Read.Push(`local {Types.f32.Read("rZ")}`, 1, 1)
			Read.Push(`{Variable} = CFrame.new(Position) * CFrame.fromOrientation(rX, rY, rZ)`, 0, 1)
			return Read.Dump()
		end,
		Write = function(Value: string): string
			local Write = Builder.new()
			Write.Push(Types.vector.Write(`{Value}.Position`))
			Write.Push(`local rX, rY, rZ = {Value}:ToOrientation()`, 1, 1)
			Write.Push(Types.f32.Write("rX"), 1, 1)
			Write.Push(Types.f32.Write("rY"), 1, 1)
			Write.Push(Types.f32.Write("rZ"), 0, 1)
			return Write.Dump()
		end
	}

	Primitives.CFrame = {
		Type = "CFrame",
		Generate = GeneratePrimitivePrefab(Types.CFrame)
	}
end

return {
	Types = Types,
	Asserts = Asserts,
	Primitives = Primitives
}