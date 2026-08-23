--!strict
-- Rarity tiers: income multiplier for hybrids, conveyor spawn weights, and
-- display colors used by both client and server.

return {
	order = { "Common", "Uncommon", "Rare", "Epic", "Legendary", "Mythic", "MutantGod" },

	colors = {
		Common = Color3.fromRGB(180, 180, 180),
		Uncommon = Color3.fromRGB(88, 200, 90),
		Rare = Color3.fromRGB(70, 140, 255),
		Epic = Color3.fromRGB(170, 90, 255),
		Legendary = Color3.fromRGB(255, 170, 40),
		Mythic = Color3.fromRGB(255, 60, 120),
		MutantGod = Color3.fromRGB(255, 255, 255),
	},

	-- Hybrid fusion income multiplier applied when a child's rarity is set.
	incomeMultipliers = {
		Common = 1.0,
		Uncommon = 1.15,
		Rare = 1.35,
		Epic = 1.65,
		Legendary = 2.1,
		Mythic = 2.8,
		MutantGod = 4.0,
	},

	-- Relative probability of each rarity appearing on the conveyor.
	conveyorWeights = {
		Common = 46,
		Uncommon = 27,
		Rare = 16,
		Epic = 7,
		Legendary = 3,
		Mythic = 0.9,
		MutantGod = 0.1,
	},
}
