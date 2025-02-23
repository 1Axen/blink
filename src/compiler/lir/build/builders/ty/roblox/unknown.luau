local ty = require("@structures/ty")
local lir = require("@structures/lir")
local hir = require("@structures/hir")
local attributes = require("@config/attributes")

local ty_numeral = require("../luau/numeral")

local fn = require("@builders/fn")
local control = require("@builders/control")
local library = require("@builders/library")
local constant = require("@builders/constant")
local condition = require("@builders/condition")
local projection = require("@builders/projection")

local context = require("@lir/build/context")

local types = require("../types")

type TyBuilder = types.TyBuilder
type ReadProps = types.ReadProps
type WriteProps = types.WriteProps

type Builder = fn.Builder
type Context = context.Context
type Attributes = attributes.TypeAttributes

type Instance = ty.Instance

type LValue = lir.LValue
type RValue = lir.RValue
type Register = lir.RegisterId

local function build_read(props: ReadProps, block: Builder, instance: Instance): Register
    return block:store()
end

local function build_write(props: WriteProps, block: Builder, instance: Instance, value: RValue): ()
    
end

return table.freeze({
    read = build_read,
    write = build_write,
})