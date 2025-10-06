--!strict
--!native
--!optimize 2

local condition = require("@builders/condition")
local constant = require("@builders/constant")
local fn = require("@builders/fn")
local globals = require("@builders/globals")
local id = require("@compiler/id")

local hir = require("@hir/types")
local lir = require("@lir/types")
local ty = require("@ty/types")

local options = require("@config/options")

local builders = require("@builders/init")
local context = require("@self/context")
local library = require("@builders/library")
local prefixes = require("@config/prefixes")
local projection = require("@builders/projection")
local state = require("@builders/state")
local structure = require("@builders/structure")

local panic = require("@util/panic")

type Lir = lir.Lir
type Hir = hir.Hir

type Decl = hir.Decl
type DeclId = hir.DeclId

type Ty = ty.Ty
type TyId = ty.TyId

type Fn = lir.Fn
type FnId = lir.FnId

type Context = context.Context
type Builder = builders.Builder

local PLAYER_TY = ty.instance()

local INCOMING = globals.incoming
local OUTGOING = globals.outgoing
local RELIABLE_EVENT = globals.events.reliable
local UNRELIABLE_EVENT = globals.events.unreliable

local QUEUE_TEMPLATE = structure.struct({
	[constant.from_value("size")] = constant.zero,
	[constant.from_value("cursor")] = constant.zero,
	[constant.from_value("columns")] = structure.array({}) :: any,
})

local function options_from_decl_id(ctx: Context, decl_id: DeclId): options.FileOptions
	local file_id = id.file(decl_id)
	if file_id == nil then
		return panic(`Expected declaration to be linked to a file`)
	end

	local options = ctx.hir.options[file_id]
	if options == nil then
		return panic(`Expected file to have options`)
	end

	return options
end

local function rreturns(ctx: Context, parameters: { hir.Parameter }): { lir.Return }
	local array = {}
	for index, parameter in parameters do
		local ty = hir.ty_from_id(ctx.hir, parameter.ty_id)
		array[index] = fn.rreturn(ty)
	end
	return array
end

local function arguments(ctx: Context, parameters: { hir.Parameter }): { lir.Argument }
	local array = {}
	for index, parameter in parameters do
		local ty = hir.ty_from_id(ctx.hir, parameter.ty_id)
		array[index] = fn.argument(ty, parameter.name)
	end
	return array
end

local function trim_outgoing_buffer(block: fn.Builder): lir.RegisterId<buffer>
	local new_buffer = block:store(OUTGOING.buffer)
	block:if_branch(condition.not_equals(OUTGOING.cursor, OUTGOING.length), function()
		block:store(library.buffer.create(OUTGOING.cursor), new_buffer)
		block:call(library.buffer.copy(new_buffer, constant.zero, OUTGOING.buffer, constant.zero, OUTGOING.cursor))
	end)
	return new_buffer
end

local function copy_outgoing_buffer(block: fn.Builder): lir.RegisterId<buffer>
	local new_buffer = block:store(library.buffer.create(OUTGOING.cursor))
	block:call(library.buffer.copy(new_buffer, constant.zero, OUTGOING.buffer, constant.zero, OUTGOING.cursor))
	return new_buffer
end

local function build_type(ctx: Context, decl: hir.Type): lir.Type?
	if decl.generics then
		return nil
	end

	return {
		type = "type",
		decl = decl,
		set = builders.ty.from_ty_id(ctx, decl.attributes, decl.ty_id),
	}
end

