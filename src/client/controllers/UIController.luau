--!strict
-- Builds the entire UI in code (zero external assets): HUD, shop panel,
-- fusion panel, roster list, announcements ticker. Subscribes to Network.

local Players = game:GetService("Players")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local RarityConfig = require(Shared.Config.RarityConfig)

local UI = {}

local player = Players.LocalPlayer

local refs = {} :: { [string]: any }
local state: any = nil
local fuseSelection: { string } = {}

-- ------------------------------------------------------------- utilities

local function make(className: string, props, parent: Instance?): Instance
	local inst = Instance.new(className)
	for key, value in props do
		(inst :: any)[key] = value
	end
	inst.Parent = parent
	return inst
end

local function corner(radius: number, parent: Instance)
	make("UICorner", { CornerRadius = UDim.new(0, radius) }, parent)
end

local function button(text: string, size: UDim2, position: UDim2, color: Color3, parent: Instance)
	local b = make("TextButton", {
		Size = size,
		Position = position,
		BackgroundColor3 = color,
		TextColor3 = Color3.new(1, 1, 1),
		TextScaled = true,
		Text = text,
		Font = Enum.Font.GothamBold,
		AutoButtonColor = true,
	}, parent)
	corner(8, b)
	return b
end

-- ---------------------------------------------------------------- layout

