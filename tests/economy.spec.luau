--!strict
-- Economy math specs.

return function(describe, it, expect, req)
	local EconomyMath = req("Util/EconomyMath")
	describe("EconomyMath.incomeFor", function()
		it("computes floor of rate * time * multiplier", function()
			expect(EconomyMath.incomeFor(10, 5, 1)).to.equal(50)
			expect(EconomyMath.incomeFor(3, 7, 2)).to.equal(42)
		end)

		it("returns zero for non-positive elapsed time", function()
			expect(EconomyMath.incomeFor(10, 0, 1)).to.equal(0)
			expect(EconomyMath.incomeFor(10, -5, 1)).to.equal(0)
		end)

		it("never returns negative income", function()
			expect(EconomyMath.incomeFor(1, 1, 0.5)).to.equal(0)
		end)
	end)

	describe("EconomyMath.rebirthRequirement", function()
		it("grows geometrically with rebirth count", function()
			expect(EconomyMath.rebirthRequirement(0, 10000, 4)).to.equal(10000)
			expect(EconomyMath.rebirthRequirement(1, 10000, 4)).to.equal(40000)
			expect(EconomyMath.rebirthRequirement(3, 10000, 4)).to.equal(640000)
		end)
	end)

	describe("EconomyMath.sellRefund", function()
		it("refunds the configured fraction, minimum 1", function()
			expect(EconomyMath.sellRefund(100, 0.6)).to.equal(60)
			expect(EconomyMath.sellRefund(1, 0.6)).to.equal(1)
		end)
	end)

	describe("EconomyMath.baseSlots", function()
		it("adds slots per rebirth", function()
			expect(EconomyMath.baseSlots(0, 8)).to.equal(8)
			expect(EconomyMath.baseSlots(2, 8)).to.equal(24)
		end)
	end)
end