local function build_event(ctx: Context, decl: hir.Event): lir.Event
	local id = constant.from_value(context.next_event_id(ctx, decl.type))
	local name = `{prefixes.event}{decl.id}_{decl.name}`

	local event_type = decl.type
	local is_unreliable = (event_type == "Unreliable")

	local event_data = decl.data or {}
	local data_args = arguments(ctx, event_data)
	local data_rets = rreturns(ctx, event_data)

	local data_rets_player = table.clone(data_rets)
	table.insert(data_rets_player, 1, fn.rreturn(PLAYER_TY))

	local data_args_player = table.clone(data_args)
	table.insert(data_args_player, 1, fn.argument(PLAYER_TY, "player"))

	local data_args_list = table.clone(data_args)
	table.insert(data_args_list, 1, fn.argument(PLAYER_TY, "list"))

	local data_fn_sets = table.create(#data_args) :: { lir.FnSet }
	for index, paramater in event_data do
		data_fn_sets[index] = builders.ty.from_ty_id(ctx, decl.attributes, paramater.ty_id)
	end

	local fire_all = fn.create(ctx, constant.from_value("fire_all"), data_args, {}, function(block)
		state.reset_outgoing(block)
		block:call(library.buffer.u8.write(block:allocate(constant.one), id))
		for index, fn_set in data_fn_sets do
			block:call_fn(fn_set.write, { block:argument(index) }, {})
		end

		if is_unreliable then
			local new_buffer = trim_outgoing_buffer(block)
			block:call(library.RemoteEvent.fire_all(UNRELIABLE_EVENT, { new_buffer, OUTGOING.unknown } :: { any }))
		else
			local new_buffer = copy_outgoing_buffer(block)
			block:for_generic(globals.players_map, function(block, _, player_save)
				state.update_save(block, player_save, new_buffer, OUTGOING.cursor)
			end)
		end
	end)
	local fire_list = fn.create(ctx, constant.from_value("fire_list"), data_args_list, {}, function(block)
		state.reset_outgoing(block)
		block:call(library.buffer.u8.write(block:allocate(constant.one), id))
		for index, fn_set in data_fn_sets do
			block:call_fn(fn_set.write, { block:argument(1 + index) }, {})
		end

		local list = block:argument(1)
		local new_buffer = is_unreliable and trim_outgoing_buffer(block) or copy_outgoing_buffer(block)

		block:for_generic(list, function(block, _, player)
			if is_unreliable then
				local args = { player, new_buffer, OUTGOING.unknown }
				block:call(library.RemoteEvent.fire_client(UNRELIABLE_EVENT, args :: { any }))
			else
				local player_save = projection.field(globals.players_map, player :: any)
				state.update_save(block, player_save, new_buffer, OUTGOING.cursor)
			end
		end)
	end)
	local fire_except = fn.create(ctx, constant.from_value("fire_except"), data_args_player, {}, function(block)
		state.reset_outgoing(block)
		block:call(library.buffer.u8.write(block:allocate(constant.one), id))
		for index, fn_set in data_fn_sets do
			block:call_fn(fn_set.write, { block:argument(1 + index) }, {})
		end

		local except = block:argument(1)
		local new_buffer = is_unreliable and trim_outgoing_buffer(block) or copy_outgoing_buffer(block)

		block:for_generic(globals.players_map, function(block, player, player_save)
			block:if_branch(condition.not_equals(player, except), function(block)
				if is_unreliable then
					local args = { player, new_buffer, OUTGOING.unknown }
					block:call(library.RemoteEvent.fire_client(UNRELIABLE_EVENT, args :: { any }))
				else
					state.update_save(block, player_save, new_buffer, OUTGOING.cursor)
				end
			end)
		end)
	end)
	local fire_server = fn.create(ctx, constant.from_value("fire"), data_args_player, {}, function(block)
		state.reset_outgoing(block)
		block:call(library.buffer.u8.write(block:allocate(constant.one), id))
		for index, fn_set in data_fn_sets do
			block:call_fn(fn_set.write, { block:argument(1 + index) }, {})
		end

		local player = block:argument(1)

		if is_unreliable then
			local new_buffer = trim_outgoing_buffer(block)
			local args = { player, new_buffer, OUTGOING.unknown }
			block:call(library.RemoteEvent.fire_client(UNRELIABLE_EVENT, args :: { any }))
		else
			local new_buffer = copy_outgoing_buffer(block)
			local player_save = projection.field(globals.players_map, player :: any)
			state.update_save(block, player_save, new_buffer, OUTGOING.cursor)
		end
	end)
	local fire_client = fn.create(ctx, constant.from_value("fire"), data_args, {}, function(block)
		local prev_buffer: lir.LValue<buffer>, prev_length: lir.LValue<number>, prev_cursor: lir.LValue<number>, prev_unknown: lir.LValue<{ unknown }>
		if is_unreliable then
			-- take snapshot of outgoing state
			prev_buffer = block:store(OUTGOING.buffer)
			prev_length = block:store(OUTGOING.length)
			prev_cursor = block:store(OUTGOING.cursor)
			prev_unknown = block:store(OUTGOING.unknown)

			-- temporary outgoing state
			local size = constant.from_value(296)
			-- 296 is 3 1.5x expansions away from 1000 bytes
			block:store(library.buffer.create(size), OUTGOING.buffer)
			block:store(size, OUTGOING.length)
			block:store(constant.zero, OUTGOING.cursor)
			block:store(library.table.create(constant.from_value(16)), OUTGOING.unknown)
		end

		-- write event payload
		block:call(library.buffer.u8.write(block:allocate(constant.one), id))
		for index, fn_set in data_fn_sets do
			block:call_fn(fn_set.write, { block:argument(index) }, {})
		end

		if is_unreliable then
			-- replicate
			local args = { trim_outgoing_buffer(block), OUTGOING.unknown } :: { any }
			block:call(library.RemoteEvent.fire_server(UNRELIABLE_EVENT, args))

			-- restore outgoing state
			block:store(prev_buffer, OUTGOING.buffer)
			block:store(prev_length, OUTGOING.length)
			block:store(prev_cursor, OUTGOING.cursor)
			block:store(prev_unknown, OUTGOING.unknown)
		end
	end)

	local event_queue = context.write_global(ctx, `{name}_queue`, QUEUE_TEMPLATE)
	local iter_server = fn.create(ctx, constant.from_value("iter"), {}, {}, function(block)
		local cursor_index = projection.index(event_queue, constant.from_value("cursor"))
		local cursor = block:store(cursor_index)
		local columns = block:store(projection.index(event_queue, constant.from_value("columns")))
	end)
	local listen_server = fn.create(ctx, constant.from_value("on"), {}, {}, function(block) end)

	local iter_client = fn.create(ctx, constant.from_value("iter"), {}, {}, function(block) end)
	local listen_client = fn.create(ctx, constant.from_value("on"), {}, {}, function(block) end)

	return {
		type = "event",
		decl = decl,
		fns = {
			fire_client = context.store_fn(ctx, fire_client),
			iter_client = context.store_fn(ctx, iter_client),
			listen_client = context.store_fn(ctx, listen_client),

			fire_all = context.store_fn(ctx, fire_all),
			fire_list = context.store_fn(ctx, fire_list),
			fire_except = context.store_fn(ctx, fire_except),
			fire_server = context.store_fn(ctx, fire_server),
			iter_server = context.store_fn(ctx, iter_server),
			listen_server = context.store_fn(ctx, listen_server),
		},
	}
end

local function build_function(ctx: Context, decl: hir.Function): lir.Function
	return nil :: any
end

local function from_hir(hir: hir.Hir): lir.Lir
	local lir: Lir = {
		fns = {},
		globals = {},

		tys = {},
		types = {},
		events = {},
		functions = {},
	}

	local ctx: Context = context.create(hir, lir)

	for decl_id, decl in hir.types do
		local lir_type = build_type(ctx, decl)
		if lir_type == nil then
			continue
		end

		lir.types[decl_id] = lir_type
	end

	for decl_id, decl in hir.events do
		lir.events[decl_id] = build_event(ctx, decl)
	end

	for decl_id, decl in hir.functs do
		lir.functions[decl_id] = build_function(ctx, decl)
	end

	return lir
end

return table.freeze({
	from_hir = from_hir,
})
