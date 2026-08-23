--!strict
-- Owns per-player session state and persists it to DataStore with pcall
-- guards. Falls back to session-only state when the DataStore is unavailable
-- (Studio without API access, offline).

local Players = game:GetService("Players")
local DataStoreService = game:GetService("DataStoreService")
local RunService = game:GetService("RunService")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local GameConfig = require(Shared.Config.GameConfig)
local EconomyMath = require(Shared.Util.EconomyMath)

local DataService = {}

local store: any = nil
local sessions: { [number]: any } = {}

-- Signals other services can observe.
DataService.PlayerInitialized = nil :: any
DataService.PlayerRemoving = nil :: any

local function defaultState(userId: number)
	return {
		userId = userId,
		cash = GameConfig.StartCash,
		rebirths = 0,
		incomeMultiplier = 1,
		baseSlots = EconomyMath.baseSlots(0, GameConfig.BaseSlotsPerRebirth),
		lastLockTime = 0,
		lockExpireAt = 0,
		unlockCooldownUntil = 0,
		creatures = {}, -- array of serialized creature tables
		totalEarned = 0,
	}
end

function DataService.Init()
	DataService.PlayerInitialized = Instance.new("BindableEvent")
	DataService.PlayerRemoving = Instance.new("BindableEvent")

	local ok, result = pcall(function()
		return DataStoreService:GetDataStore("MutateEverything_v1")
	end)
	if ok then
		store = result
	elseif not RunService:IsStudio() then
		warn("[DataService] DataStore unavailable; running session-only")
	end

	Players.PlayerAdded:Connect(function(player)
		DataService.LoadPlayer(player)
	end)
	for _, player in Players:GetPlayers() do
		task.spawn(DataService.LoadPlayer, player)
	end
	Players.PlayerRemoving:Connect(function(player)
		DataService.SavePlayer(player)
		sessions[player.UserId] = nil
		DataService.PlayerRemoving:Fire(player)
	end)
end

function DataService.Start() end

function DataService.LoadPlayer(player: Player)
	local userId = player.UserId
	if sessions[userId] then
		return sessions[userId]
	end

	local state = defaultState(userId)

	if store then
		local ok, saved = pcall(function()
			return store:GetAsync("player_" .. userId)
		end)
		if ok and type(saved) == "table" then
			state.cash = tonumber(saved.cash) or state.cash
			state.rebirths = tonumber(saved.rebirths) or 0
			state.totalEarned = tonumber(saved.totalEarned) or 0
			state.incomeMultiplier = 1 + state.rebirths * GameConfig.RebirthIncomeBonus
			state.baseSlots = EconomyMath.baseSlots(state.rebirths, GameConfig.BaseSlotsPerRebirth)
			if type(saved.creatures) == "table" then
				state.creatures = saved.creatures
			end
		end
	end

	sessions[userId] = state
	DataService.PlayerInitialized:Fire(player, state)
	return state
end

function DataService.GetState(userId: number): any
	return sessions[userId]
end

function DataService.AddCash(userId: number, amount: number): number
	local state = sessions[userId]
	if not state or amount < 0 then
		return -1
	end
	state.cash += amount
	state.totalEarned += math.max(0, amount)
	return state.cash
end

--- Returns false if the player cannot afford `cost`.
function DataService.TrySpend(userId: number, cost: number): boolean
	local state = sessions[userId]
	if not state or state.cash < cost or cost < 0 then
		return false
	end
	state.cash -= cost
	return true
end

function DataService.SavePlayer(player: Player)
	local state = sessions[player.UserId]
	if not state or not store then
		return
	end
	pcall(function()
		store:SetAsync("player_" .. player.UserId, {
			cash = state.cash,
			rebirths = state.rebirths,
			totalEarned = state.totalEarned,
			creatures = state.creatures,
		})
	end)
end

--- Autosave loop for everyone online.
function DataService.StartAutosave(intervalSeconds: number)
	task.spawn(function()
		while true do
			task.wait(intervalSeconds)
			for _, player in Players:GetPlayers() do
				DataService.SavePlayer(player)
			end
		end
	end)
end

return DataService
