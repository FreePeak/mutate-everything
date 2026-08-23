--!strict
-- Pure economy helpers: income ticks, rebirth thresholds, sell refunds.
-- Kept free of Roblox APIs for headless testing.

local EconomyMath = {}

--- Income earned over `elapsed` seconds given per-second income and multiplier.
function EconomyMath.incomeFor(incomePerSecond: number, elapsed: number, multiplier: number): number
	if elapsed <= 0 then
		return 0
	end
	return math.floor(incomePerSecond * elapsed * multiplier + 1e-6)
end

--- Cash required for rebirth N (N starts at 0 for the first rebirth).
function EconomyMath.rebirthRequirement(rebirths: number, base: number, growth: number): number
	return math.floor(base * (growth ^ rebirths) + 0.5)
end

--- Refund received when selling a creature that cost `cost`.
function EconomyMath.sellRefund(cost: number, refundFraction: number): number
	return math.max(1, math.floor(cost * refundFraction + 0.5))
end

--- Total slots available at a given rebirth count.
function EconomyMath.baseSlots(rebirths: number, slotsPerRebirth: number): number
	return slotsPerRebirth * (rebirths + 1)
end

return EconomyMath
