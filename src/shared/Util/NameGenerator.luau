--!strict
-- Procedural hybrid naming: blends two parent names into one, then prefixes a
-- mutation epithet. Pure string logic; unit-testable.

local NameGenerator = {}

local PREFIXES = { "Mega", "Ultra", "Hyper", "Turbo", "Proto", "Neo", "Grand", "Micro" }
local SUFFIXES = { "Prime", "X", "Jr", "Max", "Deluxe", "9000", "Omega", "Zero" }

local MUTATION_EPITHETS = {
	Neon = "Neon",
	Cosmic = "Cosmic",
	Void = "Void",
}

local function firstSyllables(name: string, count: number): string
	local result = {}
	for index = 1, math.min(count, #name) do
		local char = name:sub(index, index)
		-- Stop mid-cluster unless we have nothing yet.
		if index > 2 and (char == "a" or char == "e" or char == "i" or char == "o" or char == "u") then
			table.insert(result, char)
			break
		end
		table.insert(result, char)
	end
	return table.concat(result)
end

local function lastSyllables(name: string, count: number): string
	local result = {}
	for index = math.max(1, #name - count + 1), #name do
		table.insert(result, name:sub(index, index))
	end
	return table.concat(result)
end

--- Blend "Slimelet" + "Gloomaw" into something like "Slimmaw".
function NameGenerator.blend(nameA: string, nameB: string): string
	local head = firstSyllables(nameA:gsub("%s", ""), 3)
	local tail = lastSyllables(nameB:gsub("%s", ""), 3)
	local blended = head .. tail:lower()
	blended = blended:sub(1, 1):upper() .. blended:sub(2)
	return blended
end

--- Attach mutation epithet, or occasionally decorate plain hybrids.
function NameGenerator.withMutation(baseName: string, mutation: string): string
	local epithet = MUTATION_EPITHETS[mutation]
	if epithet then
		return epithet .. " " .. baseName
	end
	return baseName
end

--- Optional flair used when announcing high-value fusions.
function NameGenerator.decorated(baseName: string): string
	local prefix = PREFIXES[math.random(1, #PREFIXES)]
	local suffix = SUFFIXES[math.random(1, #SUFFIXES)]
	return ("%s %s %s"):format(prefix, baseName, suffix)
end

return NameGenerator
