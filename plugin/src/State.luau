--!strict

-- ******************************* --
-- 			AX3NX / AXEN		   --
-- ******************************* --

---- Services ----

---- Imports ----

---- Settings ----

---- Constants ----

local State = {}
State.__index = State

export type Class<T> = typeof(setmetatable(
	{} :: {
		Value: T,
		Observers: { [(T) -> ()]: boolean },
	},
	State
))

---- Variables ----

---- Private Functions ----

---- Public Functions ----

function State.new<T>(Value: T): Class<T>
	return setmetatable({
		Value = Value,
		Observers = {},
	}, State)
end

function State.Get<T>(self: Class<T>): T
	return self.Value
end

function State.Set<T>(self: Class<T>, Value: T)
	if self.Value ~= Value or type(Value) == "table" then
		self.Value = Value
		self:_updateObservers()
	end
end

function State.OnChange<T>(self: Class<T>, Observer: (T) -> ()): () -> ()
	self.Observers[Observer] = true
	task.defer(function()
		self:_updateObservers()
	end)

	return function()
		self.Observers[Observer] = nil
	end
end

function State._updateObservers<T>(self: Class<T>)
	for Observer in self.Observers do
		task.spawn(Observer, self.Value)
	end
end

---- Initialization ----

---- Connections ----

return State
