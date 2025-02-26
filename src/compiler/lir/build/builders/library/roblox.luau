--!strict

local lir = require("@structures/lir")

local constant = require("@builders/constant")
local projection = require("@builders/projection")

type Call<T> = lir.ProjCall<T>
type Namecall<T> = lir.ProjNamecall<T>

type LValue<T> = lir.LValue<T>
type RValue<T> = lir.RValue<T>
type Constant<T> = lir.Constant<T>

local function cframe_new_quat(
    x: RValue<number>, 
    y: RValue<number>, 
    z: RValue<number>,
    quat_x: RValue<number>,
    quat_y: RValue<number>,
    quat_z: RValue<number>,
    quat_w: RValue<number>
): Call<CFrame>
    return projection.call(
        constant.from_value("CFrame.new"), 
        {x, y, z, quat_x, quat_y, quat_z, quat_w} :: any
    )
end

local function cframe_to_axis_angle(at: RValue<CFrame>): Namecall<number>
    return projection.namecall(
        at :: LValue<any>,
        constant.from_value("ToAxisAngle"),
        {}
    ) :: Namecall<number>
end

local function color3_from_HSV(
    hue: RValue<number>,
    sat: RValue<number>,
    val: RValue<number>
): Call<Color3>
    return projection.call(
        constant.from_value("Color3.fromHSV"),
        {hue, sat, val} :: any
    )
end

local function color3_to_HSV(at: RValue<Color3>): Namecall<number>
    return projection.namecall(
        at :: LValue<any>,
        constant.from_value("ToHSV"),
        {}
    ) :: Namecall<number>
end

local function brick_color_new(number: RValue<number>): Call<BrickColor>
    return projection.call(
        constant.from_value("BrickColor.new"),
        {number} :: any
    )
end

local function date_time_new(timestamp: RValue<number>): Call<DateTime>
    return projection.call(
        constant.from_value("DateTime.fromUnixTimestamp"),
        {timestamp} :: any
    )
end

local function date_time_millis_new(timestamp_millis: RValue<number>): Call<DateTime>
    return projection.call(
        constant.from_value("DateTime.fromUnixTimestampMillis"),
        {timestamp_millis} :: any
    )
end

local function instance_is_a(at: RValue<Instance>, class: Constant<string>): Namecall<boolean>
    return projection.namecall(
        at :: LValue<any>, 
        constant.from_value("IsA"), 
        {class} :: any
    ) :: Namecall<boolean>
end

return table.freeze({
    CFrame = {
        new_quat = cframe_new_quat,
        to_axis_angle = cframe_to_axis_angle,
    },

    Color3 = {
        from_HSV = color3_from_HSV,
        to_HSV = color3_to_HSV
    },

    BrickColor = {
        new = brick_color_new
    },

    DateTime = {
        from_timestamp = date_time_new,
        from_timestamp_millis = date_time_millis_new,
    },

    Instance = {
        is_a = instance_is_a,
    }
})