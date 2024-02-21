local Float = -27.15625

local function ToBinary(Number: number, Bits: number)
    local Binary = "" 
    for Index = Bits, 1, -1 do
        local Bit = math.fmod(Number, 2)
        Binary ..= Bit
        Number = math.floor((Number - Bit) / 2)
    end
    return string.reverse(Binary)
end

local function Float16ToUint16(Value: number): number
    local Abosulte = math.abs(Value)
    local Interval = math.ldexp(1, math.floor(math.log(Abosulte, 2)) - 10) 
    local RoundedValue = (Abosulte // Interval) * Interval

    local Fraction, Exponent = math.frexp(RoundedValue)
    Exponent += 14

    local Mantissa = math.round(if Exponent <= 0
        then Fraction * 0x400 / math.ldexp(1, math.abs(Exponent))
        else Fraction * 0x800) % 0x400

    return Mantissa
        + math.max(Exponent, 0) * 0x400
        + if Value < 0 then 0x8000 else 0
end

local function Uint16ToFloat16(Value: number): number
    local MantissaExponent = Value % 0x8000
    local Mantissa = MantissaExponent % 0x400
    local Exponent = MantissaExponent // 0x400

    local Fraction;
    if Exponent == 0 then
        Fraction = Mantissa / 0x400
    else
        Fraction = Mantissa / 0x800 + 0.5
    end

    local Result = math.ldexp(Fraction, Exponent - 14)
    return if Value // 0x8000 == 1 then -Result else Result
end

local Result = Float16ToUint16(Float)
print(Result, Uint16ToFloat16(Result), Float)