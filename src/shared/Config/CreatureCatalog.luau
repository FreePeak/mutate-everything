--!strict
-- Base creature species purchasable from the conveyor. Hybrids are generated,
-- never listed here. Costs scale roughly with income so payback stays ~60-90s.

local catalog = {
	species = {},
	byId = {},
}

local function addSpecies(id: string, name: string, rarity: string, income: number)
	local entry = {
		id = id,
		name = name,
		rarity = rarity,
		baseIncome = income,
		cost = math.floor(income * 75 + 0.5),
		bodyColor = Color3.fromRGB(
			math.floor(income * 37 % 205) + 50,
			math.floor(income * 91 % 205) + 50,
			math.floor(income * 53 % 205) + 50
		),
		accentColor = Color3.fromHSV((income * 0.137) % 1, 0.8, 1),
		scale = 1 + (math.floor(income * 7 % 40) / 100),
		shape = ({ "Blob", "Tall", "Wide" })[(math.floor(income * 3) % 3) + 1],
	}
	table.insert(catalog.species, entry)
	catalog.byId[id] = entry
end

addSpecies("slimelet", "Slimelet", "Common", 1)
addSpecies("grubbo", "Grubbo", "Common", 2)
addSpecies("wobbler", "Wobbler", "Uncommon", 5)
addSpecies("gnarlpup", "Gnarlpup", "Uncommon", 9)
addSpecies("mucush", "Mucush", "Rare", 20)
addSpecies("thornbeak", "Thornbeak", "Rare", 35)
addSpecies("voltadon", "Voltadon", "Epic", 80)
addSpecies("gloomaw", "Gloomaw", "Epic", 140)
addSpecies("pyrelisk", "Pyrelisk", "Legendary", 320)
addSpecies("quasarox", "Quasarox", "Mythic", 900)
addSpecies("omnishambles", "Omnishambles", "MutantGod", 2500)

return catalog
