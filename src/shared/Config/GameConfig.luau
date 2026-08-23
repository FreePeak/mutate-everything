--!strict
-- Central tuning knobs. Everything server-side reads from here; the client
-- mirrors it for UI display. Change values here to rebalance the whole game.

local GameConfig = {
	-- Economy
	StartCash = 25,
	TickRateSeconds = 1,
	SellRefundFraction = 0.6,

	-- Base
	BaseSlotsPerRebirth = 8,
	BaseSlotRowsPerRebirth = 1,
	LockDurationSeconds = 45,
	LockCooldownSeconds = 60,
	LockMinLevel = 0,

	-- Stealing
	CarrySpeedMultiplier = 0.75,
	StealStunSeconds = 4,
	TheftImmunitySecondsOnSpawn = 30,

	-- Fusion
	FusionCostBase = 50,
	FusionCostPerGeneration = 25,
	FusionDurationSeconds = 5,

	-- Rebirth
	RebirthCashRequirementBase = 10_000,
	RebirthRequirementGrowth = 4,
	RebirthIncomeBonus = 0.25, -- +25% per rebirth
	RebirthKeepCreatures = false,

	-- Announcements: broadcast purchases/thefts/fusions above this cash value
	AnnounceThreshold = 500,
}

export type GameConfigType = typeof(GameConfig)

return GameConfig
