--!strict
-- Pure fusion math. No Roblox instances touched, so this is fully unit-testable
-- under lune. The server calls these functions with catalog data.
--
-- Dependencies resolve lazily through script.Parent in-game; headless test
-- runners call FusionMath.configure() first to inject them by path.

local FusionRules = {
	-- Chance the child bumps one rarity above the higher parent.
	rarityBumpChance = 0.18,
	-- Chance of a rare double-bump when both parents share the same rarity.
	doubleBumpChance = 0.05,
	-- Income roll range applied to the weighted parent average.
	incomeRollMin = 0.9,
	incomeRollMax = 1.6,
	-- Mutation chances (checked in order; first hit wins).
	mutationChances = {
		Void = 0.01,
		Cosmic = 0.04,
		Neon = 0.10,
	},
	-- Mutation income multipliers (stack on top of rarity multiplier).
	mutationIncomeMultipliers = {
		None = 1.0,
		Neon = 1.5,
		Cosmic = 3.0,
		Void = 6.0,
	},
	-- Child scale blends parents plus jitter.
	scaleJitterMin = 0.92,
	scaleJitterMax = 1.08,
	maxGeneration = 99,
}

local RarityConfig = nil
local NameGenerator = nil

local function ensureDeps()
	if not RarityConfig then
		RarityConfig = require(script.Parent.Parent.Config.RarityConfig)
		NameGenerator = require(script.Parent.NameGenerator)
	end
end

local FusionMath = {}

--- Dependency injection for headless test runners (lune): configure the
--- modules directly by path. Optional in-game.
function FusionMath.configure(deps)
	if deps.RarityConfig ~= nil then
		RarityConfig = deps.RarityConfig
	end
	if deps.NameGenerator ~= nil then
		NameGenerator = deps.NameGenerator
	end
end

FusionMath.rules = FusionRules

local function rarityIndex(rarity: string): number
	ensureDeps()
	for index, name in RarityConfig.order do
		if name == rarity then
			return index
		end
	end
	return 1
end

local function rarityAt(index: number): string
	return RarityConfig.order[math.clamp(index, 1, #RarityConfig.order)]
end

--- Compute the child's rarity from both parents' rarities.
function FusionMath.childRarity(rarityA: string, rarityB: string, rng: any): string
	local highIndex = math.max(rarityIndex(rarityA), rarityIndex(rarityB))
	local sameRarity = rarityA == rarityB

	if sameRarity and rng:Chance(FusionRules.doubleBumpChance) then
		return rarityAt(highIndex + 2)
	end
	if rng:Chance(FusionRules.rarityBumpChance) then
		return rarityAt(highIndex + 1)
	end
	return rarityAt(highIndex)
end

--- Roll the child's mutation (first hit wins; usually None).
function FusionMath.rollMutation(rng: any): string
	for _, mutation in { "Void", "Cosmic", "Neon" } do
		if rng:Chance(FusionRules.mutationChances[mutation]) then
			return mutation
		end
	end
	return "None"
end

--- Core fusion computation. Returns a plain data table the caller turns into
--- a Creature instance. `parentA`/`parentB` are Creature-shaped tables.
function FusionMath.computeChild(parentA, parentB, rng: any, newUid: string)
	ensureDeps()

	local rarity = FusionMath.childRarity(parentA.rarity or "Common", parentB.rarity or "Common", rng)
	local mutation = FusionMath.rollMutation(rng)

	-- Weighted average favors the stronger parent slightly (55/45).
	local avgIncome = (parentA.income * 0.55) + (parentB.income * 0.45)

	local rarityMult = RarityConfig.incomeMultipliers[rarity] or 1
	local mutationMult = FusionRules.mutationIncomeMultipliers[mutation] or 1
	local roll = rng:NextNumber(FusionRules.incomeRollMin, FusionRules.incomeRollMax)

	local income = math.floor(avgIncome * rarityMult * mutationMult * roll + 0.5)
	income = math.max(1, income)

	local scale = ((parentA.scale or 1) + (parentB.scale or 1)) / 2
		* rng:NextNumber(FusionRules.scaleJitterMin, FusionRules.scaleJitterMax)

	local baseName = NameGenerator.blend(parentA.name or "Blob", parentB.name or "Blob")
	local displayName = NameGenerator.withMutation(baseName, mutation)

	local generation = math.min(
		FusionRules.maxGeneration,
		math.max(parentA.generation or 1, parentB.generation or 1) + 1
	)

	-- Child color: channel-wise blend toward the dominant parent.
	local blendT = rng:NextNumber(0.35, 0.65)
	local colorA = Color3.new(
		parentA.colorA.R * blendT + parentB.colorA.R * (1 - blendT),
		parentA.colorA.G * blendT + parentB.colorA.G * (1 - blendT),
		parentA.colorA.B * blendT + parentB.colorA.B * (1 - blendT)
	)

	return {
		uid = newUid,
		speciesId = "hybrid",
		name = displayName,
		income = income,
		mutation = mutation,
		colorA = colorA,
		colorB = Color3.fromHSV((income * 0.091) % 1, 0.7, 1),
		scale = math.clamp(scale, 0.5, 4),
		generation = generation,
		parents = { parentA.uid or "?", parentB.uid or "?" },
		rarity = rarity,
	}
end

return FusionMath
