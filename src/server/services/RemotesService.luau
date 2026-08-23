--!strict
-- Creates and owns all RemoteEvents/Functions. Other services never touch the
-- ReplicatedStorage remotes folder directly; they go through this API.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = {}

local remoteNames = {
	StateChanged = "RemoteEvent",
	Notify = "RemoteEvent",
	Announce = "RemoteEvent",
	ConveyorSpawned = "RemoteEvent",
	FusionComplete = "RemoteEvent",
	GetState = "RemoteFunction",
	RequestBuy = "RemoteFunction",
	RequestSell = "RemoteFunction",
	RequestFuse = "RemoteFunction",
	RequestLock = "RemoteFunction",
	RequestSteal = "RemoteFunction",
	RequestRebirth = "RemoteFunction",
}

local container

function Remotes.Init()
	container = Instance.new("Folder")
	container.Name = "Remotes"
	for name, className in remoteNames do
		local remote = Instance.new(className)
		remote.Name = name
		remote.Parent = container
	end
	container.Parent = ReplicatedStorage
end

function Remotes.Get(name: string)
	return container:WaitForChild(name)
end

--- Fire a RemoteEvent at one player.
function Remotes.Fire(name: string, player: Player, ...)
	(container[name] :: any):FireClient(player, ...)
end

--- Fire a RemoteEvent at everyone.
function Remotes.FireAll(name: string, ...)
	(container[name] :: any):FireAllClients(...)
end

--- Register a server handler on a RemoteFunction.
function Remotes.OnRequest(name: string, handler: (player: Player, ...any) -> any)
	(container[name] :: any).OnServerInvoke = handler
end

return Remotes
