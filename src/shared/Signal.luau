--!strict
-- Minimal typed signal implementation (no RBXScriptSignal dependency so it
-- runs headless under lune for unit tests).

export type Connection = {
	Disconnect: (self: Connection) -> (),
	Connected: boolean,
}

local Signal = {}
Signal.__index = Signal

export type Signal<T...> = {
	Connect: (self: Signal<T...>, fn: (T...) -> ()) -> Connection,
	Fire: (self: Signal<T...>, T...) -> (),
	Destroy: (self: Signal<T...>) -> (),
}

function Signal.new<T...>(): Signal<T...>
	local self = setmetatable({
		_handlers = {} :: { [Connection]: (T...) -> () },
	}, Signal)
	return (self :: any) :: Signal<T...>
end

function Signal:Connect(fn)
	local connection = {}
	connection.Connected = true
	function connection.Disconnect(c: Connection)
		c.Connected = false
	end
	self._handlers[connection] = fn
	return setmetatable(connection, {
		__index = function(_, key)
			if key == "Connected" then
				return connection.Connected
			end
			return nil
		end,
	})
end

function Signal:Fire(...)
	for connection, fn in self._handlers do
		if connection.Connected then
			task.spawn(fn, ...)
		else
			self._handlers[connection] = nil
		end
	end
end

function Signal:Destroy()
	for connection in self._handlers do
		connection.Connected = false
	end
	table.clear(self._handlers)
end

return Signal