function UI.Init()
	local gui = make("ScreenGui", {
		Name = "MutateUI",
		ResetOnSpawn = false,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
	}, player:WaitForChild("PlayerGui"))

	-- Cash HUD (top left).
	local hud = make("Frame", {
		Size = UDim2.fromOffset(280, 90),
		Position = UDim2.fromOffset(12, 12),
		BackgroundColor3 = Color3.fromRGB(25, 25, 32),
		BackgroundTransparency = 0.15,
	}, gui)
	corner(10, hud)

	make("TextLabel", {
		Name = "Cash",
		Size = UDim2.new(1, -16, 0.55, 0),
		Position = UDim2.fromOffset(8, 4),
		BackgroundTransparency = 1,
		TextColor3 = Color3.fromRGB(120, 255, 140),
		TextScaled = true,
		Font = Enum.Font.GothamBold,
		Text = "$0",
		TextXAlignment = Enum.TextXAlignment.Left,
	}, hud)

	make("TextLabel", {
		Name = "Income",
		Size = UDim2.new(1, -16, 0.35, 0),
		Position = UDim2.new(0, 8, 0.6, 0),
		BackgroundTransparency = 1,
		TextColor3 = Color3.fromRGB(200, 200, 220),
		TextScaled = true,
		Font = Enum.Font.Gotham,
		Text = "$0/s",
		TextXAlignment = Enum.TextXAlignment.Left,
	}, hud)

	-- Announcement ticker (top center).
	local ticker = make("Frame", {
		Size = UDim2.new(0, 480, 0, 34),
		Position = UDim2.new(0.5, -240, 0, 12),
		BackgroundColor3 = Color3.fromRGB(20, 20, 26),
		BackgroundTransparency = 0.25,
	}, gui)
	corner(8, ticker)
	make("TextLabel", {
		Name = "TickerText",
		Size = UDim2.new(1, -12, 1, 0),
		Position = UDim2.fromOffset(6, 0),
		BackgroundTransparency = 1,
		TextColor3 = Color3.fromRGB(255, 230, 130),
		TextScaled = true,
		Font = Enum.Font.GothamBold,
		Text = "Welcome to MUTATE! Buy, fuse, steal.",
	}, ticker)

	-- Lock button + rebirth (bottom center).
	local lockBtn = button("LOCK BASE (45s)", UDim2.fromOffset(190, 44), UDim2.new(0.5, -260, 1, -64), Color3.fromRGB(60, 160, 80), gui)
	lockBtn.Name = "LockButton"
	lockBtn.MouseButton1Click:Connect(function()
		task.spawn(function()
			require(script.Parent.NetworkController).RequestLock()
		end)
	end)

	local rebirthBtn = button("REBIRTH", UDim2.fromOffset(150, 44), UDim2.new(0.5, -50, 1, -64), Color3.fromRGB(170, 60, 220), gui)
	rebirthBtn.Name = "RebirthButton"
	rebirthBtn.MouseButton1Click:Connect(function()
		task.spawn(function()
			require(script.Parent.NetworkController).RequestRebirth()
		end)
	end)

	-- Shop panel (left side, toggleable).
	local shop = make("Frame", {
		Name = "Shop",
		Size = UDim2.fromOffset(260, 340),
		Position = UDim2.new(0, 12, 0.5, -170),
		BackgroundColor3 = Color3.fromRGB(25, 25, 32),
		BackgroundTransparency = 0.1,
	}, gui)
	corner(10, shop)
	make("TextLabel", {
		Size = UDim2.new(1, 0, 0, 30),
		BackgroundColorTransparency = 1,
		BackgroundTransparency = 1,
		TextColor3 = Color3.new(1, 1, 1),
		TextScaled = true,
		Font = Enum.Font.GothamBold,
		Text = "CONVEYOR SHOP",
	}, shop)

	local shopList = make("ScrollingFrame", {
		Name = "ShopList",
		Size = UDim2.new(1, -16, 1, -44),
		Position = UDim2.fromOffset(8, 36),
		BackgroundTransparency = 1,
		CanvasSize = UDim2.new(0, 0, 0, 0),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ScrollBarThickness = 6,
	}, shop)
	make("UIListLayout", { Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder }, shopList)

	local catalog = require(Shared.Config.CreatureCatalog)
	for order, entry in catalog.species do
		local row = make("Frame", {
			Size = UDim2.new(1, -8, 0, 40),
			BackgroundColor3 = Color3.fromRGB(40, 40, 50),
			LayoutOrder = order,
		}, shopList)
		corner(6, row)
		make("TextLabel", {
			Size = UDim2.new(0.62, 0, 1, 0),
			Position = UDim2.fromOffset(6, 0),
			BackgroundTransparency = 1,
			TextColor3 = RarityConfig.colors[entry.rarity],
			TextScaled = true,
			Font = Enum.Font.GothamBold,
			Text = ("%s $%d"):format(entry.name, entry.cost),
			TextXAlignment = Enum.TextXAlignment.Left,
		}, row)
		local buy = button("BUY", UDim2.new(0.28, 0, 0.7, 0), UDim2.new(0.68, 0, 0.15, 0), Color3.fromRGB(70, 130, 200), row)
		buy.MouseButton1Click:Connect(function()
			task.spawn(function()
				require(script.Parent.NetworkController).RequestBuy(entry.id)
			end)
		end)
	end

	-- Roster / fusion panel (right side).
	local rosterPanel = make("Frame", {
		Name = "Roster",
		Size = UDim2.fromOffset(280, 380),
		Position = UDim2.new(1, -292, 0.5, -190),
		BackgroundColor3 = Color3.fromRGB(25, 25, 32),
		BackgroundTransparency = 0.1,
	}, gui)
	corner(10, rosterPanel)
	make("TextLabel", {
		Size = UDim2.new(1, 0, 0, 30),
		BackgroundTransparency = 1,
		TextColor3 = Color3.new(1, 1, 1),
		TextScaled = true,
		Font = Enum.Font.GothamBold,
		Text = "ROSTER + FUSION LAB",
	}, rosterPanel)

	local rosterList = make("ScrollingFrame", {
		Name = "RosterList",
		Size = UDim2.new(1, -16, 1, -110),
		Position = UDim2.fromOffset(8, 34),
		BackgroundTransparency = 1,
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		CanvasSize = UDim2.new(0, 0, 0, 0),
		ScrollBarThickness = 6,
	}, rosterPanel)
	make("UIListLayout", { Padding = UDim.new(0, 4), SortOrder = Enum.SortOrder.LayoutOrder }, rosterList)

	local fuseInfo = make("TextLabel", {
		Name = "FuseInfo",
		Size = UDim2.new(1, -16, 0, 24),
		Position = UDim2.new(0, 8, 1, -72),
		BackgroundTransparency = 1,
		TextColor3 = Color3.fromRGB(255, 200, 100),
		TextScaled = true,
		Font = Enum.Font.Gotham,
		Text = "Pick two to fuse",
	}, rosterPanel)

	local fuseBtn = button("FUSE", UDim2.new(1, -76, 0, 34), UDim2.new(0, 8, 1, -42), Color3.fromRGB(200, 120, 40), rosterPanel)
	fuseBtn.MouseButton1Click:Connect(function()
		if #fuseSelection == 2 then
			task.spawn(function()
				require(script.Parent.NetworkController).RequestFuse(fuseSelection[1], fuseSelection[2])
			end)
			table.clear(fuseSelection)
		end
	end)

	refs.gui = gui
	refs.rosterList = rosterList
	refs.fuseInfo = fuseInfo
end

-- ------------------------------------------------------------ rendering

