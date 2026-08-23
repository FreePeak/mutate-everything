--!strict
-- Builds the world procedurally from parts (zero external assets):
-- a central conveyor runway plus one plot per player with slot pads.
-- Also owns creature model construction and the "on own pad" check.

local Players = game:GetService("Players")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local GameConfig = require(Shared.Config.GameConfig)
local RarityConfig = require(Shared.Config.RarityConfig)

local BaseService = {}

local world: Folder
local plots: { [number]: any } = {}
local plotAnchors: { [any]: number } = {} -- spawn pad -> userId for Touched checks
local conveyorPedestals: { [number]: Part } = {}
local pedestalDisplays: { [Part]: any } = {}

local PLOT_RADIUS = 40
local SLOT_SPACING = 10

local function makePart(props): Part
	local part = Instance.new("Part")
	part.Anchored = true
	part.Size = props.size or Vector3.new(4, 1, 4)
	part.Position = props.position
	part.Color = props.color or Color3.fromRGB(120, 120, 120)
	part.Material = props.material or Enum.Material.SmoothPlastic
	part.Name = props.name or "Part"
	if props.shape then
		part.Shape = props.shape
	end
	part.Parent = props.parent or world
	return part
end

local function buildRunway()
	-- Central conveyor strip where catalog creatures parade.
	local runway = Instance.new("Model")
	runway.Name = "Runway"
	runway.Parent = world

	for index = -6, 6 do
		makePart({
			position = Vector3.new(index * 8, 0.5, 0),
			size = Vector3.new(7, 1, 12),
			color = index % 2 == 0 and Color3.fromRGB(60, 60, 70) or Color3.fromRGB(75, 75, 88),
			material = Enum.Material.DiamondPlate,
			parent = runway,
			name = "ConveyorSegment",
		})
	end

	local sign = Instance.new("SurfaceGui")
	sign.Face = Enum.NormalId.Top
	sign.CanvasSize = Vector2.new(200, 60)
	sign.Parent = makePart({
		position = Vector3.new(0, 3, -14),
		size = Vector3.new(20, 4, 1),
		color = Color3.fromRGB(30, 30, 35),
		parent = runway,
		name = "Sign",
	})

	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.TextScaled = true
	label.TextColor3 = Color3.fromRGB(255, 220, 80)
	label.Text = "MUTATE CONVEYOR"
	label.Parent = sign

	-- Purchase pedestals along both edges of the runway.
	for index = -3, 3 do
		local pedestal = makePart({
			position = Vector3.new(index * 24, 1.5, -10),
			size = Vector3.new(5, 2, 5),
			color = Color3.fromRGB(50, 50, 60),
			material = Enum.Material.Metal,
			name = "Pedestal" .. tostring(index),
			parent = runway,
		})

		local prompt = Instance.new("ProximityPrompt")
		prompt.HoldDuration = 0.3
		prompt.MaxActivationDistance = 12
		prompt.ObjectText = "Conveyor"
		prompt.ActionText = "Inspect"
		prompt.Parent = pedestal
		prompt.Triggered:Connect(function(player)
			local entry = pedestalDisplays[pedestal]
			if entry then
				BaseService.ConveyorPurchaseRequested:Fire(player, entry.id)
			end
		end)

		conveyorPedestals[index] = pedestal
		pedestalDisplays[pedestal] = nil
	end
end

local conveyorCursor = -3

