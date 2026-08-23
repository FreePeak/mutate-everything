--!strict
-- Creature ownership: catalog purchases, roster storage, conveyor spawning,
-- and the shared creature-view serialization used by remotes.

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local GameConfig = require(Shared.Config.GameConfig)
local Catalog = require(Shared.Config.CreatureCatalog)
local RarityConfig = require(Shared.Config.RarityConfig)
local RNG = require(Shared.Util.RNG)

local CreatureService = {}

local rng = RNG.new()

-- uid -> { ownerId, creature, model (Instance?) }
local liveCreatures: { [string]: any } = {}

CreatureService.CreatureAdded = nil :: any
CreatureService.CreatureRemoved = nil :: any

local uidCounter = 0
local function nextUid(prefix: string): string
	uidCounter += 1
	return ("%s_%d_%d"):format(prefix, os.clock() * 1000 % 1e9, uidCounter)
end

function CreatureService.Init()
	CreatureService.CreatureAdded = Instance.new("BindableEvent")
	CreatureService.CreatureRemoved = Instance.new("BindableEvent")
end

function CreatureService.Start()
	-- Conveyor: spawn a purchasable species every few seconds.
	task.spawn(function()
		while true do
			task.wait(4)
			local speciesId = CreatureService.RollConveyorSpecies()
			CreatureService.ConveyorSpawned:Fire(speciesId)
		end
	end)
end

CreatureService.ConveyorSpawned = Instance.new("BindableEvent")

function CreatureService.GetLive(uid: string): any
	return liveCreatures[uid]
end

function CreatureService.RegisterLive(ownerId: number, creature): ()
	liveCreatures[creature.uid] = {
		ownerId = ownerId,
		creature = creature,
	}
end

function CreatureService.UnregisterLive(uid: string)
	liveCreatures[uid] = nil
end

--- Weighted random species for the conveyor, weighted by rarity.
function CreatureService.RollConveyorSpecies(): string
	local weights = {}
	for _, entry in Catalog.species do
		weights[entry.id] = RarityConfig.conveyorWeights[entry.rarity] or 1
	end
	return rng:WeightedPick(weights)
end

--- Server-validated purchase. Returns (ok, reason).
function CreatureService.TryBuy(player: Player, speciesId: string, dataService): (boolean, string)
	local state = dataService.GetState(player.UserId)
	if not state then
		return false, "not_loaded"
	end

	if #state.creatures >= state.baseSlots then
		return false, "base_full"
	end

	local entry = Catalog.byId[speciesId]
	if not entry then
		return false, "unknown_species"
	end

	if not dataService.TrySpend(player.UserId, entry.cost) then
		return false, "insufficient_cash"
	end

	local creature = {
		uid = nextUid("c"),
		speciesId = entry.id,
		name = entry.name,
		income = entry.baseIncome,
		mutation = "None",
		rarity = entry.rarity,
		colorA = entry.bodyColor,
		colorB = entry.accentColor,
		scale = entry.scale,
		generation = 1,
		parents = {},
	}

	table.insert(state.creatures, creature)
	CreatureService.RegisterLive(player.UserId, creature)
	CreatureService.CreatureAdded:Fire(player, creature)
	return true, "ok"
end

function CreatureService.TrySell(player: Player, uid: string, dataService): (boolean, string)
	local state = dataService.GetState(player.UserId)
	if not state then
		return false, "not_loaded"
	end

	for index, creature in state.creatures do
		if creature.uid == uid then
			local catalogEntry = Catalog.byId[creature.speciesId]
			local cost = catalogEntry and catalogEntry.cost or math.floor(creature.income * 75)
			local refund = math.floor(cost * GameConfig.SellRefundFraction + 0.5)
			dataService.AddCash(player.UserId, refund)
			table.remove(state.creatures, index)
			CreatureService.UnregisterLive(uid)
			CreatureService.CreatureRemoved:Fire(uid)
			return true, "ok"
		end
	end
	return false, "not_owned"
end

--- Client-facing view of a creature (no server-only fields).
function CreatureService.Serialize(creature)
	return {
		uid = creature.uid,
		name = creature.name,
		income = creature.income,
		mutation = creature.mutation,
		rarity = creature.rarity,
		generation = creature.generation,
	}
end

return CreatureService
