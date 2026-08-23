--!strict
-- Base locking and stealing. All validation is server-side: lock windows,
-- distance checks, one carried creature per thief, and secure-at-home-pad.

local Players = game:GetService("Players")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local GameConfig = require(Shared.Config.GameConfig)

local TheftService = {}

local baseService: any
local creatureService: any
local dataService: any
local announce: any -- function(player, message, kind)

-- uid -> { thiefUserId, ownerId, grabbedAt }
local activeThefts: { [string]: any } = {}

function TheftService.Init(deps)
	baseService = deps.BaseService
	creatureService = deps.CreatureService
	dataService = deps.DataService
	announce = deps.Announce
end

function TheftService.Start() end

--- Player requests to lock their own base. Returns (ok, reason).
function TheftService.TryLock(player: Player): (boolean, string)
	local state = dataService.GetState(player.UserId)
	if not state then
		return false, "not_loaded"
	end

	local now = os.clock()
	if now < state.unlockCooldownUntil then
		return false, "on_cooldown"
	end

	state.lastLockTime = now
	state.lockExpireAt = now + GameConfig.LockDurationSeconds
	state.unlockCooldownUntil = 0
	return true, "ok"
end

--- Called by BaseService when a lock expires.
function TheftService.OnLockExpired(userId: number)
	local state = dataService.GetState(userId)
	if not state then
		return
	end
	state.lockExpireAt = 0
	state.unlockCooldownUntil = os.clock() + GameConfig.LockCooldownSeconds
end

--- Is the target's base currently open for raiding?
function TheftService.IsBaseOpen(ownerId: number): boolean
	local state = dataService.GetState(ownerId)
	if not state then
		return true
	end
	local now = os.clock()
	if state.lockExpireAt > now then
		return false
	end
	return true
end

function TheftService.IsCarrying(userId: number): boolean
	for _, theft in activeThefts do
		if theft.thiefUserId == userId then
			return true
		end
	end
	return false
end

--- Attempt to steal creature `uid` owned by `ownerId`.
function TheftService.TrySteal(thief: Player, ownerId: number, uid: string): (boolean, string)
	if thief.UserId == ownerId then
		return false, "own_creature"
	end

	local live = creatureService.GetLive(uid)
	if not live or live.ownerId ~= ownerId then
		return false, "not_available"
	end

	if TheftService.IsCarrying(thief.UserId) then
		return false, "already_carrying"
	end

	if not TheftService.IsBaseOpen(ownerId) then
		return false, "base_locked"
	end

	local ownerPlot = baseService.GetPlayerPlot(ownerId)
	local thiefCharacter = thief.Character
	if not ownerPlot or not thiefCharacter then
		return false, "no_character"
	end

	local thiefRoot = thiefCharacter:FindFirstChild("HumanoidRootPart")
	if not thiefRoot then
		return false, "no_character"
	end

	-- Must be physically near the creature's owner plot to grab.
	local distance = (thiefRoot.Position - ownerPlot.center.Position).Magnitude
	if distance > ownerPlot.radius * 1.5 then
		return false, "too_far"
	end

	activeThefts[uid] = {
		thiefUserId = thief.UserId,
		ownerId = ownerId,
		grabbedAt = os.clock(),
	}

	task.spawn(function()
		-- If nobody secures the steal within 60s it returns home automatically.
		task.wait(60)
		if activeThefts[uid] then
			TheftService.AbortTheft(uid, "timeout")
		end
	end)

	return true, "ok"
end

--- Thief reached their own pad: transfer ownership.
function TheftService.TrySecure(thief: Player): (boolean, string)
	for uid, theft in activeThefts do
		if theft.thiefUserId == thief.UserId then
			if not baseService.IsOnOwnPad(thief) then
				return false, "not_on_pad"
			end

			activeThefts[uid] = nil
			local state = dataService.GetState(theft.ownerId)
			if state then
				for index, creature in state.creatures do
					if creature.uid == uid then
						table.remove(state.creatures, index)
						break
					end
				end
			end

			local thiefState = dataService.GetState(thief.UserId)
			local live = creatureService.GetLive(uid)
			if thiefState and live and #thiefState.creatures < thiefState.baseSlots then
				live.ownerId = thief.UserId
				table.insert(thiefState.creatures, live.creature)
				if announce then
					announce(
						thief,
						("%s stole %s ($%s/s)!"):format(thief.Name, live.creature.name, tostring(live.creature.income)),
						"theft"
					)
				end
			else
				-- No room: creature is lost to the void. Harsh but funny.
				creatureService.UnregisterLive(uid)
				creatureService.CreatureRemoved:Fire(uid)
			end
			return true, "ok"
		end
	end
	return false, "not_carrying"
end

--- Owner fought back / timeout: creature returns home.
function TheftService.AbortTheft(uid: string, reason: string)
	local theft = activeThefts[uid]
	if not theft then
		return
	end
	activeThefts[uid] = nil
	if announce and reason == "defended" then
		local owner = Players:GetPlayerByUserId(theft.ownerId)
		if owner then
			announce(owner, ("You defended your %s!"):format(uid), "defense")
		end
	end
end

function TheftService.GetActiveThefts()
	return activeThefts
end

return TheftService
