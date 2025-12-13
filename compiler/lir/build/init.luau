--!strict
--!native
--!optimize 2

local binary = require("@builders/binary")
local builders = require("@builders")
local condition = require("@builders/condition")
local constant = require("@builders/constant")
local context = require("@self/context")
local control = require("@builders/control")
local fn = require("@builders/fn")
local globals = require("@builders/globals")
local hir = require("@hir")
local library = require("@builders/library")
local panic = require("@util/panic")
local projection = require("@builders/projection")
local shuffle = require("@util/shuffle")
local state = require("@builders/state")
local strong_exhaustive_match = require("@util/strong_exhaustive_match")
local structure = require("@builders/structure")
local ternary = require("@builders/ternary")
local ty = require("@ty")
local types = require("@lir/types")
local unary = require("@builders/unary")

type Lir = types.Lir
type Hir = hir.Hir

type Decl = hir.Decl
type DeclId = hir.DeclId
type ScopeId = hir.ScopeId
type Event = hir.Event
type Function = hir.Function

type Ty = ty.Ty
type TyId = ty.TyId

type Fn = types.Fn
type FnId = types.FnId
type AnonymousFn = types.AnonymousFn

type Context = context.Context
type Builder = builders.Builder

type Export = types.Export
type TypeExport = types.TypeExport
type EventExport = types.EventExport
type FunctionExport = types.FunctionExport
type ScopeExport = types.ScopeExport

type Receivable = {
	read id: number,
	read decl: Event | Function,
}

type ExportsMap = { [DeclId]: Export? }

type Side = "Server" | "Client"

local QUEUES = globals.queues_map
local INCOMING = globals.incoming
local OUTGOING = globals.outgoing
local CONNECTIONS = globals.connections_map
local INVOCATIONS = globals.invocations_map
local RELIABLE_EVENT = globals.events.reliable
local UNRELIABLE_EVENT = globals.events.unreliable

-- the bitset is flipped to use 1 for free and 0 for occupied
-- this allows us to skip the inversion before countrz
local FULL_BITSET = constant.zero
local EMPTY_BITSET = constant.from_value(2 ^ 32 - 1)
local INVOCATIONS_BITSET = globals.invocations_bitset

local BUFFER_TY = ty.buffer()
local PLAYER_TY = ty.instance(ty.string_literal("Player"))
local PLAYERS_TY = ty.array(PLAYER_TY)
local UNKNOWN_TY = ty.unknown()
local UNKNOWNS_TY = ty.array(ty.unknown())

local PLAYER_RETURN = fn.rreturn(PLAYER_TY)
local PLAYER_PARAMETER = fn.parameter(PLAYER_TY, "player")
local PLAYER_LIST_PARAMETER = fn.parameter(PLAYERS_TY, "players")

local RECEIVE_PARAMETERS = {
	fn.parameter(BUFFER_TY, "packet_buffer"),
	fn.parameter(UNKNOWNS_TY, "packet_unknowns"),
}

local SERVER_RECEIVE_PARAMETERS = {
	PLAYER_PARAMETER,
	fn.parameter(BUFFER_TY, "packet_buffer"),
	fn.parameter(UNKNOWNS_TY, "packet_unknowns"),
}

local ON_PARAMETER = fn.parameter(UNKNOWN_TY)
local DISCONNECT_RETURN = fn.rreturn(UNKNOWN_TY)

local BUFFER_RETURN = fn.rreturn(BUFFER_TY)
local BUFFER_PARAMETER = fn.parameter(BUFFER_TY, "buf")

local CURSOR_TY = ty.numeral("32", "u")

local CURSOR_RETURN = fn.rreturn(CURSOR_TY)
local CURSOR_PARAMETER = fn.parameter(CURSOR_TY, "cursor")
local LENGTH_PARAMETER = fn.parameter(CURSOR_TY, "length")

local CURSOR_OPTIONAL_TY = ty.union({ CURSOR_TY, ty.nnil() })
local CURSOR_OPTIONAL_PARAMETER = fn.parameter(CURSOR_OPTIONAL_TY, "cursor")

local function returns(ctx: Context, parameters: { hir.Parameter }): { types.Return }
	local array = {}
	for index, parameter in parameters do
		local ty = hir.ty_from_id(ctx.hir, parameter.ty_id)
		array[index] = fn.rreturn(ty)
	end
	return array
end

