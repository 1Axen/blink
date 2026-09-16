--!strict

local types = require("@lir/types")

local constant = require("@builders/constant")
local projection = require("@builders/projection")
local ty = require("@ty")

type Call<T> = types.ProjCall<T>
type Namecall<T> = types.ProjNamecall<T>

type Writeable<T> = types.Writeable<T>
type Readable<T> = types.Readable<T>
type Constant<T> = types.Constant<T>

type Instance = ty.Instance

local function cframe_new_quat(
	x: Readable<number>,
	y: Readable<number>,
	z: Readable<number>,
	quat_x: Readable<number>,
	quat_y: Readable<number>,
	quat_z: Readable<number>,
	quat_w: Readable<number>
): Call<CFrame>
	return projection.call(constant.from_value("CFrame.new"), { x, y, z, quat_x, quat_y, quat_z, quat_w })
end

local function cframe_new_position(x: Readable<number>, y: Readable<number>, z: Readable<number>): Call<CFrame>
	return projection.call(constant.from_value("CFrame.new"), { x, y, z })
end

local function cframe_to_axis_angle(at: Readable<CFrame>): Namecall<number>
	return projection.namecall(at :: Writeable<any>, constant.from_value("ToAxisAngle"), {})
end

local function color3_from_HSV(hue: Readable<number>, sat: Readable<number>, val: Readable<number>): Call<Color3>
	return projection.call(constant.from_value("Color3.fromHSV"), { hue, sat, val })
end

local function color3_to_HSV(at: Readable<Color3>): Namecall<number>
	return projection.namecall(at :: Writeable<any>, constant.from_value("ToHSV"), {})
end

local function brick_color_new(number: Readable<number>): Call<BrickColor>
	return projection.call(constant.from_value("BrickColor.new"), { number })
end

local function date_time_new(timestamp: Readable<number>): Call<DateTime>
	return projection.call(constant.from_value("DateTime.fromUnixTimestamp"), { timestamp })
end

local function date_time_millis_new(timestamp_millis: Readable<number>): Call<DateTime>
	return projection.call(constant.from_value("DateTime.fromUnixTimestampMillis"), { timestamp_millis })
end

local function instance_is_a(at: Readable<Instance>, class: Constant<string>): Namecall<boolean>
	return projection.namecall(at :: Writeable<any>, constant.from_value("IsA"), { class } :: any)
end

local function instance_find_first_child(parent: Readable<Instance>, name: Readable<string>): Namecall<Instance?>
	return projection.namecall(parent :: Writeable<any>, constant.from_value("FindFirstChild"), { name })
end

local function instance_wait_for_child(parent: Readable<Instance>, name: Readable<string>): Namecall<Instance>
	return projection.namecall(parent :: Writeable<any>, constant.from_value("WaitForChild"), { name })
end

local function fire_all(remote: Readable<RemoteEvent>, args: { Readable<any> }): Namecall<nil>
	return projection.namecall(remote :: Writeable<any>, constant.from_value("FireAllClients"), args)
end

local function fire_client(remote: Readable<RemoteEvent>, args: { Readable<any> }): Namecall<nil>
	return projection.namecall(remote :: Writeable<any>, constant.from_value("FireClient"), args)
end

local function fire_server(remote: Readable<RemoteEvent>, args: { Readable<any> }): Namecall<nil>
	return projection.namecall(remote :: Writeable<any>, constant.from_value("FireServer"), args)
end

local function get_players(service: Readable<Players>): Namecall<{ Player }>
	return projection.namecall(service :: Writeable<any>, constant.from_value("GetPlayers"), {})
end

local function get_service<T>(name: Readable<string>): Namecall<T>
	return projection.namecall(constant.from_value("game"), constant.from_value("GetService"), { name })
end

return table.freeze({
	CFrame = {
		new_quat = cframe_new_quat,
		new_position = cframe_new_position,
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