--- Show a catalog species on the next pedestal (round-robin).
function BaseService.SetConveyorDisplay(entry)
	local pedestal = conveyorPedestals[conveyorCursor]
	if not pedestal then
		return
	end
	conveyorCursor = conveyorCursor >= 3 and -3 or conveyorCursor + 1

	-- Clear previous display model if present.
	if pedestalDisplays[pedestal] and pedestalDisplays[pedestal].model then
		pedestalDisplays[pedestal].model:Destroy()
	end

	local rarityColor = RarityConfig.colors[entry.rarity] or Color3.new(1, 1, 1)

	local specimen = Instance.new("Part")
	specimen.Anchored = true
	specimen.Shape = Enum.PartType.Ball
	specimen.Size = Vector3.new(3, 3, 3)
	specimen.Color = entry.bodyColor
	specimen.Material = Enum.Material.SmoothPlastic
	specimen.Position = pedestal.Position + Vector3.new(0, 4, 0)
	specimen.Parent = pedestal.Parent

	local billboard = Instance.new("BillboardGui")
	billboard.Size = UDim2.new(0, 220, 0, 64)
	billboard.StudsOffset = Vector3.new(0, 3, 0)
	billboard.AlwaysOnTop = false
	billboard.Parent = specimen

	local nameLabel = Instance.new("TextLabel")
	nameLabel.Size = UDim2.fromScale(1, 0.6)
	nameLabel.BackgroundTransparency = 1
	nameLabel.TextScaled = true
	nameLabel.Font = Enum.Font.GothamBold
	nameLabel.TextColor3 = rarityColor
	nameLabel.Text = ("%s | $%d"):format(entry.name, entry.cost)
	nameLabel.Parent = billboard

	local incomeLabel = Instance.new("TextLabel")
	incomeLabel.Size = UDim2.fromScale(1, 0.35)
	incomeLabel.Position = UDim2.fromScale(0, 0.62)
	incomeLabel.BackgroundTransparency = 1
	incomeLabel.TextScaled = true
	incomeLabel.Font = Enum.Font.Gotham
	incomeLabel.TextColor3 = Color3.fromRGB(200, 200, 210)
	incomeLabel.Text = ("$%d/s"):format(entry.baseIncome)
	incomeLabel.Parent = billboard

	local prompt = pedestal:FindFirstChildOfClass("ProximityPrompt")
	if prompt then
		prompt.ObjectText = entry.name
		prompt.ActionText = ("Buy $%d"):format(entry.cost)
	end

	pedestalDisplays[pedestal] = { id = entry.id, model = specimen }
end

local function buildPlot(userId: number, origin: Vector3)
	local plot = {
		center = makePart({
			position = origin,
			size = Vector3.new(PLOT_RADIUS * 2, 1, PLOT_RADIUS * 2),
			color = Color3.fromRGB(90, 130, 95),
			material = Enum.Material.Grass,
			name = "PlotFloor",
		}),
		radius = PLOT_RADIUS,
		slotPads = {},
		models = {}, -- uid -> Model
	}

	plot.center.Touched:Connect(function(hit)
		local character = hit:FindFirstAncestorOfClass("Model")
		local player = character and Players:GetPlayerFromCharacter(character)
		if player then
			BaseService.PlayerTouchedPad:Fire(player)
		end
	end)

	plots[userId] = plot
	return plot
end

function BaseService.Init()
	world = Instance.new("Folder")
	world.Name = "World"
	world.Parent = workspace

	BaseService.PlayerTouchedPad = Instance.new("BindableEvent")
	BaseService.ConveyorPurchaseRequested = Instance.new("BindableEvent")
	BaseService.DefendRequested = Instance.new("BindableEvent")
	BaseService.StealRequested = Instance.new("BindableEvent")

	buildRunway()
end

function BaseService.Start()
	-- Carried creatures hover above the thief's head; updated on the server so
	-- all clients see the same chase state.
	local RunService = game:GetService("RunService")
	RunService.Heartbeat:Connect(function()
		for uid, carried in carriedCreatures do
			local thief = Players:GetPlayerByUserId(carried.thiefUserId)
			local root = thief and thief.Character and thief.Character:FindFirstChild("HumanoidRootPart")
			if root then
				carried.model:PivotTo(CFrame.new(root.Position + Vector3.new(0, 5, 0)))
			end
		end
	end)

	-- Plot assignment is driven externally (bootstrap wires PlayerInitialized
	-- to AssignPlot); this loop only refreshes owner beacons for late joiners.
	task.spawn(function()
		while true do
			task.wait(5)
			for _, player in Players:GetPlayers() do
				local plot = plots[player.UserId]
				if plot then
					local beacon = plot.center.Parent and plot.center.Parent:FindFirstChild("OwnerBeacon")
					if beacon then
						beacon.Color = RarityConfig.colors.Legendary
					end
				end
			end
		end
	end)
end