local function parameters(ctx: Context, parameters: { hir.Parameter }): { types.Parameter }
	local array = {}
	for index, parameter in parameters do
		local ty = hir.ty_from_id(ctx.hir, parameter.ty_id)
		array[index] = fn.parameter(ty, parameter.name)
	end
	return array
end

local function ty_pack_to_fn_sets(ctx: Context, decl: hir.Decl, pack: { hir.Parameter }): { types.FnSet }
	local fn_sets = table.create(#pack) :: { types.FnSet }
	for index, parameter in pack do
		local parameter_ty = hir.ty_from_id(ctx.hir, parameter.ty_id)
		fn_sets[index] = builders.ty.build(ctx, decl.attributes, parameter_ty)
	end
	return fn_sets
end

local function next_event_id(pool: { number }): number
	local id = table.remove(pool, #pool)
	if id == nil then
		return panic("exhausted event ids")
	end

	return id
end

local function event_queue_structure(args_count: number): types.Struct<any>
	local columns_array = table.create(args_count, structure.array({}))
	return structure.struct({
		[constant.from_value("row")] = constant.zero,
		[constant.from_value("size")] = constant.zero,
		[constant.from_value("columns")] = structure.array(columns_array :: any) :: any,
	})
end

local function trim_outgoing_buffer(block: fn.Builder): types.RegisterId<buffer>
	local new_buffer = block:store(OUTGOING.buffer)
	block:if_single(condition.not_equals(OUTGOING.cursor, OUTGOING.length), function()
		block:store(library.buffer.create(OUTGOING.cursor), new_buffer)
		block:call(library.buffer.copy(new_buffer, constant.zero, OUTGOING.buffer, constant.zero, OUTGOING.cursor))
	end)
	return new_buffer
end

local function copy_outgoing_buffer(block: fn.Builder): types.RegisterId<buffer>
	local new_buffer = block:store(library.buffer.create(OUTGOING.cursor))
	block:call(library.buffer.copy(new_buffer, constant.zero, OUTGOING.buffer, constant.zero, OUTGOING.cursor))
	return new_buffer
end

local function toggle_bitset_index(block: fn.Builder, index: types.RValue<number>, bitset: types.RValue<number>?)
	local modified_bitset = library.bit32.bxor(bitset or INVOCATIONS_BITSET, binary.pow(constant.two, index))
	block:store(modified_bitset, INVOCATIONS_BITSET)
end

local function build_type(ctx: Context, ttype: hir.Type): TypeExport?
	if ttype.generics then
		return nil
	end

	local type_ty = hir.ty_from_id(ctx.hir, ttype.ty_id)
	local type_fnset = builders.ty.build(ctx, ttype.attributes, type_ty, ttype.name)

	if ttype.attributes.export ~= true then
		return nil
	end

	local type_return = fn.rreturn(type_ty)
	local type_parameter = fn.parameter(type_ty, "value")

	local read = fn.anonymous(
		{ BUFFER_PARAMETER, CURSOR_OPTIONAL_PARAMETER },
		{ type_return, CURSOR_RETURN },
		function(block: builders.Builder)
			block:store(block:parameter(1), INCOMING.buffer)
			block:store(condition.oor(block:parameter(2), constant.zero), INCOMING.cursor)

			local value = block:reserve()
			block:call_fn(type_fnset.read, {}, { value })
			block:rreturn({ value, INCOMING.cursor } :: any)
		end
	)

	local write = fn.anonymous({ type_parameter }, { BUFFER_RETURN }, function(block: builders.Builder)
		block:store(constant.zero, OUTGOING.cursor)
		block:call_fn(type_fnset.write, { block:parameter(1) }, {})
		block:rreturn({ copy_outgoing_buffer(block) } :: any)
	end)

	local write_to = fn.anonymous(
		{ type_parameter, BUFFER_PARAMETER, CURSOR_PARAMETER, LENGTH_PARAMETER },
		{ BUFFER_RETURN, CURSOR_RETURN },
		function(block: builders.Builder)
			local prev_buf = block:store(OUTGOING.buffer)
			local prev_length = block:store(OUTGOING.length)

			block:store(block:parameter(2), OUTGOING.buffer)
			block:store(block:parameter(3), OUTGOING.cursor)
			block:store(block:parameter(4), OUTGOING.length)

			block:call_fn(type_fnset.write, { block:parameter(1) }, {})
			local trimmed_buffer = trim_outgoing_buffer(block)

			block:store(prev_buf, OUTGOING.buffer)
			block:store(prev_length, OUTGOING.length)

			block:rreturn({ trimmed_buffer, OUTGOING.cursor } :: any)
		end
	)

	return {
		type = "export",
		kind = "type",
		name = ttype.name,

		read = read,
		write = write,
		write_to = write_to,
	}
end

local function queue_iterator(queue_projection: types.ProjField<any>, args_count: number)
	return fn.anonymous({}, {}, function(block)
		local queue = block:store(queue_projection)
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

local function build_event(ctx: Context, decl: Event, event_id: number): EventExport
	local id = constant.from_value(event_id)

	local event_type = decl.type
	local is_unreliable = (event_type == "Unreliable")

	local data = decl.data or {}
	local data_rets = returns(ctx, data)
	local data_params = parameters(ctx, data)
	local data_fn_sets = ty_pack_to_fn_sets(ctx, decl, data)

	local data_rets_player = table.clone(data_rets)
	table.insert(data_rets_player, 1, PLAYER_RETURN)

	local data_params_player = table.clone(data_params)
	table.insert(data_params_player, 1, PLAYER_PARAMETER)

	local data_params_list = table.clone(data_params)
	table.insert(data_params_list, 1, PLAYER_LIST_PARAMETER)

	local fire_all = fn.anonymous(data_params, {}, function(block)
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

	local fire_list = fn.anonymous(data_params_list, {}, function(block)
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

	local fire_except = fn.anonymous(data_params_player, {}, function(block)
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

	local fire_client = fn.anonymous(data_params_player, {}, function(block)
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

	local fire_server = fn.anonymous(data_params, {}, function(block)
		local prev_buffer: types.LValue<buffer>, prev_length: types.LValue<number>, prev_cursor: types.LValue<number>, prev_unknown: types.LValue<{ unknown }>
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

	local on_server: AnonymousFn?, on_client: AnonymousFn?
	local iter_server: AnonymousFn?, iter_client: AnonymousFn?

	local call = decl.call
	local queue_projection = projection.field(QUEUES, constant.from_value(event_id))
	if call == "Polling" then
		iter_client = queue_iterator(queue_projection, #data_params)
		iter_server = queue_iterator(queue_projection, #data_params_player)
	else
		local on_fn = fn.anonymous({ ON_PARAMETER }, { DISCONNECT_RETURN }, function(block)
			local listener = block:store(block:parameter(1))
			local is_single = (call == "SingleSync" or call == "SingleAsync")
			local connection_projection = projection.field(CONNECTIONS, constant.from_value(event_id))

			if is_single then
				block:if_single(condition.not_equals(connection_projection, constant.null), function(block)
					local message = library.debug.traceback(
						constant.from_value(
							"[Blink]: Event already has a listener, the current listener will be discarded."
						),
						constant.from_value(2)
					)

					block:call(library.warn(message))
				end)

				block:store(listener, connection_projection)
			else
				block:call(library.table.insert(connection_projection, listener))
			end

			local disconnect = fn.anonymous({}, {}, function(block)
				block:capture({ listener })

				if is_single then
					block:store(constant.null, connection_projection)
				else
					local index = block:store(library.table.find(connection_projection, listener))
					block:if_single(condition.not_equals(index, constant.null), function()
						block:store(constant.null, projection.field(connection_projection, index))
					end)
				end
			end)

			block:rreturn({ disconnect })
		end)

		on_client = on_fn
		on_server = on_fn
	end

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
	}
end

local function build_event_receive(ctx: Context, side: Side, block: fn.Builder, decl: Event, event_id: number)
	local call = decl.call
	local fn_sets = ty_pack_to_fn_sets(ctx, decl, decl.data or {})
	local queue = projection.field(QUEUES, constant.from_value(event_id))

	local values: { types.RegisterId<any> } = {}
	if side == "Server" then
		-- player parameter
		table.insert(values, block:parameter(1))
	end

	for _, fn_set in fn_sets do
		local register = block:reserve()
		block:call_fn(fn_set.read, {}, { register })
		table.insert(values, register)
	end

	if call == "SingleSync" or call == "SingleAsync" then
		local connection = projection.field(CONNECTIONS, constant.from_value(event_id))
		block:if_single(condition.not_equals(connection, constant.null), function(block)
			if call == "SingleSync" then
				block:call(projection.call(connection :: any, values :: any))
			else
				block:call(library.task.spawn(connection :: any, values :: any))
			end

			block:rreturn({})
		end)
	elseif call == "ManySync" or call == "ManyAsync" then
		local connections = projection.field(CONNECTIONS, constant.from_value(event_id))
		local is_connected = condition.greater_than(unary.len(connections), constant.zero)
		block:if_single(is_connected, function(block)
			block:for_generic(connections, function(block, _, connection)
				if call == "ManySync" then
					block:call(projection.call(connection :: any, values :: any))
				else
					block:call(library.task.spawn(connection :: any, values :: any))
				end
			end)

			block:rreturn({})
		end)
	end

	-- insert into queue
	local size_index = projection.index(queue, constant.from_value("size"))
	local size = block:store(binary.add(size_index, constant.one))
	local columns = block:store(projection.index(queue, constant.from_value("columns")))
	block:store(size, size_index)

	for index, value in values do
		local column = projection.field(columns, constant.from_value(index))
		local column_row = projection.field(column, size)
		block:store(value, column_row)
	end
end

local function build_function(ctx: Context, decl: Function, event_id: number): FunctionExport
	local id = constant.from_value(event_id)

	local data = decl.data or {}
	local rreturn = decl.ret or {}

	local fn_returns = returns(ctx, rreturn)
	local fn_parameters = parameters(ctx, data)

	local data_fn_sets = ty_pack_to_fn_sets(ctx, decl, data)

	local on = fn.anonymous({ ON_PARAMETER }, { DISCONNECT_RETURN }, function(block)
		local listener = block:store(block:parameter(1))
		local callback = projection.field(CONNECTIONS, constant.from_value(event_id))

		block:if_single(condition.not_equals(callback, constant.null), function(block)
			local message = library.debug.traceback(
				constant.from_value("[Blink]: Function already has a listener, the current listener will be discarded."),
				constant.from_value(2)
			)

			block:call(library.warn(message))
		end)

		block:store(listener, callback)

		local disconnect = fn.anonymous({}, {}, function(block)
			block:capture({ listener })
			block:store(constant.null, callback)
		end)

		block:rreturn({ disconnect })
	end)

	local invoke_server = fn.anonymous(fn_parameters, fn_returns, function(block)
		-- store upvalue locally to speed up loads
		local bitset = block:store(INVOCATIONS_BITSET)
		block:if_single(condition.equals(bitset, FULL_BITSET), function(block)
			block:call(
				library.error(
					"[Blink]: More than 32 invocations are awaiting a response, this invocation has been dropped."
				)
			)
		end)

		-- find the first free index and mark it as occupied
		local bitset_index = block:store(library.bit32.countrz(bitset))
		toggle_bitset_index(block, bitset_index, bitset)

		-- store invocation thread in map
		-- we increment by 1 since the bitset index is in the range of [0;31]
		-- where as we need an index in the range of the array portion of INVOCATIONS [1;32]
		local map_index = projection.field(INVOCATIONS, binary.add(bitset_index, constant.one))
		block:store(library.coroutine.running(), map_index)

		-- write function payload
		block:call(library.buffer.u8.write(block:allocate(constant.one), id))
		block:call(library.buffer.u8.write(block:allocate(constant.one), bitset_index))

		for index, fn_set in data_fn_sets do
			block:call_fn(fn_set.write, { block:parameter(index) }, {})
		end

		-- first value is a boolean indicating whether the server successfully processed the invocation
		local return_values = block:store_mult(library.coroutine.yield(), #rreturn + 1)

		local success_status = return_values[1]
		block:if_single(condition.equals(success_status, constant.falsity), function(block)
			block:call(library.error("[Blink]: Server encountered an error while processing the invocation."))
		end)

		block:rreturn({ unpack(return_values, 2) })
	end)

	return {
		type = "export",
		kind = "function",
		name = decl.name,
		on = on,
		invoke_server = invoke_server,
	}
end

local function build_function_receive(ctx: Context, side: Side, block: fn.Builder, decl: Function, event_id: number)
	local data = decl.data or {}
	local rreturn = decl.ret or {}

	local data_fn_sets = ty_pack_to_fn_sets(ctx, decl, data)
	local return_fn_sets = ty_pack_to_fn_sets(ctx, decl, rreturn)

	if side == "Client" then
		local invocation_id = block:store(library.buffer.u8.read(control.advance(constant.one)))
		local success_status =
			block:store(condition.equals(library.buffer.u8.read(control.advance(constant.one)), constant.one))

		local return_registers = {}
		for index = 1, #return_fn_sets do
			return_registers[index] = block:reserve()
		end

		block:if_single(condition.equals(success_status, constant.truth), function(block)
			for index, fn_set in return_fn_sets do
				block:call_fn(fn_set.read, {}, { return_registers[index] })
			end
		end)

		local map_index = block:store(binary.add(invocation_id, constant.one))
		local map_projection = projection.field(INVOCATIONS, map_index)
		local invocation_thread = block:store(map_projection)
		block:if_single(condition.not_equals(invocation_thread, constant.null), function(block)
			block:store(constant.null, map_projection)
			toggle_bitset_index(block, invocation_id)

			local thread_status = library.coroutine.status(invocation_thread)
			block:if_single(condition.equals(thread_status, constant.from_value("suspended")), function(block)
				block:call(library.coroutine.resume(invocation_thread, success_status :: any, unpack(return_registers)))
			end)
		end)
	elseif side == "Server" then
		local id = constant.from_value(event_id)
		local callback = block:store(projection.field(CONNECTIONS, id))
		local invocation_id = block:store(library.buffer.u8.read(control.advance(constant.one)))

		local data_values = {}
		for index, fn_set in data_fn_sets do
			local register = block:reserve()
			block:call_fn(fn_set.read, {}, { register })
			data_values[index] = register
		end

		block:if_chain(2, function(index)
			if index == 1 then
				return condition.equals(callback, constant.null),
					function(block: fn.Builder)
						block:call(library.buffer.u8.write(block:allocate(constant.one), id))
						block:call(library.buffer.u8.write(block:allocate(constant.one), invocation_id))
						block:call(library.buffer.u8.write(block:allocate(constant.one), constant.zero))
					end
			end

			return condition.not_equals(callback, constant.null),
				function(block: fn.Builder)
					local player = block:store(block:parameter(1))
					block:call(library.task.spawn(
						fn.anonymous({}, {}, function(block)
							block:capture({ callback, player })

							local pcall_values =
								block:store_mult(library.pcall(callback, unpack(data_values)), #rreturn + 1)

							local was_successful = condition.equals(pcall_values[1], constant.truth)
							local success_value = ternary(was_successful, constant.one, constant.zero)

							state.reset_outgoing(block)
							block:call(library.buffer.u8.write(block:allocate(constant.one), id))
							block:call(library.buffer.u8.write(block:allocate(constant.one), invocation_id))
							block:call(library.buffer.u8.write(block:allocate(constant.one), success_value))

							block:if_single(was_successful, function(block)
								for index, fn_set in return_fn_sets do
									block:call_fn(fn_set.write, { pcall_values[index + 1] }, {})
								end
							end)

							local new_buffer = copy_outgoing_buffer(block)
							local player_save = projection.field(globals.players_map, player :: any)
							state.update_save(block, player_save, new_buffer, OUTGOING.cursor)
						end),
						{}
					))
				end
		end)
	else
		strong_exhaustive_match(side)
	end
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

local function build_receive_connection(ctx: Context, side: Side, receivables: { Receivable }): types.AnonymousFn
	local parameters = RECEIVE_PARAMETERS
	local parameters_offset = 0
	local is_server = side == "Server"

	if is_server then
		parameters = SERVER_RECEIVE_PARAMETERS
		parameters_offset = 1
	end

	return fn.anonymous(parameters, {}, function(block)
		local n_receivables = #receivables
		local packet_buffer = block:parameter(parameters_offset + 1)
		local packet_unknowns = block:parameter(parameters_offset + 2)
		local packet_length = block:store(library.buffer.len(packet_buffer))

		block:store(packet_buffer, INCOMING.buffer)
		block:store(constant.zero, INCOMING.cursor)
		block:store(packet_unknowns, INCOMING.unknown)
		block:store(constant.zero, INCOMING.unknown_cursor)

		block:while_loop(condition.less_than(INCOMING.cursor, packet_length), function(block)
			local read_event_id = block:store(library.buffer.u8.read(control.advance(constant.one)))
			block:if_chain(n_receivables + 1, function(index)
				if index > n_receivables then
					local fallback = condition.equals(constant.truth, constant.truth)
					return fallback,
						function(block: fn.Builder)
							block:call(library.error("Unknown event id"))
						end
				end

				local receivable = receivables[index]
				local decl = receivable.decl
				local event_id = receivable.id
				local event_id_matches = condition.equals(read_event_id, constant.from_value(event_id))

				return event_id_matches,
					function(block: fn.Builder)
						if decl.kind == "event" then
							build_event_receive(ctx, side, block, decl, event_id)
						elseif decl.kind == "function" then
							build_function_receive(ctx, side, block, decl, event_id)
						else
							strong_exhaustive_match(decl.kind)
						end
					end
			end)
		end)
	end)
end

local function from_hir(hir: hir.Hir): types.Lir
	local ctx = context.create(hir, types)
	local exports_map: ExportsMap = {}

	-- write globals
	context.write_global(ctx, globals.types_map.identifier, structure.map({}))
	context.write_global(ctx, INVOCATIONS.identifier, structure.map({}))
	context.write_global(ctx, INVOCATIONS_BITSET.identifier, EMPTY_BITSET)

	-- build types
	for decl_id, decl in hir.types do
		exports_map[decl_id] = build_type(ctx, decl)
	end

	-- build events
	local reliable_receivables: { Receivable } = {}
	local unreliables_receivables: { Receivable } = {}

	do
		local queues = {}
		local connections = {}
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
			local receivables = type == "Reliable" and reliable_receivables or unreliables_receivables

			local event_id = next_event_id(id_pool)
			table.insert(receivables, { id = event_id, decl = decl })

			local key = constant.from_value(event_id)
			local call = decl.call
			local n_args = decl.data and #decl.data or 1

			queues[key] = event_queue_structure(n_args)
			connections[key] = (call == "ManySync" or call == "ManyAsync") and structure.array({}) or nil
			exports_map[decl_id] = build_event(ctx, decl, event_id)
		end

		for decl_id, decl in hir.functs do
			local event_id = next_event_id(reliable_ids)
			exports_map[decl_id] = build_function(ctx, decl, event_id)
			table.insert(reliable_receivables, { id = event_id, decl = decl })
		end

		context.write_global(ctx, globals.queues_map.identifier, structure.map(queues :: any))
		context.write_global(ctx, globals.connections_map.identifier, structure.map(connections :: any))
	end

	local client_receive_reliable = build_receive_connection(ctx, "Client", reliable_receivables)
	local client_receive_unreliable = build_receive_connection(ctx, "Client", unreliables_receivables)
	local server_receive_reliable = build_receive_connection(ctx, "Server", reliable_receivables)
	local server_receive_unreliable = build_receive_connection(ctx, "Server", unreliables_receivables)

	local client_step = fn.anonymous({}, {}, function(block)
		local packet_buffer = trim_outgoing_buffer(block)
		block:call(library.RemoteEvent.fire_server(RELIABLE_EVENT, { packet_buffer, OUTGOING.unknown } :: any))
		block:store(constant.zero, OUTGOING.cursor)
		block:call(library.table.clear(OUTGOING.unknown))
	end)

	local server_step = fn.anonymous({}, {}, function(block)
		block:for_generic(globals.players_map, function(block, player, save)
			local buffers = block:store(projection.index(save, constant.from_value("buffers")))
			local lengths = block:store(projection.index(save, constant.from_value("lengths")))
			local unknown = block:store(projection.index(save, constant.from_value("unknown")))

			local total_length = block:store(constant.zero)
			block:for_generic(lengths, function(block, _, length)
				block:store(binary.add(total_length, length), total_length)
			end)

			local cursor = block:store(constant.zero)
			local packet_buffer = block:store(library.buffer.create(total_length))
			block:for_generic(buffers, function(block, index, segment)
				local length = projection.field(lengths, index)
				block:call(library.buffer.copy(packet_buffer, cursor, segment))
				block:store(binary.add(cursor, length), cursor)
			end)

			block:call(library.RemoteEvent.fire_client(RELIABLE_EVENT, { player, packet_buffer :: any, unknown }))

			block:call(library.table.clear(buffers))
			block:call(library.table.clear(lengths))
			block:call(library.table.clear(unknown))
		end)
	end)

	return {
		export = build_scope(ctx, 0 :: any, exports_map),
		fn_map = ctx.fn_map,
		globals = ctx.globals,
		client = {
			step_replication = client_step,
			reliable_receive = client_receive_reliable,
			unreliable_receive = client_receive_unreliable,
		},
		server = {
			step_replication = server_step,
			reliable_receive = server_receive_reliable,
			unreliable_receive = server_receive_unreliable,
		},
	}
end

return table.freeze({
	from_hir = from_hir,
})
