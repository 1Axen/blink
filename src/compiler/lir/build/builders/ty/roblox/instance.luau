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

local DEFAULT_TYPE = constant.from_value("Instance")
local DEFAULT_CLASS = constant.from_value("Instance")

local function build_read(props: ReadProps, block: Builder, instance: Instance): Register
    return block:store()
end

local function build_write(props: WriteProps, block: Builder, instance: Instance, value: RValue): ()
    
end

local function validate(ctx: Context, block: Builder, instance: Instance, at: LValue)
    local type_cond = condition.equals(library.typeof(at), DEFAULT_TYPE)
    block:if_branch(type_cond, function(block)
        block:call_lib(library.error(`Expected an Instance"`))
    end)

    local class_ty_id = instance.class
    if class_ty_id == nil then
        return
    end

    -- LUAU
    local class = hir.ty_from_id(ctx.hir, class_ty_id) :: lir.Constant<string>
    local class_cond = condition.equals(library.Instance.is_a(at, class), constant.from_value(true))

    block:if_branch(class_cond, function(block)
        block:call_lib(library.error(`Expected an Instance of class "{class}"`))
    end)
end

return table.freeze({
    read = build_read,
    write = build_write,
})