--!strict

local lir = require("@structures/lir")

local globals = require("./globals")
local constant = require("./constant")
local projection = require("./projection")

type BufferDataFormat = 
    | "u8" | "u16" | "u32" 
    | "i8" | "i16" | "i32"
    | "f32" | "f64"
    | "string"
;

type Axis = lir.Constant<number> | lir.RegisterId

type LValue = lir.LValue
type RValue = lir.RValue
type Register = lir.RegisterId

type Call = lir.ProjCall
type Index = lir.ProjIndex
type Field = lir.ProjField
type Namecall = lir.ProjNamecall

type Advance = lir.CtrlAdvance
type Allocate = lir.CtrlAllocate

local READ_BUFFER = globals.incoming.buffer
local WRITE_BUFFER = globals.outgoing.buffer

local function index(library: string, method: string): Index
    local library_const = constant.from_value(library)
    local method_const = constant.from_value(method)
    return projection.index(library_const, method_const)
end

local function luau_error(message: string): Call
    return projection.call(
        constant.from_value("error"),
        {constant.from_value(message) :: RValue}
    )
end

local function luau_typeof(of: LValue): Call
    return projection.call(
        constant.from_value("typeof"),
        {of :: RValue}
    )
end

local function luau_tostring(value: LValue): Call
    return projection.call(
        constant.from_value("typeof"),
        {value :: RValue}
    )
end

local function table_create(size: number): Call
    return projection.call(
        index("table", "create"), 
        {constant.from_value(size) :: RValue}
    )
end

local function vector_create(x: Axis, y: Axis, z: Axis): Call
    return projection.call(
        index("vector", "create"), 
        {x, y, z} :: {RValue}
    )
end

local function vector_magnitude(vec: lir.Id): Call
    return projection.call(
        index("vector", "create"), 
        {vec :: RValue}
    )
end

local function bit32_bor(...: RValue): Call
    return projection.call(
        index("bit32", "bor"),
        {...}
    )
end

local function bit32_lshift(x: RValue, disp: lir.Constant<number>): Call
    return projection.call(
        index("bit32", "lshift"),
        {x, disp}
    )
end

local function bit32_rshift(x: RValue, disp: lir.Constant<number>): Call
    return projection.call(
        index("bit32", "rshift"),
        {x, disp}
    )
end

local function buffer_create(size: RValue): Call
    return projection.call(
        index("buffer", "create"),
        {size}
    )
end

local function buffer_len(of: RValue): Call
    return projection.call(
        index("buffer", "len"),
        {of}
    )
end

local function buffer_copy(target: RValue, target_offset: RValue, source: RValue, source_offset: RValue?, count: RValue?): Call
    return projection.call(
        index("buffer", "copy"),
        {target, target_offset, source, source_offset, count} :: {RValue}
    )
end

local function buffer_readstring(advance: Advance, bytes: RValue): Call
    return projection.call(
        index("buffer", "readstring"),
        {READ_BUFFER, advance, bytes}
    )
end

local function buffer_writestring(allocate: Register, bytes: RValue, value: RValue): Call
    return projection.call(
        index("buffer", `writestring`),
        {WRITE_BUFFER, allocate, value, bytes}
    )
end

local function buffer_read_ctor(format: BufferDataFormat)
    return function(advance: Advance): Call
        return projection.call(
            index("buffer", `read{format}`),
            {READ_BUFFER, advance :: RValue}
        )
    end
end

local function buffer_write_ctor(format: BufferDataFormat)
    return function(allocate: Register, value: RValue): Call
        return projection.call(
            index("buffer", `write{format}`),
            {WRITE_BUFFER, allocate, value}
        )
    end
end

local function math_cos(n: lir.Constant<number> | lir.BinaryOp): Call
    return projection.call(index("math", "cos"), {n :: RValue})
end

local function math_sin(n: lir.Constant<number> | lir.BinaryOp): Call
    return projection.call(index("math", "sin"), {n :: RValue})
end

local function cframe_new_quat(
    x: RValue, 
    y: RValue, 
    z: RValue,
    quat_x: RValue,
    quat_y: RValue,
    quat_z: RValue,
    quat_w: RValue
): Call
    return projection.call(
        index("CFrame", "new"), 
        {x, y, z, quat_x, quat_y, quat_z, quat_w}
    )
end

local function cframe_to_euler_angles(at: LValue): Namecall
    return projection.namecall(
        at,
        constant.from_value("ToEulerAnglesXYZ"),
        {}
    )
end

local function color3_from_HSV(
    hue: RValue,
    sat: RValue,
    val: RValue
): Call
    return projection.call(
        index("Color3", "fromHSV"),
        {hue, sat, val}
    )
end

local function color3_to_HSV(at: LValue): Namecall
    return projection.namecall(
        at,
        constant.from_value("ToHSV"),
        {}
    )
end

local function brick_color_new(number: RValue): Call
    return projection.call(
        index("BrickColor", "new"),
        {number}
    )
end

local function date_time_new(timestamp: RValue): Call
    return projection.call(
        index("DateTime", "fromUnixTimestamp"),
        {timestamp}
    )
end

local function date_time_millis_new(timestamp_millis: RValue): Call
    return projection.call(
        index("DateTime", "fromUnixTimestampMillis"),
        {timestamp_millis}
    )
end

local function instance_is_a(at: LValue, class: lir.Constant<string>): Namecall
    return projection.namecall(
        at, 
        constant.from_value("IsA"), 
        {class :: RValue}
    )
end

-- cached library methods

return table.freeze({
    error = luau_error,
    typeof = luau_typeof,
    tostring = luau_tostring,

    math = {
        cos = math_cos,
        sin = math_sin,
    },

    bit32 = {
        bor = bit32_bor,
        lshift = bit32_lshift,
        rshift = bit32_rshift,
    },

    table = {
        create = table_create
    },

    vector = {
        create = vector_create,
        magnitude = vector_magnitude,
    },

    buffer = {
        len = buffer_len,
        copy = buffer_copy,
        create = buffer_create,
        
        u8 = {
            read = buffer_read_ctor("u8"),
            write = buffer_write_ctor("u8"),
        },
        u16 = {
            read = buffer_read_ctor("u16"),
            write = buffer_write_ctor("u16"),
        },
        u32 = {
            read = buffer_read_ctor("u32"),
            write = buffer_write_ctor("u32"),
        },
        i8 = {
            read = buffer_read_ctor("i8"),
            write = buffer_write_ctor("i8"),
        },
        i16 = {
            read = buffer_read_ctor("i16"),
            write = buffer_write_ctor("i16"),
        },
        i32 = {
            read = buffer_read_ctor("i32"),
            write = buffer_write_ctor("i32"),
        },
        f32 = {
            read = buffer_read_ctor("f32"),
            write = buffer_write_ctor("f32"),
        },
        f64 = {
            read = buffer_read_ctor("f64"),
            write = buffer_write_ctor("f64"),
        },
        string = {
            read = buffer_readstring,
            write = buffer_writestring,
        },
    },

    CFrame = {
        new_quat = cframe_new_quat,
        to_euler_angles = cframe_to_euler_angles,
    },

    Color3 = {
        from_HSV = color3_from_HSV,
        to_HSV = color3_to_HSV
    },

    BrickColor = {
        new = brick_color_new
    },

    DateTime = {
        from_timestamp = date_time_new,
        from_timestamp_millis = date_time_millis_new,
    },

    Instance = {
        is_a = instance_is_a,
    }
})