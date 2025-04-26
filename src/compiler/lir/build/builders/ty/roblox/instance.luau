local ty = require("@structures/ty")
local lir = require("@structures/lir")
local hir = require("@structures/hir")
local attributes = require("@config/attributes")

local fn = require("@builders/fn")
local library = require("@builders/library")
local constant = require("@builders/constant")
local condition = require("@builders/condition")

local context = require("@lir/build/context")

local types = require("../types")

type TyBuilder = types.TyBuilder
type ReadProps = types.ReadProps
type WriteProps = types.WriteProps

type Builder = fn.Builder
type Context = context.Context
type Attributes = attributes.TypeAttributes

type Instance = ty.Instance

type LValue<T> = lir.LValue<T>
type RValue<T> = lir.RValue<T>
type Register<T> = lir.RegisterId<T>

local DEFAULT_TYPE = constant.from_value("Instance")
local DEFAULT_CLASS = constant.from_value("Instance")

local function validate(ctx: Context, block: Builder, instance: Instance, value: RValue<Instance>)
    local type_cond = condition.equals(library.typeof(value :: any), DEFAULT_TYPE)
    block:if_branch(type_cond, function(block)
        block:call_lib(library.error(`Expected an Instance"`))
    end)

    local class_ty_id = instance.class
    if class_ty_id == nil then
        return
    end

    -- LUAU
    local class = hir.ty_from_id(ctx.hir, class_ty_id) :: lir.Constant<string>
    local class_cond = condition.equals(library.Instance.is_a(value :: any, class), constant.from_value(true))

    block:if_branch(class_cond, function(block)
        block:call_lib(library.error(`Expected an Instance of class "{class}"`))
    end)
end

local function build_read(props: ReadProps, block: Builder, instance: Instance): Register<Instance>
    return block:reserve()
end

local function build_write(props: WriteProps, block: Builder, instance: Instance, value: RValue<Instance>): ()
    
end

return table.freeze({
    read = build_read,
    write = build_write,
})