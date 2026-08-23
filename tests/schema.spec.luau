--!strict
-- Schema migration specs.

return function(describe, it, expect, req)
	local SchemaMigration = req("Util/SchemaMigration")

	describe("SchemaMigration.migrate", function()
		it("returns a clean default for nil or hostile payloads", function()
			for _, payload in { nil, 42, "oops", {}, { cash = "banana" } } do
				local result = SchemaMigration.migrate(payload)
				expect(type(result.creatures)).to.equal("table")
				expect(result.cash >= 0).to.equal(true)
				expect(result.rebirths >= 0).to.equal(true)
			end
		end)

		it("preserves valid fields and clamps negatives", function()
			local result = SchemaMigration.migrate({
				cash = 500,
				rebirths = 2,
				totalEarned = 10000,
				creatures = {},
			})
			expect(result.cash).to.equal(500)
			expect(result.rebirths).to.equal(2)
			expect(result.totalEarned).to.equal(10000)
		end)

		it("drops malformed creatures and keeps well-formed ones", function()
			local result = SchemaMigration.migrate({
				cash = 10,
				creatures = {
					{ uid = "ok1", income = 5 },
					"not a table",
					{ no_uid = true },
					{ uid = "zero_income", income = 0 },
					{ uid = "ok2", income = -3 },
				},
			})
			expect(#result.creatures).to.equal(1)
			expect(result.creatures[1].uid).to.equal("ok1")
		end)

		it("fills creature defaults without crashing on missing colors", function()
			local result = SchemaMigration.migrate({
				cash = 10,
				creatures = { { uid = "a", income = 7, generation = "not-a-number" } },
			})
			local creature = result.creatures[1]
			expect(creature.name).to.equal("Nameless Mutant")
			expect(creature.rarity).to.equal("Common")
			-- Non-numeric generation falls back to the default of 1.
			expect(creature.generation).to.equal(1)
			expect(creature.income).to.equal(7)
		end)
	end)
end