--- Assign a plot near an angle ring position.
function BaseService.AssignPlot(player: Player, index: number)
	if plots[player.UserId] then
		return plots[player.UserId]
	end
	local angle = math.rad(index * 60 - 90)
	local origin = Vector3.new(math.cos(angle) * 140, 0.5, math.sin(angle) * 140 - 160)
	local plot = buildPlot(player.UserId, origin)

	local beacon = makePart({
		position = origin + Vector3.new(0, 6, -PLOT_RADIUS + 4),
		size = Vector3.new(6, 12, 1),
		color = RarityConfig.colors.Legendary,
		material = Enum.Material.Neon,
		name = "OwnerBeacon",
	})

	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.new(0, 400, 0, 100)
	gui.StudsOffset = Vector3.new(0, 8, 0)
	gui.AlwaysOnTop = true
	gui.Parent = beacon
	local nameLabel = Instance.new("TextLabel")
	nameLabel.Size = UDim2.fromScale(1, 1)
	nameLabel.BackgroundTransparency = 1
	nameLabel.TextScaled = true
	nameLabel.Text = player.DisplayName .. "'s Lab"
	nameLabel.TextColor3 = Color3.new(1, 1, 1)
	nameLabel.Parent = gui

	return plot
end

function BaseService.GetPlayerPlot(userId: number)
	return plots[userId]
end

function BaseService.ReleasePlot(userId: number)
	local plot = plots[userId]
	if plot then
		plot.center.Parent:Destroy()
		plots[userId] = nil
	end
end

--- Is the player standing on their own secure pad?
function BaseService.IsOnOwnPad(player: Player): boolean
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	local plot = plots[player.UserId]
	if not root or not plot then
		return false
	end
	return (root.Position - plot.center.Position).Magnitude < PLOT_RADIUS
end

--- Spawn (or refresh) the physical model of a creature on its owner's plot.
function BaseService.SpawnCreatureModel(player: Player, creature)
	local plot = plots[player.UserId]
	if not plot then
		return
	end

	local oldModel = plot.models[creature.uid]
	if oldModel then
		oldModel:Destroy()
	end

	local model = Instance.new("Model")
	model.Name = creature.uid

	local rarityColor = RarityConfig.colors[creature.rarity] or Color3.new(1, 1, 1)
	local bodySize = Vector3.new(3, 3, 3) * (creature.scale or 1)

	local body = Instance.new("Part")
	body.Anchored = true
	body.Shape = Enum.PartType.Ball
	body.Size = bodySize
	body.Color = creature.colorA
	body.Material = creature.mutation == "Neon" and Enum.Material.Neon or Enum.Material.SmoothPlastic
	body.Parent = model

	-- Accent head marks mutation tier visually.
	local head = Instance.new("Part")
	head.Anchored = true
	head.Shape = Enum.PartType.Ball
	head.Size = bodySize * 0.5
	local headColor = creature.colorB
	if creature.mutation == "Cosmic" then
		headColor = Color3.fromRGB(90, 60, 180)
	elseif creature.mutation == "Void" then
		headColor = Color3.fromRGB(10, 10, 15)
	end
	head.Color = headColor
	head.Material = Enum.Material.Neon
	head.Parent = model

	-- Rarity ring underfoot.
	local ring = Instance.new("Part")
	ring.Anchored = true
	ring.Shape = Enum.PartType.Cylinder
	ring.Size = Vector3.new(0.3, bodySize.X * 1.4, bodySize.Z * 1.4)
	ring.Orientation = Vector3.new(0, 0, 90)
	ring.Color = rarityColor
	ring.Material = Enum.Material.Neon
	ring.Transparency = 0.3
	ring.Parent = model

	local billboard = Instance.new("BillboardGui")
	billboard.Size = UDim2.new(0, 240, 0, 70)
	billboard.StudsOffset = Vector3.new(0, 3.5, 0)
	billboard.Parent = body
	local nameLabel = Instance.new("TextLabel")
	nameLabel.Size = UDim2.fromScale(1, 0.6)
	nameLabel.BackgroundTransparency = 1
	nameLabel.TextScaled = true
	nameLabel.TextColor3 = rarityColor
	nameLabel.Text = ("%s | $%s/s"):format(creature.name, tostring(creature.income))
	nameLabel.Parent = billboard

	-- Steal interaction: visible to everyone; the server rejects attempts on
	-- your own creatures and while the owner's base is locked.
	local stealPrompt = Instance.new("ProximityPrompt")
	stealPrompt.Name = "StealPrompt"
	stealPrompt.HoldDuration = 0.6
	stealPrompt.MaxActivationDistance = 10
	stealPrompt.ObjectText = creature.name
	stealPrompt.ActionText = "Steal"
	stealPrompt.Parent = body
	stealPrompt.Triggered:Connect(function(player)
		BaseService.StealRequested:Fire(player, uid)
	end)

	-- Arrange in a grid over the plot.
	local slotsUsed = 0
	for _, existing in plot.models do
		slotsUsed += 1
	end
	local column = slotsUsed % 6
	local row = math.floor(slotsUsed / 6) % 6
	local basePosition = plot.center.Position
	body.Position = basePosition + Vector3.new((column - 2.5) * SLOT_SPACING, bodySize.Y / 2, (row - 2) * SLOT_SPACING + PLOT_RADIUS / 3)
	head.Position = body.Position + Vector3.new(0, bodySize.Y * 0.55, 0)
	ring.CFrame = CFrame.new(body.Position - Vector3.new(0, bodySize.Y / 2 - 0.2, 0)) * CFrame.Angles(0, 0, math.rad(90))

	model.Parent = world
	plot.models[creature.uid] = model
