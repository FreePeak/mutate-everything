--!strict
-- Server bootstrap: two-phase lifecycle (Init then Start) with explicit
-- dependency wiring so there are no circular requires and no init races.

local Players = game:GetService("Players")

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local GameConfig = require(Shared.Config.GameConfig)
local EconomyMath = require(Shared.Util.EconomyMath)
local Catalog = require(Shared.Config.CreatureCatalog)

local ServicesFolder = script.Parent:WaitForChild("services")

local RemotesService = require(ServicesFolder.RemotesService)
local DataService = require(ServicesFolder.DataService)
local CreatureService = require(ServicesFolder.CreatureService)
local FusionService = require(ServicesFolder.FusionService)
local TheftService = require(ServicesFolder.TheftService)
local BaseService = require(ServicesFolder.BaseService)
local EconomyService = require(ServicesFolder.EconomyService)

-- ---------------------------------------------------------------- helpers

local function buildStatePayload(player: Player)
	local state = DataService.GetState(player.UserId)
	if not state then
		return nil
	end
	local roster = {}
	for _, creature in state.creatures do
		table.insert(roster, CreatureService.Serialize(creature))
	end
	local now = os.clock()
	return {
		cash = state.cash,
		rebirths = state.rebirths,
		incomeMultiplier = state.incomeMultiplier,
		baseSlots = state.baseSlots,
		rosterSize = #state.creatures,
		totalIncome = EconomyService.RosterIncome(state) * state.incomeMultiplier,
		rebirthRequirement = EconomyMath.rebirthRequirement(
			state.rebirths,
			GameConfig.RebirthCashRequirementBase,
			GameConfig.RebirthRequirementGrowth
		),
		lockExpireIn = math.max(0, state.lockExpireAt - now),
		unlockCooldownIn = math.max(0, state.unlockCooldownUntil - now),
		roster = roster,
	}
end

local function broadcastState(player: Player)
	local payload = buildStatePayload(player)
	if payload then
		RemotesService.Fire("StateChanged", player, payload)
	end
end

local function announce(player: Player, message: string, kind: string)
	RemotesService.FireAll("Announce", message, kind or "info")
end

-- ------------------------------------------------------------------- Init

RemotesService.Init()
DataService.Init()
CreatureService.Init()
FusionService.Init()
BaseService.Init()
TheftService.Init({
	BaseService = BaseService,
	CreatureService = CreatureService,
	DataService = DataService,
	Announce = announce,
})

-- ------------------------------------------------------- remote handlers

RemotesService.OnRequest("GetState", function(player)
	return buildStatePayload(player)
end)

RemotesService.OnRequest("RequestBuy", function(player, speciesId)
	if type(speciesId) ~= "string" then
		return false, "bad_request"
	end
	local ok, reason = CreatureService.TryBuy(player, speciesId, DataService)
	broadcastState(player)
	return ok, reason
end)

RemotesService.OnRequest("RequestSell", function(player, uid)
	if type(uid) ~= "string" then
		return false, "bad_request"
	end
	local ok, reason = CreatureService.TrySell(player, uid, DataService)
	BaseService.RemoveCreatureModel(uid)
	broadcastState(player)
	return ok, reason
end)

RemotesService.OnRequest("RequestFuse", function(player, uidA, uidB)
	if type(uidA) ~= "string" or type(uidB) ~= "string" then
		return false, nil, "bad_request"
	end
	local child, reason = FusionService.Fuse(player, uidA, uidB, CreatureService, DataService)
	if child then
		BaseService.SpawnCreatureModel(player, child)
		RemotesService.Fire("FusionComplete", player, CreatureService.Serialize(child))
		if child.income >= GameConfig.AnnounceThreshold then
			announce(
				player,
				("%s fused %s | $%s/s %s!"):format(
					player.DisplayName,
					child.name,
					tostring(child.income),
					child.rarity
				),
				"fusion"
			)
		end
	else
		RemotesService.Fire("Notify", player, reason, "error")
	end
	broadcastState(player)
	return child ~= nil, child and CreatureService.Serialize(child) or nil, reason
end)

