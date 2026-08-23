--!strict
-- Client network layer: wraps all remote calls behind one controller and
-- exposes typed signals for the UI to subscribe to.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Signal = require(ReplicatedStorage.Shared.Signal)

local Network = {}

Network.StateChanged = nil :: any
Network.Announced = nil :: any
Network.Notified = nil :: any
Network.FusionComplete = nil :: any

function Network.Init()
	Network.StateChanged = Signal.new()
	Network.Announced = Signal.new()
	Network.Notified = Signal.new()
	Network.FusionComplete = Signal.new()

	local remotes = ReplicatedStorage:WaitForChild("Remotes")

	local stateRemote = (remotes :: any).StateChanged
	stateRemote.OnClientEvent:Connect(function(payload)
		Network.StateChanged:Fire(payload)
	end)
	remotes.Announce.OnClientEvent:Connect(function(message, kind)
		Network.Announced:Fire(message, kind)
	end)
	remotes.Notify.OnClientEvent:Connect(function(reason, kind)
		Network.Notified:Fire(reason, kind)
	end)
	remotes.FusionComplete.OnClientEvent:Connect(function(childView)
		Network.FusionComplete:Fire(childView)
	end)
end

local function invoke(name: string, ...): any
	local remotes = ReplicatedStorage:WaitForChild("Remotes")
	local remote = remotes:FindFirstChild(name)
	if not remote then
		warn("[Network] missing remote " .. name)
		return nil
	end
	return (remote :: any):InvokeServer(...)
end

function Network.GetState()
	return invoke("GetState")
end

function Network.RequestBuy(speciesId: string)
	return invoke("RequestBuy", speciesId)
end

function Network.RequestSell(uid: string)
	return invoke("RequestSell", uid)
end

function Network.RequestFuse(uidA: string, uidB: string)
	return invoke("RequestFuse", uidA, uidB)
end

function Network.RequestLock()
	return invoke("RequestLock")
end

function Network.RequestSteal(ownerId: number, uid: string)
	return invoke("RequestSteal", ownerId, uid)
end

function Network.RequestRebirth()
	return invoke("RequestRebirth")
end

return Network
