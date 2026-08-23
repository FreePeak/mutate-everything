--!strict
-- Save-data normalization and migration. Pure logic so it is unit-testable:
-- takes whatever came out of the DataStore (possibly nil, partial, hostile)
-- and returns a safe v1 record. Bump SCHEMA_VERSION and add a step per bump.

local SchemaMigration = {}

SchemaMigration.SCHEMA_VERSION = 1

export type MigratedSave = {
	version: number,
	cash: number,
	rebirths: number,
	totalEarned: number,
	creatures: { any },
}

local function toFiniteNumber(value: any, fallback: number): number
	local n = tonumber(value)
	if n == nil or n ~= n or n == math.huge or n == -math.huge then
		return fallback
	end
	return math.max(0, n)
end

--- Normalize an arbitrary saved payload into a MigratedSave.
function SchemaMigration.migrate(saved: any): MigratedSave
	if type(saved) ~= "table" then
		return {
			version = SchemaMigration.SCHEMA_VERSION,
			cash = 0,
			rebirths = 0,
			totalEarned = 0,
			creatures = {},
		}
	end

	local migrated: MigratedSave = {
		version = SchemaMigration.SCHEMA_VERSION,
		cash = toFiniteNumber(saved.cash, 0),
		rebirths = math.floor(toFiniteNumber(saved.rebirths, 0)),
		totalEarned = toFiniteNumber(saved.totalEarned, 0),
		creatures = {},
	}

	if type(saved.creatures) == "table" then
		for _, creature in saved.creatures do
			if type(creature) == "table"
				and type(creature.uid) == "string"
				and toFiniteNumber(creature.income, 0) > 0
			then
				table.insert(migrated.creatures, {
					uid = creature.uid,
					speciesId = type(creature.speciesId) == "string" and creature.speciesId or "hybrid",
					name = type(creature.name) == "string" and creature.name or "Nameless Mutant",
					income = toFiniteNumber(creature.income, 1),
					mutation = creature.mutation or "None",
					rarity = creature.rarity or "Common",
					generation = math.floor(toFiniteNumber(creature.generation, 1)),
					colorA = typeof(creature.colorA) == "Color3" and creature.colorA or Color3.fromRGB(120, 120, 120),
					colorB = typeof(creature.colorB) == "Color3" and creature.colorB or Color3.fromRGB(80, 80, 80),
					scale = toFiniteNumber(creature.scale, 1),
					parents = {},
				})
			end
		end
	end

	return migrated
end

return SchemaMigration
