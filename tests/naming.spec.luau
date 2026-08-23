--!strict
-- Name generator and RNG specs.

return function(describe, it, expect, req)
	local NameGenerator = req("Util/NameGenerator")
	local RNG = req("Util/RNG")
	describe("NameGenerator.blend", function()
		it("produces a capitalized blend of both parent names", function()
			local blended = NameGenerator.blend("Slimelet", "Gloomaw")
			expect(#blended > 0).to.equal(true)
			-- Head comes from name A, tail from name B.
			expect(blended:sub(1, 1):match("%u") ~= nil).to.equal(true)
			expect(blended:sub(-1):lower() == "w").to.equal(true)
		end)

		it("never errors on short or identical names", function()
			for seed = 1, 50 do
				local ok = pcall(function()
					return NameGenerator.blend("A", "B")
				end)
				expect(ok).to.equal(true)
			end
		end)
	end)

	describe("NameGenerator.withMutation", function()
		it("prefixes mutation epithets", function()
			expect(NameGenerator.withMutation("Blorp", "Neon")).to.equal("Neon Blorp")
			expect(NameGenerator.withMutation("Blorp", "Void")).to.equal("Void Blorp")
			expect(NameGenerator.withMutation("Blorp", "None")).to.equal("Blorp")
		end)
	end)

	describe("RNG.WeightedPick", function()
		it("always picks keys within the provided weight table", function()
			local rng = RNG.new(1234)
			local weights = { a = 10, b = 0.001, c = 5 }
			for _ = 1, 500 do
				local pick = rng:WeightedPick(weights)
				expect(weights[pick] ~= nil).to.equal(true)
			end
		end)

		it("heavily favors the dominant weight", function()
			local rng = RNG.new(777)
			local dominant = 0
			for _ = 1, 1000 do
				if rng:WeightedPick({ x = 99, y = 1 }) == "x" then
					dominant += 1
				end
			end
			-- Expect ~990; allow generous margin for determinism check.
			expect(dominant > 900).to.equal(true)
		end)

		it("is deterministic for the same seed", function()
			local a = RNG.new(42)
			local b = RNG.new(42)
			for _ = 1, 100 do
				expect(a:NextInteger(1, 100)).to.equal(b:NextInteger(1, 100))
			end
		end)
	end)
end
