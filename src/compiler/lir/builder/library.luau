--!strict

local ty = require("@compiler/structures/ty")
local lir = require("@compiler/structures/lir")

local constant = require("./constant")
local projection = require("./projection")

type BufferDataFormat = 
    | "u8" | "u16" | "u32" 
    | "i8" | "i16" | "i32"
    | "f32" | "f64"
    | "string"
;

type Axis = lir.Constant<number> | lir.RegisterId

type Value = lir.Value

type Call = lir.ProjCall
type Advance = lir.CtrlAdvance
type Allocate = lir.CtrlAllocate

local function index(library: string, method: string): lir.ProjIndex
    local library_const = constant.from_value(library) :: lir.Constant<string>
    local method_const = constant.from_value(method) :: lir.Constant<string>
    return projection.index(library_const, method_const)
end

local function luau_error(message: string)
    return projection.call(
        constant.from_value("error"),
        {message}
    )
end

local function table_create(size: number)
    return projection.call(
        index("table", "create"), 
        {constant.from_value(size) :: Value}
    )
end

local function vector_create(x: Axis, y: Axis, z: Axis)
    return projection.call(
        index("vector", "create"), 
        {x, y, z} :: {any}
    )
end

local function vector_magnitude(vec: lir.RegisterId | lir.ArgumentId)
    return projection.call(
        index("vector", "create"), 
        {vec} :: {any}
    )
end

local function buffer_read_ctor(format: BufferDataFormat): (advance: Advance) -> Call
    return function(advance: Advance)
        return projection.call(
            index("buffer", `read{format}`),
            {advance} :: {Value}
        )
    end
end

local function buffer_write_ctor(format: BufferDataFormat): (allocate: Allocate) -> Call
    return function(allocate: Allocate)
        return projection.call(
            index("buffer", `write{format}`),
            {allocate} :: {Value}
        )
    end
end

local function buffer_readstring(advance: Advance, bytes: lir.LRValue): Call
    return projection.call(
        index("buffer", `write`),
        {advance, bytes} :: {Value}
    )
end

local function buffer_writestring(allocate: Allocate, bytes: lir.LRValue): Call
    return projection.call(
        index("buffer", `write`),
        {allocate, bytes} :: {Value}
    )
end

-- cached library methods

return table.freeze({
    error = luau_error,

    table = {
        create = table_create
    },

    vector = {
        create = vector_create,
        magnitude = vector_magnitude,
    },

    buffer = {
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
    }
})