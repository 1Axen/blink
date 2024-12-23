local ty = require("@compiler/types/ty")
local hir = require("@compiler/types/hir")

local fmt_ty = require("@format/ty")
local fmt_id = require("@format/id")
local fmt_types = require("@format/types")

local builder = require("@util/builder")

type Builder = builder.Builder

local function fmt_parameters(parameters: {hir.Parameter}, fmt_builder: Builder)
    builder.append(fmt_builder, "{")

    for index, parameter in parameters do
        if parameter.name then
            builder.append(fmt_builder, `{parameter.name}: `)
        end

        builder.append(fmt_builder, fmt_id(parameter.value))

        if index < #parameters then
            builder.append(fmt_builder, ", ")
        end
    end

    builder.append(fmt_builder, "}")
end

local function fmt_type(decl: hir.Type, fmt_builder: Builder)
    builder.append(fmt_builder, "Type {\n")
    builder.indent(fmt_builder)

    builder.append_line(fmt_builder, `name: {fmt_types.string(decl.name)},`)
    builder.append_line(fmt_builder, `scope: {fmt_id(decl.scope)},`)
    builder.append_line(fmt_builder, `ty: {fmt_id(decl.ty)},`)
    
    if decl.generics then
        builder.append_indent(fmt_builder)
        builder.append(fmt_builder, "generics: {")

        for index, generic in decl.generics do
            builder.append(fmt_builder, fmt_id(generic))
            
            if #decl.generics > index then
                builder.append(fmt_builder, ", ")
            end
        end

        builder.append(fmt_builder, "}\n")
    end

    builder.dedent(fmt_builder)
    builder.append_line(fmt_builder, "}")
end

local function fmt_event(decl: hir.Event, fmt_builder: Builder)
    builder.append(fmt_builder, "Event {\n")
    builder.indent(fmt_builder)

    builder.append_line(fmt_builder, `name: {decl.name}`)
    builder.append_line(fmt_builder, `from: {decl.from}`)
    builder.append_line(fmt_builder, `type: {decl.type}`)
    builder.append_line(fmt_builder, `call: {decl.call}`)
    builder.append_line(fmt_builder, `poll: {fmt_types.boolean(decl.poll)}`)

    if decl.data then
        builder.append_indent(fmt_builder)
        builder.append(fmt_builder, `data: `)
        fmt_parameters(decl.data, fmt_builder)
        builder.append(fmt_builder, "\n")
    end

    builder.dedent(fmt_builder)
    builder.append_line(fmt_builder, "}")
end

local function fmt_function(decl: hir.Function, fmt_builder: Builder)
    builder.append(fmt_builder, "Function {\n")
    builder.indent(fmt_builder)

    builder.append_line(fmt_builder, `name: {decl.name}`)
    builder.append_line(fmt_builder, `yield: {decl.yield}`)
    
    if decl.data then
        builder.append_indent(fmt_builder)
        builder.append(fmt_builder, `data: `)
        fmt_parameters(decl.data, fmt_builder)
        builder.append(fmt_builder, "\n")
    end

    if decl.ret then
        builder.append_indent(fmt_builder)
        builder.append(fmt_builder, `return: `)
        fmt_parameters(decl.ret, fmt_builder)
        builder.append(fmt_builder, "\n")
    end

    builder.dedent(fmt_builder)
    builder.append_line(fmt_builder, "}")
end

local function fmt_tys(tys: {[ty.TyId]: ty.Ty}, fmt_builder: Builder)
    builder.append_line(fmt_builder, "Tys {")
    builder.indent(fmt_builder)

    for ty_id, ty in tys do
        builder.append_indent(fmt_builder)
        builder.append_line(fmt_builder, `{fmt_id(ty_id)}: {fmt_ty(ty)}`)
    end

    builder.dedent(fmt_builder)
    builder.append_line(fmt_builder, "}")
end

local function fmt_decls(decls: {[hir.DeclId]: hir.Decl}, fmt_builder: Builder)
    builder.append_line(fmt_builder, "Decls {")
    builder.indent(fmt_builder)

    for decl_id, decl in decls do
        builder.append_indent(fmt_builder)
        builder.append(fmt_builder, fmt_id(decl_id))
        builder.append(fmt_builder, ": ")
        
        if decl.kind == "type" then
            fmt_type(decl, fmt_builder)
        elseif decl.kind == "event" then
            fmt_event(decl, fmt_builder)
        elseif decl.kind == "function" then
            fmt_function(decl, fmt_builder)
        end
    end

    builder.dedent(fmt_builder)
    builder.append_line(fmt_builder, "}")
end


local function fmt_scopes(scopes: {[hir.ScopeId]: string}, fmt_builder: Builder)
    builder.append_line(fmt_builder, "Scopes {")
    builder.indent(fmt_builder)

    for scope_id, scope_name in scopes do
        builder.append_line(fmt_builder, `{fmt_id(scope_id)}: {fmt_types.string(scope_name)}`)
    end

    builder.dedent(fmt_builder)
    builder.append_line(fmt_builder, "}")
end

local function fmt_hir(hir: hir.Hir, fmt_builder: Builder)
    fmt_tys(hir.tys, fmt_builder)
    fmt_decls(hir.decls, fmt_builder)
    fmt_scopes(hir.scopes, fmt_builder)
end

return fmt_hir