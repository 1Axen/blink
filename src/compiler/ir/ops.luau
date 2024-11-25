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

--- read `format` `value` of `size` bytes at `offset` in buffer and store in `target` register
export type Read = {
    kind: "read",
    size: number,
    format: Format,

    offset: Register,
    target: Register,
}

--- write `format` `value` of `size` bytes at `offset` in buffer
export type Write = {
    kind: "write",
    size: number,
    format: Format,

    value: Register,
    offset: Register,
}

--- return values in registers
export type Return = {
    kind: "return",
    values: {Register}
}

return {}