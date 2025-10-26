--!strict
--!native
--!optimize 2

local binary = require("@builders/binary")
local builders = require("@builders/init")
local condition = require("@builders/condition")
local constant = require("@builders/constant")
local context = require("@self/context")
local fn = require("@builders/fn")
local globals = require("@builders/globals")
local hir = require("@hir/types")
local library = require("@builders/library")
local lir = require("@lir/types")
local panic = require("@util/panic")
local prefixes = require("@config/prefixes")
local projection = require("@builders/projection")
local shuffle = require("@util/shuffle")
local state = require("@builders/state")
local structure = require("@builders/structure")
local ty = require("@ty/types")
local unary = require("@builders/unary")

type Lir = lir.Lir
type Hir = hir.Hir

type Decl = hir.Decl
type DeclId = hir.DeclId
type ScopeId = hir.ScopeId

type Ty = ty.Ty
type TyId = ty.TyId

type Fn = lir.Fn
type FnId = lir.FnId
type AnonymousFn = lir.AnonymousFn

type Context = context.Context
type Builder = builders.Builder

type Export = lir.Export
type TypeExport = lir.TypeExport
type EventExport = lir.EventExport
type FunctionExport = lir.FunctionExport
type ScopeExport = lir.ScopeExport

type ExportsMap = { [DeclId]: Export? }

local INCOMING = globals.incoming
local OUTGOING = globals.outgoing
local RELIABLE_EVENT = globals.events.reliable
local UNRELIABLE_EVENT = globals.events.unreliable

local PLAYER_RETURN = fn.static_return("Player")
local PLAYER_ARGUMENT = fn.static_parameter("Player", "player")
local PLAYER_LIST_ARGUMENT = fn.static_parameter("{Player}", "players")
local RECEIVE_PARAMETERS = {
	fn.static_parameter("buffer", "packet_buffer"),
	fn.static_parameter("{unknown},", "packet_unknowns"),
}

local function rreturns(ctx: Context, parameters: { hir.Parameter }): { lir.Return }
	local array = {}
	for index, parameter in parameters do
		local ty = hir.ty_from_id(ctx.hir, parameter.ty_id)
		array[index] = fn.rreturn(ty)
	end
	return array
end

local function parameters(ctx: Context, parameters: { hir.Parameter }): { lir.Parameter }
	local array = {}
	for index, parameter in parameters do
		local ty = hir.ty_from_id(ctx.hir, parameter.ty_id)
		array[index] = fn.parameter(ty, parameter.name)
	end
	return array
end