local function renderRoster(roster)
	if not refs.rosterList then
		return
	end
	refs.rosterList:ClearAllChildren()

	-- Keep list layout alive after clear.
	make("UIListLayout", { Padding = UDim.new(0, 4), SortOrder = Enum.SortOrder.LayoutOrder }, refs.rosterList)

	-- Preserve selections across renders; drop creatures that are gone.
	local alive = {}
	for _, creature in roster do
		if table.find(fuseSelection, creature.uid) then
			table.insert(alive, creature.uid)
		end
	end
	fuseSelection = alive

	for index, creature in roster do
		local rarityColor = RarityConfig.colors[creature.rarity] or Color3.new(1, 1, 1)
		local row = make("Frame", {
			Size = UDim2.new(1, -8, 0, 46),
			BackgroundColor3 = Color3.fromRGB(40, 40, 50),
			LayoutOrder = index,
		}, refs.rosterList)
		corner(6, row)

		local selectBtn = button("", UDim2.new(0.14, 0, 0.7, 0), UDim2.fromOffset(4, 7), Color3.fromRGB(70, 70, 85), row)
		selectBtn.Text = if table.find(fuseSelection, creature.uid) then "x" else "+"
		selectBtn.MouseButton1Click:Connect(function()
			local found = table.find(fuseSelection, creature.uid)
			if found then
				table.remove(fuseSelection, found)
				selectBtn.Text = "+"
				selectBtn.BackgroundColor3 = Color3.fromRGB(70, 70, 85)
			else
				if #fuseSelection >= 2 then
					return
				end
				table.insert(fuseSelection, creature.uid)
				selectBtn.Text = tostring(#fuseSelection)
				selectBtn.BackgroundColor3 = Color3.fromRGB(200, 120, 40)
			end
			refs.fuseInfo.Text = if #fuseSelection == 2
				then "Ready! Hit FUSE."
				else ("Selected %d/2"):format(#fuseSelection)
		end)

		make("TextLabel", {
			Size = UDim2.new(0.52, 0, 0.5, 0),
			Position = UDim2.fromOffset(38, 2),
			BackgroundTransparency = 1,
			TextColor3 = rarityColor,
			TextScaled = true,
			Font = Enum.Font.GothamBold,
			Text = creature.name,
			TextXAlignment = Enum.TextXAlignment.Left,
		}, row)

		make("TextLabel", {
			Size = UDim2.new(0.52, 0, 0.4, 0),
			Position = UDim2.new(0, 38, 0.55, 0),
			BackgroundTransparency = 1,
			TextColor3 = Color3.fromRGB(180, 180, 195),
			TextScaled = true,
			Font = Enum.Font.Gotham,
			Text = ("$%s/s | Gen %d"):format(tostring(creature.income), creature.generation),
			TextXAlignment = Enum.TextXAlignment.Left,
		}, row)

		local sellBtn = button("$", UDim2.new(0.18, 0, 0.7, 0), UDim2.new(1, -46, 0.15, 0), Color3.fromRGB(150, 60, 60), row)
		sellBtn.MouseButton1Click:Connect(function()
			task.spawn(function()
				require(script.Parent.NetworkController).RequestSell(creature.uid)
			end)
		end)
	end
end

--- Wire signals; call once after Init.
function UI.Start(network)
	network.StateChanged:Connect(function(payload)
		state = payload
		local cashLabel = refs.gui:FindFirstChild("Cash")
		local incomeLabel = refs.gui:FindFirstChild("Income")
		if cashLabel then
			cashLabel.Text = ("$%d"):format(payload.cash)
		end
		if incomeLabel then
			incomeLabel.Text = ("$%s/s | x%.2f mult | Rebirths: %d"):format(
				tostring(math.floor(payload.totalIncome)),
				payload.incomeMultiplier,
				payload.rebirths
			)
		end
		renderRoster(payload.roster or {})
	end)

	network.Announced:Connect(function(message, kind)
		local ticker = refs.gui and refs.gui:FindFirstChild("TickerText")
		if ticker then
			ticker.Text = message
			ticker.TextColor3 = kind == "danger" and Color3.fromRGB(255, 90, 90)
				or kind == "theft" and Color3.fromRGB(255, 170, 60)
				or kind == "fusion" and Color3.fromRGB(160, 120, 255)
				or Color3.fromRGB(255, 230, 130)
		end
	end)

	network.FusionComplete:Connect(function(childView)
		local ticker = refs.gui and refs.gui:FindFirstChild("TickerText")
		if ticker then
			ticker.Text = ("FUSION! You created %s ($%s/s)"):format(childView.name, tostring(childView.income))
			ticker.TextColor3 = Color3.fromRGB(160, 255, 160)
		end
	end)
end

return UI
