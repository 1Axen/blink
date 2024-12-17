local ty = require("@compiler/ty")
local ast = require("@compiler/ast")

export type DefId<T = Def> = number & { __T: T}

export type Type = {
    read kind: "type",
    read name: string,
    read ty: ty.TyId
} 

export type Event = {
    read kind: "event",
    read name: string,
    
}

export type Def = any

return table.freeze({})