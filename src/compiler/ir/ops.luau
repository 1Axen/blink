export type Register = number
export type Format = "i" | "u" | "f" | "string"

--- advance buffer cursor by `size` bytes and store new cursor in `target` register
export type Advance = {
    kind: "advance",
    size: number,
    target: Register,
}

--- allocate `size` bytes in buffer and store new cursor in `target` register
export type Allocate = {
    kind: "allocate",
    size: number,
    target: Register,
}

--- read `format` `value` of static `size` bytes at `offset` in buffer and store in `target` register
export type Read = {
    kind: "read",
    size: number,
    format: Format,

    offset: Register,
    target: Register,
}

--- write `format` `value` of static `size` bytes at `offset` in buffer
export type Write = {
    kind: "write",
    size: number,
    format: Format,

    value: Register,
    offset: Register,
}

--- read `format` `value` of size in `size` register at `offset` in buffer and store in `target` register
export type Read_Dynamic = {
    kind: "read_dynamic",
    format: Format,

    size: Register,
    value: Register,
    offset: Register
}

--- write `format` `value` of size in `size` register at `offset` in buffer
export type Write_Dynamic = {
    kind: "write_dynamic",
    format: Format,

    size: Register,
    value: Register,
    offset: Register
}

export type MapLoop = {
    kind: "map_loop",
    map: Register,
}

export type ArrayLoop = {
    kind: "array_loop",
    array: Register,
}

export type FixedLoop = {
    kind: "fixed_loop",
    iterations: number,
}

--- return values in registers
export type Return = {
    kind: "return",
    values: {Register}
}

return {}