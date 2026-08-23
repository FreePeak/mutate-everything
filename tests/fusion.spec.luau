--!strict
-- Fusion math specs.

local function rarityOrderIndex(rarity: string): number
	local order = { "Common", "Uncommon", "Rare", "Epic", "Legendary", "Mythic", "MutantGod" }
	for index, name in order do
		if name == rarity then
			return index
		end
	end
	return -1
end

local function makeParent(uid: string, income: number, rarity: string, generation: number)
	return {
		uid = uid,
		name = "Slimelet",
		income = income,
		rarity = rarity,
		mutation = "None",
		colorA = Color3.fromRGB(100, 100, 100),
		colorB = Color3.fromRGB(50, 50, 50),
		scale = 1,
		generation = generation,
		parents = {},
	}
end

return function(describe, it, expect, req)
	local RNG = req("Util/RNG")
	local FusionMath = req("Util/FusionMath")

	describe("FusionMath.childRarity", function()
		it("returns the higher parent rarity without a bump", function()
			for seed = 1, 40 do
				local result = FusionMath.childRarity("Common", "Epic", RNG.new(seed))
				expect(rarityOrderIndex(result) >= 4).to.equal(true)
				expect(rarityOrderIndex(result) <= 5).to.equal(true)
			end
		end)

		it("never returns below the higher parent rarity across many rolls", function()
			for seed = 1, 300 do
				local result = FusionMath.childRarity("Common", "Mythic", RNG.new(seed))
				expect(rarityOrderIndex(result) >= 6).to.equal(true)
			end
		end)

		it("caps at MutantGod without erroring", function()
			for seed = 1, 300 do
				local ok, result = pcall(function()
					return FusionMath.childRarity("MutantGod", "MutantGod", RNG.new(seed))
				end)
				expect(ok).to.equal(true)
				if ok then
					expect(result).to.equal("MutantGod")
				end
			end
		end)

		it("sometimes bumps same-rarity parents upward", function()
			local bumped = false
			for seed = 1, 400 do
				local result = FusionMath.childRarity("Common", "Common", RNG.new(seed))
				if rarityOrderIndex(result) > 1 then
					bumped = true
				end
			end
			expect(bumped).to.equal(true)
		end)
	end)

	describe("FusionMath.rollMutation", function()
		it("usually returns None but can return mutations over many rolls", function()
			local seenNone = false
			local seenOther = false
			for seed = 1, 500 do
				local mutation = FusionMath.rollMutation(RNG.new(seed))
				if mutation == "None" then
					seenNone = true
				else
					seenOther = true
				end
			end
			expect(seenNone).to.equal(true)
			expect(seenOther).to.equal(true)
		end)
	end)

	describe("FusionMath.computeChild", function()
		it("advances generation to max(parents) + 1", function()
			local child = FusionMath.computeChild(
				makeParent("a", 10, "Common", 1),
				makeParent("b", 20, "Uncommon", 2),
				RNG.new(1),
				"child"
			)
			expect(child.generation).to.equal(3)
		end)

		it("keeps income within deterministic bounds for fixed inputs", function()
			local minIncome = math.huge
			local maxIncome = 0
			for seed = 1, 300 do
				local child = FusionMath.computeChild(
					makeParent("a", 10, "Common", 1),
					makeParent("b", 20, "Uncommon", 2),
					RNG.new(seed),
					"child_" .. seed
				)
				minIncome = math.min(minIncome, child.income)
				maxIncome = math.max(maxIncome, child.income)
			end

			-- Weighted avg 14.5; worst case Common x None x 0.9 roll -> ~13.
			expect(minIncome >= 12).to.equal(true)
			-- Best case Mythic bump (2.8) x Void (6) x 1.6 -> ~390.
			expect(maxIncome <= 420).to.equal(true)
		end)

		it("records both parent uids", function()
			local child = FusionMath.computeChild(
				makeParent("alpha", 10, "Common", 1),
				makeParent("beta", 20, "Common", 1),
				RNG.new(5),
				"child"
			)
			expect(child.parents[1]).to.equal("alpha")
			expect(child.parents[2]).to.equal("beta")
		end)

		it("blends colors within channel bounds", function()
			local red = makeParent("r", 10, "Common", 1)
			red.colorA = Color3.new(1, 0, 0)
			local green = makeParent("g", 10, "Common", 1)
			green.colorA = Color3.new(0, 1, 0)

			for seed = 1, 50 do
				local child = FusionMath.computeChild(red, green, RNG.new(seed), "c" .. seed)
				expect(child.colorA.R >= 0 and child.colorA.R <= 1).to.equal(true)
				expect(child.colorA.G >= 0 and child.colorA.G <= 1).to.equal(true)
			end
		end)
	end)
end
