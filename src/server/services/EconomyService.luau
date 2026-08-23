--!strict
-- Income ticks, rebirth handling, and global announcements. The single
-- server-authoritative money source.

local Players = game:GetService("Players")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local GameConfig = require(Shared.Config.GameConfig)
local EconomyMath = require(Shared.Util.EconomyMath)

local EconomyService = {}

function EconomyService.Init() end

--- Compute a player's total per-second income from their roster.
function EconomyService.RosterIncome(state): number
	local total = 0
	for _, creature in state.creatures do
		total += creature.income
	end
	return total
end

function EconomyService.Start(deps)
	-- Master income tick.
	task.spawn(function()
		while true do
			task.wait(GameConfig.TickRateSeconds)
			for _, player in Players:GetPlayers() do
				local state = deps.DataService.GetState(player.UserId)
				if state then
					local income = EconomyMath.incomeFor(
						EconomyService.RosterIncome(state),
						GameConfig.TickRateSeconds,
						state.incomeMultiplier
					)
					if income > 0 then
						deps.DataService.AddCash(player.UserId, income)
					end
				end
			end
			deps.BroadcastState()
		end
	end)

	-- Lock expiry watcher.
	task.spawn(function()
		while true do
			task.wait(1)
			for _, player in Players:GetPlayers() do
				local state = deps.DataService.GetState(player.UserId)
				if state and state.lockExpireAt > 0 and os.clock() >= state.lockExpireAt then
					deps.TheftService.OnLockExpired(player.UserId)
					deps.Announce(
						player,
						player.DisplayName .. "'s base is OPEN. Raid time.",
						"danger"
					)
				end
			end
		end
	end)
end

--- Rebirth: reset cash + roster for permanent income multiplier and slots.
function EconomyService.TryRebirth(player: Player, dataService, creatureService): (boolean, string)
	local state = dataService.GetState(player.UserId)
	if not state then
		return false, "not_loaded"
	end

	local requirement = EconomyMath.rebirthRequirement(
		state.rebirths,
		GameConfig.RebirthCashRequirementBase,
		GameConfig.RebirthRequirementGrowth
	)

	if state.cash < requirement then
		return false, "insufficient_cash"
	end

	if not GameConfig.RebirthKeepCreatures then
		for _, creature in state.creatures do
			creatureService.UnregisterLive(creature.uid)
			creatureService.CreatureRemoved:Fire(creature.uid)
		end
		table.clear(state.creatures)
	end

	state.rebirths += 1
	state.cash = GameConfig.StartCash
	state.incomeMultiplier = 1 + state.rebirths * GameConfig.RebirthIncomeBonus
	state.baseSlots = EconomyMath.baseSlots(state.rebirths, GameConfig.BaseSlotsPerRebirth)

	return true, "ok"
end

return EconomyService
