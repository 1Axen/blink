local date_time = {}
date_time.__index = date_time

type DateTimeMock = setmetatable<{
	UnixTimestamp: number,
	UnixTimestampMillis: number,
}, typeof(date_time)>

function date_time.fromUnixTimestamp(timestamp: number)
	return setmetatable({
		UnixTimestamp = timestamp,
		UnixTimestampMillis = timestamp // 1000,
	}, date_time)
end

function date_time.fromUnixTimestampMillis(timestamp: number)
	return setmetatable({
		UnixTimestamp = (timestamp * 1000) // 1,
		UnixTimestampMillis = timestamp,
	}, date_time)
end

function date_time.__eq(self: DateTimeMock, value: DateTimeMock)
	return self.UnixTimestamp == value.UnixTimestamp or self.UnixTimestampMillis == value.UnixTimestampMillis
end

function date_time.__tostring(self: DateTimeMock)
	return `DateTime({self.UnixTimestamp}, {self.UnixTimestampMillis})`
end

return date_time