RemotesService.OnRequest("RequestLock", function(player)
	local ok, reason = TheftService.TryLock(player)
	if not ok then
		RemotesService.Fire("Notify", player, reason, "error")
	end
	broadcastState(player)
	return ok, reason
end)

RemotesService.OnRequest("RequestSteal", function(player, ownerId, uid)
	if type(ownerId) ~= "number" or type(uid) ~= "string" then
		return false, "bad_request"
	end
	local ok, reason = TheftService.TrySteal(player, ownerId, uid)
	if not ok then
		RemotesService.Fire("Notify", player, reason, "error")
	end
	return ok, reason
end)

RemotesService.OnRequest("RequestDefend", function(player, thiefUserId)
	if type(thiefUserId) ~= "number" then
		return false, "bad_request"
	end
	local ok, reason = TheftService.TryDefend(player, thiefUserId)
	if not ok then
		RemotesService.Fire("Notify", player, reason, "error")
	end
	broadcastState(player)
	return ok, reason
end)

RemotesService.OnRequest("RequestRebirth", function(player)
	local ok, reason = EconomyService.TryRebirth(player, DataService, CreatureService)
	if ok then
		local state = DataService.GetState(player.UserId)
		announce(player, ("%s REBIRTHED. Income x%.2f"):format(player.DisplayName, state.incomeMultiplier), "rebirth")
	end
	broadcastState(player)
	return ok, reason
end)

-- ---------------------------------------------------------------- events

DataService.PlayerInitialized.Event:Connect(function(player, _state)
	BaseService.AssignPlot(player, #Players:GetPlayers())

	-- Materialize saved creatures onto the new plot.
	local state = DataService.GetState(player.UserId)
	if state then
		for _, creature in state.creatures do
			CreatureService.RegisterLive(player.UserId, creature)
			BaseService.SpawnCreatureModel(player, creature)
		end
	end

	RemotesService.Fire("StateChanged", player, buildStatePayload(player))
end)

DataService.PlayerRemoving.Event:Connect(function(player)
	TheftService.OnPlayerRemoving(player)
	BaseService.ReleasePlot(player.UserId)
end)

-- Conveyor: physical pedestal display + purchase path.
CreatureService.ConveyorSpawned.Event:Connect(function(speciesId)
	local entry = Catalog.byId[speciesId]
	if entry then
		BaseService.SetConveyorDisplay(entry)
	end
end)

BaseService.ConveyorPurchaseRequested.Event:Connect(function(player, speciesId)
	local ok, reason = CreatureService.TryBuy(player, speciesId, DataService)
	if not ok then
		RemotesService.Fire("Notify", player, reason, "error")
	else
		broadcastState(player)
	end
end)

BaseService.DefendRequested.Event:Connect(function(defender, thiefUserId)
	local ok, _reason = TheftService.TryDefend(defender, thiefUserId)
	broadcastState(defender)
	if ok then
		broadcastState(Players:GetPlayerByUserId(thiefUserId))
	end
end)

BaseService.StealRequested.Event:Connect(function(player, uid)
	local live = CreatureService.GetLive(uid)
	if not live then
		return
	end
	local ok, reason = TheftService.TrySteal(player, live.ownerId, uid)
	if not ok then
		RemotesService.Fire("Notify", player, reason, "error")
	else
		broadcastState(player)
	end
end)

CreatureService.CreatureAdded.Event:Connect(function(player, creature)
	BaseService.SpawnCreatureModel(player, creature)
end)

CreatureService.CreatureRemoved.Event:Connect(function(uid)
	BaseService.RemoveCreatureModel(uid)
end)

BaseService.PlayerTouchedPad.Event:Connect(function(player)
	-- Touching your own pad secures a carried steal; touching someone else's
	-- pad while they carry nothing does nothing.
	TheftService.TrySecure(player)
	broadcastState(player)
end)

-- ----------------------------------------------------------------- Start

DataService.StartAutosave(60)
TheftService.Start()
CreatureService.Start()
EconomyService.Start({
	DataService = DataService,
	TheftService = TheftService,
	BroadcastState = function()
		for _, player in Players:GetPlayers() do
			broadcastState(player)
		end
	end,
	Announce = announce,
})
BaseService.Start()

print("[MUTATE] server initialized")
