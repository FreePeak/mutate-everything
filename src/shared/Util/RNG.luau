--!strict
-- Deterministic RNG wrapper so all gameplay randomness is seedable and
-- unit-testable. Uses Lua's math.random under the hood; tests inject seeds.

local RNG = {}
RNG.__index = RNG

export type RNGType = typeof(setmetatable({} :: { _seed: number }, RNG))

function RNG.new(seed: number?)
	local self = setmetatable({}, RNG)
	self._rng = Random.new(seed)
	return self
end

function RNG:NextNumber(min: number?, max: number?): number
	return self._rng:NextNumber(min or 0, max or 1)
end

function RNG:NextInteger(min: number, max: number): number
	return self._rng:NextInteger(min, max)
end

--- Weighted pick from a table mapping keys to numeric weights.
function RNG:WeightedPick(weights: { [string]: number }): string
	local total = 0
	for _, weight in weights do
		total += weight
	end
	local roll = self._rng:NextNumber(0, total)
	local cumulative = 0
	for key, weight in weights do
		cumulative += weight
		if roll <= cumulative then
			return key
		end
	end
	-- Float edge: return the last key.
	local lastKey = ""
	for key in weights do
		lastKey = key
	end
	return lastKey
end

function RNG:Chance(probability: number): boolean
	return self._rng:NextNumber(0, 1) < probability
end

return RNG
