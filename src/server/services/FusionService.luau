--!strict
-- Fuses two creatures from a player's roster into a procedurally generated
-- hybrid using the pure FusionMath module. Consumes both parents.

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local GameConfig = require(Shared.Config.GameConfig)
local FusionMath = require(Shared.Util.FusionMath)
local RNG = require(Shared.Util.RNG)

local FusionService = {}

local rng = RNG.new()

function FusionService.Init() end

function FusionService.Start() end

--- Fuse two roster creatures by uid. Returns (child, reason).
--- reason is "ok" on success, otherwise an error code.
function FusionService.Fuse(player: Player, uidA: string, uidB: string, creatureService, dataService)
	local state = dataService.GetState(player.UserId)
	if not state then
		return nil, "not_loaded"
	end
	if uidA == uidB then
		return nil, "same_creature"
	end

	local indexA, indexB
	for index, creature in state.creatures do
		if creature.uid == uidA then
			indexA = index
		elseif creature.uid == uidB then
			indexB = index
		end
	end

	if not indexA or not indexB then
		return nil, "missing_parent"
	end

	local fusionCost = GameConfig.FusionCostBase
		+ GameConfig.FusionCostPerGeneration * math.max(
			state.creatures[indexA].generation,
			state.creatures[indexB].generation
		)

	if not dataService.TrySpend(player.UserId, fusionCost) then
		return nil, "insufficient_cash"
	end

	local parentA = table.remove(state.creatures, math.max(indexA, indexB))
	local parentB = table.remove(state.creatures, math.min(indexA, indexB))

	creatureService.UnregisterLive(parentA.uid)
	creatureService.UnregisterLive(parentB.uid)
	creatureService.CreatureRemoved:Fire(parentA.uid)
	creatureService.CreatureRemoved:Fire(parentB.uid)

	local child = FusionMath.computeChild(parentA, parentB, rng, ("h_%d_%d"):format(player.UserId, os.clock() * 1000 % 1e9))
	table.insert(state.creatures, child)
	creatureService.RegisterLive(player.UserId, child)
	creatureService.CreatureAdded:Fire(player, child)

	return child, "ok"
end

return FusionService