local function next_event_id(pool: { number }): number
	local id = table.remove(pool, #pool)
	if id == nil then
		return panic("exhausted event ids")
	end

	return id
end

local function event_queue_structure(args_count: number): lir.Struct<any>
	local columns_array = table.create(args_count, structure.array({}))
	return structure.struct({
		[constant.from_value("row")] = constant.zero,
		[constant.from_value("size")] = constant.zero,
		[constant.from_value("columns")] = structure.array(columns_array :: any) :: any,
	})
end

local function trim_outgoing_buffer(block: fn.Builder): lir.RegisterId<buffer>
	local new_buffer = block:store(OUTGOING.buffer)
	block:if_single(condition.not_equals(OUTGOING.cursor, OUTGOING.length), function()
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

local function build_type(ctx: Context, decl: hir.Type): TypeExport?
	if decl.generics then
		return nil
	end

	local fn_set = builders.ty.from_ty_id(ctx, decl.attributes, decl.ty_id)

	return nil
end

local function queue_iterator(queue: lir.Global<any>, args_count: number)
	return fn.anonymous({}, {}, function(block)
		local row_index = projection.index(queue, constant.from_value("row"))
		local size_index = projection.index(queue, constant.from_value("size"))

		local row = block:store(row_index)
		local size = block:store(size_index)
		local columns = block:store(projection.index(queue, constant.from_value("columns")))

		local inner_iter = fn.anonymous({}, {}, function(block)
			block:capture({ size, row, columns })
			block:store(binary.add(row, constant.one), row)

			block:if_single(condition.greater_than(row, size), function(block)
				block:store(constant.zero, size_index)
				block:store(constant.zero, row)

				for index = 1, args_count do
					local column = projection.field(columns, constant.from_value(index))
					block:call(library.table.clear(column))
				end

				block:rreturn({})
			end)

			local values = {}
			for index = 1, args_count do
				local column = projection.field(columns, constant.from_value(index))
				local value = projection.field(column, row)
				table.insert(values, value)
			end

			block:rreturn(values)
		end)

		block:rreturn({ inner_iter })
	end)
end

local function build_event(ctx: Context, decl: hir.Event, event_id: number): (EventExport, FnId)
	local id = constant.from_value(event_id)
	local name = `{prefixes.event}{event_id}_{decl.name}`

	local event_type = decl.type
	local is_unreliable = (event_type == "Unreliable")

	local event_data = decl.data or {}
	local data_args = parameters(ctx, event_data)
	local data_rets = rreturns(ctx, event_data)

	local data_rets_player = table.clone(data_rets)
	table.insert(data_rets_player, 1, PLAYER_RETURN)

	local data_args_player = table.clone(data_args)
	table.insert(data_args_player, 1, PLAYER_ARGUMENT)

	local data_args_list = table.clone(data_args)
	table.insert(data_args_list, 1, PLAYER_LIST_ARGUMENT)

	local data_fn_sets = table.create(#data_args) :: { lir.FnSet }
	for index, paramater in event_data do
		data_fn_sets[index] = builders.ty.from_ty_id(ctx, decl.attributes, paramater.ty_id)
	end

	local fire_all = fn.anonymous(data_args, {}, function(block)
		state.reset_outgoing(block)
		block:call(library.buffer.u8.write(block:allocate(constant.one), id))
		for index, fn_set in data_fn_sets do
			block:call_fn(fn_set.write, { block:parameter(index) }, {})
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

	local fire_list = fn.anonymous(data_args_list, {}, function(block)
		state.reset_outgoing(block)
		block:call(library.buffer.u8.write(block:allocate(constant.one), id))
		for index, fn_set in data_fn_sets do
			block:call_fn(fn_set.write, { block:parameter(1 + index) }, {})
		end

		local list = block:parameter(1)
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

	local fire_except = fn.anonymous(data_args_player, {}, function(block)
		state.reset_outgoing(block)
		block:call(library.buffer.u8.write(block:allocate(constant.one), id))
		for index, fn_set in data_fn_sets do
			block:call_fn(fn_set.write, { block:parameter(1 + index) }, {})
		end

		local except = block:parameter(1)
		local new_buffer = is_unreliable and trim_outgoing_buffer(block) or copy_outgoing_buffer(block)

		block:for_generic(globals.players_map, function(block, player, player_save)
			block:if_single(condition.not_equals(player, except), function(block)
				if is_unreliable then
					local args = { player, new_buffer, OUTGOING.unknown }
					block:call(library.RemoteEvent.fire_client(UNRELIABLE_EVENT, args :: { any }))
				else
					state.update_save(block, player_save, new_buffer, OUTGOING.cursor)
				end
			end)
		end)
	end)

	local fire_client = fn.anonymous(data_args_player, {}, function(block)
		state.reset_outgoing(block)
		block:call(library.buffer.u8.write(block:allocate(constant.one), id))
		for index, fn_set in data_fn_sets do
			block:call_fn(fn_set.write, { block:parameter(1 + index) }, {})
		end

		local player = block:parameter(1)

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

	local fire_server = fn.anonymous(data_args, {}, function(block)
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
			block:call_fn(fn_set.write, { block:parameter(index) }, {})
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

	local event_queue = context.write_global(ctx, `{name}_queue`, event_queue_structure(#data_args_player))
	local on_server: AnonymousFn?, on_client: AnonymousFn?
	local iter_server: AnonymousFn?, iter_client: AnonymousFn?

	local call = decl.call
	if call == "Polling" then
		iter_client = queue_iterator(event_queue, #data_args)
		iter_server = queue_iterator(event_queue, #data_args_player)
	else
		on_client = fn.anonymous({}, {}, function(block) end)
		on_server = fn.anonymous({}, {}, function(block) end)
	end

	local receive_fn = fn.create(constant.from_value(`{name}_receive`), { PLAYER_ARGUMENT }, {}, function(block)
		local player = block:parameter(1)
		local values = { player }
		for _, fn_set in data_fn_sets do
			local register = block:reserve()
			block:call_fn(fn_set.read, {}, { register })
			table.insert(values, register)
		end

		if call == "SingleSync" or call == "SingleAsync" then
			local event_connection = context.write_global(ctx, `{name}_connection`, constant.null)
			block:if_single(condition.not_equals(event_connection, constant.null), function(block)
				local target: lir.ProjCall<any> = call == "SingleSync"
						and projection.call(event_connection :: any, values :: any)
					or library.task.spawn(event_connection :: any, values :: any)

				block:call(target)
				block:rreturn({})
			end)
		elseif call == "ManySync" or call == "ManyAsync" then
			local event_connections = context.write_global(ctx, `{name}_connections`, structure.array({}))
			local is_connected = condition.greater_than(unary.len(event_connections), constant.zero)
			block:if_single(is_connected, function(block)
				block:for_generic(event_connections, function(block, _, connection)
					local target: lir.ProjCall<any> = call == "SingleSync"
							and projection.call(connection :: any, values :: any)
						or library.task.spawn(connection :: any, values :: any)

					block:call(target)
				end)

				block:rreturn({})
			end)
		end

		-- insert into queue
		local size_index = projection.index(event_queue, constant.from_value("size"))
		local size = block:store(binary.add(size_index, constant.one))
		local columns = block:store(projection.index(event_queue, constant.from_value("columns")))
		block:store(size, size_index)

		for index, value in values do
			local column = projection.field(columns, constant.from_value(index))
			local column_row = projection.field(column, size)
			block:store(value, column_row)
		end
	end)

	return {
		type = "export",
		kind = "event",
		name = decl.name,
		server = {
			on = on_server,
			iter = iter_server,
			fire_all = fire_all,
			fire_list = fire_list,
			fire_except = fire_except,
			fire_client = fire_client,
		},
		client = {
			on = on_client,
			iter = iter_client,
			fire_server = fire_server,
		},
	},
		context.store_fn(ctx, receive_fn)
end

local function build_scope(ctx: Context, scope_id: hir.ScopeId, exports_map: ExportsMap): ScopeExport
	local hhir = ctx.hir
	local scope = hir.scope_from_id(hhir, scope_id)
	local items: { Export } = {}

	for _, stat in scope.values do
		local decl_id = stat.id :: DeclId
		local export = exports_map[decl_id]
		if export then
			table.insert(items, export)
		end
	end

	return {
		type = "export",
		kind = "scope",
		name = scope.name,
		items = items,
	}
end

local function from_hir(hir: hir.Hir): lir.Lir
	local ctx = context.create(hir, lir)
	local exports_map: ExportsMap = {}

	-- write globals
	context.write_global(ctx, globals.types_map.identifier, structure.struct({}))

	-- build types
	for decl_id, decl in hir.types do
		exports_map[decl_id] = build_type(ctx, decl)
	end

	-- build events
	local reliable_events: { [number]: FnId } = {}
	local unreliable_events: { [number]: FnId } = {}

	do
		local reliable_ids = table.create(256, 0)
		local unreliable_ids = table.create(256, 0)

		for index = 1, #reliable_ids do
			local id = (index - 1)
			reliable_ids[index] = id
			unreliable_ids[index] = id
		end

		shuffle(reliable_ids)
		shuffle(unreliable_ids)

		for decl_id, decl in hir.events do
			local type = decl.type
			local id_pool = type == "Reliable" and reliable_ids or unreliable_ids
			local receive_map = type == "Reliable" and reliable_events or unreliable_events

			local event_id = next_event_id(id_pool)
			local event_export, event_receive = build_event(ctx, decl, event_id)

			exports_map[decl_id] = event_export
			receive_map[event_id] = event_receive
		end
	end

	local client_receive_reliable = fn.anonymous(RECEIVE_PARAMETERS, {}, function(block) end)

	local client_receive_unreliable = fn.anonymous(RECEIVE_PARAMETERS, {}, function(block) end)

	local server_receive_reliable = fn.anonymous(RECEIVE_PARAMETERS, {}, function(block) end)

	local server_receive_unreliable = fn.anonymous(RECEIVE_PARAMETERS, {}, function(block) end)

	return {
		export = build_scope(ctx, 0 :: any, exports_map),
		fn_map = ctx.fn_map,
		globals = ctx.globals,
		client_receive = {
			reliable = client_receive_reliable,
			unreliable = client_receive_unreliable,
		},
		server_receive = {
			reliable = server_receive_reliable,
			unreliable = server_receive_unreliable,
		},
	}
end

return table.freeze({
	from_hir = from_hir,
})
