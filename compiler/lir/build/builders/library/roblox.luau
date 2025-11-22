--!strict

local types = require("@lir/types")

local constant = require("@builders/constant")
local projection = require("@builders/projection")

type Call<T> = types.ProjCall<T>
type Namecall<T> = types.ProjNamecall<T>

type LValue<T> = types.LValue<T>
type RValue<T> = types.RValue<T>
type Constant<T> = types.Constant<T>

local function cframe_new_quat(
	x: RValue<number>,
	y: RValue<number>,
	z: RValue<number>,
	quat_x: RValue<number>,
	quat_y: RValue<number>,
	quat_z: RValue<number>,
	quat_w: RValue<number>
): Call<CFrame>
	return projection.call(constant.from_value("CFrame.new"), { x, y, z, quat_x, quat_y, quat_z, quat_w })
end

local function cframe_to_axis_angle(at: RValue<CFrame>): Namecall<number>
	return projection.namecall(at :: LValue<any>, constant.from_value("ToAxisAngle"), {})
end

local function color3_from_HSV(hue: RValue<number>, sat: RValue<number>, val: RValue<number>): Call<Color3>
	return projection.call(constant.from_value("Color3.fromHSV"), { hue, sat, val })
end

local function color3_to_HSV(at: RValue<Color3>): Namecall<number>
	return projection.namecall(at :: LValue<any>, constant.from_value("ToHSV"), {})
end

local function brick_color_new(number: RValue<number>): Call<BrickColor>
	return projection.call(constant.from_value("BrickColor.new"), { number })
end

local function date_time_new(timestamp: RValue<number>): Call<DateTime>
	return projection.call(constant.from_value("DateTime.fromUnixTimestamp"), { timestamp })
end

local function date_time_millis_new(timestamp_millis: RValue<number>): Call<DateTime>
	return projection.call(constant.from_value("DateTime.fromUnixTimestampMillis"), { timestamp_millis })
end

local function instance_is_a(at: RValue<Instance>, class: Constant<string>): Namecall<boolean>
	return projection.namecall(at :: LValue<any>, constant.from_value("IsA"), { class } :: any)
end

local function instance_find_first_child(parent: RValue<Instance>, name: RValue<string>): Namecall<Instance?>
	return projection.namecall(parent :: LValue<any>, constant.from_value("FindFirstChild"), { name })
end

local function instance_wait_for_child(parent: RValue<Instance>, name: RValue<string>): Namecall<Instance>
	return projection.namecall(parent :: LValue<any>, constant.from_value("WaitForChild"), { name })
end

local function fire_all(remote: RValue<RemoteEvent>, args: { RValue<any> }): Namecall<nil>
	return projection.namecall(remote :: LValue<any>, constant.from_value("FireAllClients"), args)
end

local function fire_client(remote: RValue<RemoteEvent>, args: { RValue<any> }): Namecall<nil>
	return projection.namecall(remote :: LValue<any>, constant.from_value("FireClient"), args)
end

local function fire_server(remote: RValue<RemoteEvent>, args: { RValue<any> }): Namecall<nil>
	return projection.namecall(remote :: LValue<any>, constant.from_value("FireServer"), args)
end

local function get_players(service: RValue<Players>): Namecall<{ Player }>
	return projection.namecall(service :: LValue<any>, constant.from_value("GetPlayers"), {})
end

local function get_service<T>(name: RValue<string>): Namecall<T>
	return projection.namecall(constant.from_value("game"), constant.from_value("GetService"), { name })
end

return table.freeze({
	CFrame = {
		new_quat = cframe_new_quat,
		to_axis_angle = cframe_to_axis_angle,
	},

	Color3 = {
		from_HSV = color3_from_HSV,
		to_HSV = color3_to_HSV,
	},

	BrickColor = {
		new = brick_color_new,
	},

	DateTime = {
		from_timestamp = date_time_new,
		from_timestamp_millis = date_time_millis_new,
	},

	Instance = {
		is_a = instance_is_a,
		wait_for_child = instance_wait_for_child,
		find_first_child = instance_find_first_child,
	},

	RemoteEvent = {
		fire_all = fire_all,
		fire_client = fire_client,
		fire_server = fire_server,
	},

	Players = {
		get_players = get_players,
	},

	DataModel = {
		get_service = get_service,
	},
})