end

function BaseService.RemoveCreatureModel(uid: string)
	for _, plot in plots do
		local model = plot.models[uid]
		if model then
			model:Destroy()
			plot.models[uid] = nil
		end
	end
end

-- ------------------------------------------------------- carried creatures

-- uid -> { thiefUserId, model }
local carriedCreatures: { [string]: any } = {}

--- Lift a creature off its plot and start following the thief.
function BaseService.AttachCarried(uid: string, thief: Player)
	for _, plot in plots do
		local model = plot.models[uid]
		if model then
			plot.models[uid] = nil -- detach from grid bookkeeping during carry
			carriedCreatures[uid] = { thiefUserId = thief.UserId, model = model }

			local prompt = Instance.new("ProximityPrompt")
			prompt.Name = "DefendPrompt"
			prompt.HoldDuration = 0.2
			prompt.MaxActivationDistance = 15
			prompt.ObjectText = "Thief!"
			prompt.ActionText = ("Stop %s"):format(thief.DisplayName)
			prompt.Parent = model.PrimaryPart or model:FindFirstChildWhichIsA("BasePart")
			prompt.Triggered:Connect(function(player)
				BaseService.DefendRequested:Fire(player, thief.UserId)
			end)

			return true
		end
	end
	return false
end

--- Stop carrying. If `restoreOwnerId` is given and that player still has a
--- plot, the model returns to their grid slot; otherwise it is destroyed.
function BaseService.DetachCarried(uid: string, ownerId: number?)
	local carried = carriedCreatures[uid]
	if not carried then
		return false
	end
	carriedCreatures[uid] = nil

	local model = carried.model
	local oldPrompt = model:FindFirstChild("DefendPrompt", true)
	if oldPrompt then
		oldPrompt:Destroy()
	end
	if not model.Parent then
		return false
	end

	local ownerPlot = ownerId and plots[ownerId] or nil
	if ownerPlot then
		ownerPlot.models[uid] = model
		model:PivotTo(CFrame.new(ownerPlot.center.Position + Vector3.new(0, 4, 0)))
		BaseService.RelayoutPlot(ownerId)
	else
		model:Destroy()
	end
	return true
end

function BaseService.IsCarried(uid: string): boolean
	return carriedCreatures[uid] ~= nil
end

--- Re-grid all models on a plot (used after models leave/return).
function BaseService.RelayoutPlot(userId: number)
	local plot = plots[userId]
	if not plot then
		return
	end
	local index = 0
	for uid, model in plot.models do
		index += 1
		local column = (index - 1) % 6
		local row = math.floor((index - 1) / 6) % 6
		local target = plot.center.Position
			+ Vector3.new((column - 2.5) * SLOT_SPACING, 2, (row - 2) * SLOT_SPACING + PLOT_RADIUS / 3)
		model:PivotTo(CFrame.new(target))
	end
end

return BaseService
