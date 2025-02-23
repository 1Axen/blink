--!strict

local lir = require("@structures/lir")

local globals = require("./globals")
local constant = require("./constant")
local projection = require("./projection")

type BufferDataFormat = 
    | "u8" | "u16" | "u32" 
    | "i8" | "i16" | "i32"
    | "f32" | "f64"
;

type Axis = lir.Constant<number> | lir.RegisterId<number>

type LValue<T> = lir.LValue<T>
type RValue<T> = lir.RValue<T>
type Register<T> = lir.RegisterId<T>

type Call<T> = lir.ProjCall<T>
type Index<T> = lir.ProjIndex<T>
type Field<T> = lir.ProjField<T>
type Namecall<T> = lir.ProjNamecall<T>

type Advance = lir.CtrlAdvance<number>
type Allocate = lir.CtrlAllocate<number>

local READ_BUFFER = globals.incoming.buffer
local WRITE_BUFFER = globals.outgoing.buffer

local function index(library: string, method: string): Index<any>
    local library_const = constant.from_value(library)
    local method_const = constant.from_value(method)
    return projection.index(library_const, method_const)
end

local function luau_error(message: string): Call<nil>
    return projection.call(
        constant.from_value("error"),
        {constant.from_value(message)} :: any
    )
end

local function luau_typeof(of: RValue<any>): Call<string>
    return projection.call(
        constant.from_value("typeof"),
        {of} :: any
    )
end

local function luau_tostring(value: RValue<any>): Call<string>
    return projection.call(
        constant.from_value("typeof"),
        {value} :: any
    )
end

local function table_create(size: RValue<number>): Call<{any}>
    return projection.call(
        index("table", "create"), 
        {size} :: any
    )
end

local function vector_create(x: Axis, y: Axis, z: Axis): Call<vector>
    return projection.call(
        index("vector", "create"), 
        {x, y, z} :: {any}
    )
end

local function vector_magnitude(vec: lir.Id<vector>): Call<number>
    return projection.call(
        index("vector", "create"), 
        {vec} :: any
    )
end

local function bit32_bor(...: RValue<number>): Call<number>
    return projection.call(
        index("bit32", "bor"),
        {...} :: any
    )
end

local function bit32_lshift(x: RValue<number>, disp: lir.Constant<number>): Call<number>
    return projection.call(
        index("bit32", "lshift"),
        {x, disp} :: any
    )
end

local function bit32_rshift(x: RValue<number>, disp: lir.Constant<number>): Call<number>
    return projection.call(
        index("bit32", "rshift"),
        {x, disp} :: any
    )
end

local function buffer_create(size: RValue<number>): Call<buffer>
    return projection.call(
        index("buffer", "create"),
        {size} :: any
    )
end

local function buffer_len(of: RValue<buffer>): Call<number>
    return projection.call(
        index("buffer", "len"),
        {of} :: any
    )
end

local function buffer_copy(
    target: RValue<buffer>, 
    target_offset: RValue<number>, 
    source: RValue<buffer>, 
    source_offset: RValue<number>?, 
    count: RValue<number>?
): Call<nil>
    return projection.call(
        index("buffer", "copy"),
        {target, target_offset, source, source_offset, count} :: any
    )
end

local function buffer_readstring(
    advance: Advance, 
    bytes: RValue<number>
): Call<string>
    return projection.call(
        index("buffer", "readstring"),
        {READ_BUFFER, advance, bytes} :: any
    )
end

local function buffer_writestring(
    allocate: Register<number>, 
    bytes: RValue<number>, 
    value: RValue<string>
): Call<nil>
    return projection.call(
        index("buffer", `writestring`),
        {WRITE_BUFFER, allocate, value, bytes} :: any
    )
end

local function buffer_read_ctor(format: BufferDataFormat)
    return function(advance: Advance): Call<number>
        return projection.call(
            index("buffer", `read{format}`),
            {READ_BUFFER, advance} :: any
        )
    end
end

local function buffer_write_ctor(format: BufferDataFormat)
    return function(allocate: Register<number>, value: RValue<number>): Call<nil>
        return projection.call(
            index("buffer", `write{format}`),
            {WRITE_BUFFER, allocate, value} :: any
        )
    end
end

local function math_cos(n: lir.RValue<number>): Call<number>
    return projection.call(index("math", "cos"), {n} :: any)
end

local function math_sin(n: lir.RValue<number>): Call<number>
    return projection.call(index("math", "sin"), {n} :: any)
end

local function cframe_new_quat(
    x: RValue<number>, 
    y: RValue<number>, 
    z: RValue<number>,
    quat_x: RValue<number>,
    quat_y: RValue<number>,
    quat_z: RValue<number>,
    quat_w: RValue<number>
): Call<CFrame>
    return projection.call(
        index("CFrame", "new"), 
        {x, y, z, quat_x, quat_y, quat_z, quat_w} :: any
    )
end

local function cframe_to_axis_angle(at: RValue<CFrame>): Namecall<number>
    return projection.namecall(
        at :: LValue<any>,
        constant.from_value("ToAxisAngle"),
        {}
    ) :: Namecall<number>
end

local function color3_from_HSV(
    hue: RValue<number>,
    sat: RValue<number>,
    val: RValue<number>
): Call<Color3>
    return projection.call(
        index("Color3", "fromHSV"),
        {hue, sat, val} :: any
    )
end

local function color3_to_HSV(at: RValue<Color3>): Namecall<number>
    return projection.namecall(
        at :: LValue<any>,
        constant.from_value("ToHSV"),
        {}
    ) :: Namecall<number>
end

local function brick_color_new(number: RValue<number>): Call<BrickColor>
    return projection.call(
        index("BrickColor", "new"),
        {number} :: any
    )
end

local function date_time_new(timestamp: RValue<number>): Call<DateTime>
    return projection.call(
        index("DateTime", "fromUnixTimestamp"),
        {timestamp} :: any
    )
end

local function date_time_millis_new(timestamp_millis: RValue<number>): Call<DateTime>
    return projection.call(
        index("DateTime", "fromUnixTimestampMillis"),
        {timestamp_millis} :: any
    )
end

local function instance_is_a(at: RValue<Instance>, class: lir.Constant<string>): Namecall<boolean>
    return projection.namecall(
        at :: LValue<any>, 
        constant.from_value("IsA"), 
        {class} :: any
    ) :: Namecall<boolean>
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
        to_axis_angle = cframe_to_axis_angle,
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