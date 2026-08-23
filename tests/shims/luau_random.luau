--!strict
-- Headless shim for Roblox's Random class (lune does not provide it).
-- Implements the subset used by src/shared/Util/RNG.luau: NextNumber,
-- NextInteger. Deterministic per seed (xoshiro-inspired LCG mix).

local SHIFT = 2 ^ 32

local LuauRandom = {}
LuauRandom.__index = LuauRandom

function LuauRandom.new(seed: number?)
	local self = setmetatable({}, LuauRandom)
	-- Splitmix-style seeding into 64-bit state kept as two 32-bit halves.
	local s = math.floor((seed or os.clock() * 1e6) % 4294967296)
	if s == 0 then
		s = 0x9E3779B9
	end
	self._state = s
	return self
end

function LuauRandom:_nextU32(): number
	-- Numerical Recipes LCG: portable across Luau integer handling.
	self._state = (self._state * 1664525 + 1013904223) % 4294967296
	return self._state
end

function LuauRandom:NextNumber(min: number?, max: number?): number
	local lo = min or 0
	local hi = max or 1
	if hi < lo then
		lo, hi = hi, lo
	end
	return lo + (hi - lo) * (self:_nextU32() / 4294967296)
end

function LuauRandom:NextInteger(min: number, max: number): number
	if max < min then
		min, max = max, min
	end
	local span = math.floor(max - min + 1)
	return math.min(max, min + math.floor(self:_nextU32() / 4294967296 * span))
end

function LuauRandom:Clone()
	return LuauRandom.new(self._state)
end

return LuauRandom
