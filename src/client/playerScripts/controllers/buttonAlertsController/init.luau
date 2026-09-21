-- Roblox Services
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Packages
local knit = require(ReplicatedStorage.src.Packages.knit)

-- Config Modules
local RebirthConfig = require(ReplicatedStorage.src.GameConfiguration.Economy.rebirthConfig)

-->
local ButtonAlertsController = knit.CreateController({
	Name = "ButtonAlertsController",
	Connections = {},
	Buttons = {},
	Data = {},
	InventoryItems = {},
	ReadyEggs = {},
	PlacedEggs = {},
	Unread = { Eggs = {}, Animals = {} },
	Open = {},
})

-- Private Methods
function ButtonAlertsController:setAlert(name: string, visible: boolean)
	local button = self.Buttons[name]
	if not button then
		return
	end

	if visible then
		self.ButtonsController:IncrementButtonAlerts(button, 1)
	else
		self.ButtonsController:ClearButtonAlerts(button)
	end
end

function ButtonAlertsController:acknowledge(name: string)
	if self.Unread[name] then
		table.clear(self.Unread[name])
	end

	self:setAlert(name, false)
end

function ButtonAlertsController:updateInventory(inventory, initial: boolean?)
	local current = {}
	for reference, item in pairs(inventory) do
		local category = item.Handler == "Animal" and "Animals" or item.Handler == "Egg" and "Eggs"
		if category then
			current[reference] = category
			if not initial and self.InventoryItems[reference] ~= category and not self.Open[category] then
				self.Unread[category][reference] = true
			end
		end
	end

	self.InventoryItems = current
	for category, unread in pairs(self.Unread) do
		for reference in pairs(unread) do
			if current[reference] ~= category and not (category == "Eggs" and self.PlacedEggs[reference]) then
				unread[reference] = nil
			end
		end
		self:setAlert(category, next(unread) ~= nil)
	end
end

function ButtonAlertsController:updateEggs(placed, initial: boolean?)
	local ready = {}
	local current = {}
	for reference, egg in pairs(placed) do
		current[reference] = true
		if not initial and not self.PlacedEggs[reference] and not self.Open.Eggs then
			self.Unread.Eggs[reference] = true
		end
		if egg.CanHatch then
			ready[reference] = true
			if not self.ReadyEggs[reference] and not self.Open.Eggs then
				self.Unread.Eggs[reference] = true
			end
		end
	end

	self.ReadyEggs = ready
	self.PlacedEggs = current
	for reference in pairs(self.Unread.Eggs) do
		if not current[reference] and self.InventoryItems[reference] ~= "Eggs" then
			self.Unread.Eggs[reference] = nil
		end
	end
	self:setAlert("Eggs", next(self.Unread.Eggs) ~= nil)
end

function ButtonAlertsController:updateIndex(index)
	for animal, discovered in pairs(index.Discovered or {}) do
		if discovered and not (index.Claimed or {})[animal] then
			self:setAlert("Index", true)
			return
		end
	end

	self:setAlert("Index", false)
end

function ButtonAlertsController:updateRebirth()
	local count = self.Data.Rebirths or 0
	local multiplier = RebirthConfig.GetMultiplier(count + 1)
	local eligible = RebirthConfig.Enabled
		and count + 1 < 2 ^ 53
		and (RebirthConfig.MaxRebirths == 0 or count < RebirthConfig.MaxRebirths)
		and multiplier > 0
		and multiplier < math.huge

	for key, required in pairs(RebirthConfig.GetRequirements(count)) do
		local value = self.Data[key]
		if
			type(value) ~= "number"
			or value ~= value
			or value < 0
			or value == math.huge
			or required ~= required
			or required < 0
			or required == math.huge
			or value < required
		then
			eligible = false
		end
	end

	self:setAlert("Rebirth", eligible)
	if eligible and not self.RebirthReady then
		self.NotificationController:Push({
			Message = "You can rebirth now!",
			Color = Color3.fromRGB(210, 170, 255),
			Sound = "Generic",
		})
	end
	self.RebirthReady = eligible
end

function ButtonAlertsController:watch(key: string, callback)
	table.insert(self.Connections, self.DataController:GetValueChangedSignal(key):Connect(callback))
end

-- Public Methods
-- Called after button signal listeners exist, so initial alerts cannot be lost during KnitStart.
function ButtonAlertsController:Start(player: Player)
	if self.Started then
		return
	end
	self.Started = true

	local hud = player.PlayerGui:WaitForChild("Hud")
	local left = hud:WaitForChild("LeftMain"):WaitForChild("Left"):WaitForChild("Row1")
	local right = hud:WaitForChild("RightMain"):WaitForChild("Right"):WaitForChild("Row1")
	for name, parent in pairs({ Index = left, Shop = left, Rebirth = left, Animals = right, Eggs = right }) do
		local frame = parent:WaitForChild(name == "Rebirth" and "REBIRTHS" or string.upper(name))
		local button = frame:WaitForChild("Detection")
		self.Buttons[name] = button
		button:SetAttribute("KeepAlertUntilCleared", name == "Index" or name == "Rebirth")
		self:setAlert(name, name == "Shop")
		if name == "Shop" or name == "Animals" or name == "Eggs" then
			table.insert(
				self.Connections,
				button.Activated:Connect(function()
					self:acknowledge(name)
				end)
			)
		end
	end

	self.Open.Eggs = self.EggController.Visible
	self.Open.Animals = self.AnimalLoadoutController.Visible
	self:updateInventory(self.DataController:GetValue("Inventory"), true)
	self:updateEggs(self.DataController:GetValue("PlacedEggs"), true)
	self:updateIndex(self.DataController:GetValue("AnimalIndex"))
	self:watch("Inventory", function(value)
		self:updateInventory(value)
	end)
	self:watch("PlacedEggs", function(value)
		self:updateEggs(value)
	end)
	self:watch("AnimalIndex", function(value)
		self:updateIndex(value)
	end)

	for name, controller in pairs({ Eggs = self.EggController, Animals = self.AnimalLoadoutController }) do
		table.insert(
			self.Connections,
			controller.Signals.ToggleVisibility:Connect(function(visible)
				self.Open[name] = visible
				if visible then
					self:acknowledge(name)
				end
			end)
		)
	end
	table.insert(
		self.Connections,
		self.PanelController.PanelStateChanged:Connect(function(state)
			if state.Visible and state.PanelName == "Shop" then
				self:acknowledge("Shop")
			end
		end)
	)
	if self.PanelController.ActivePanel == "Shop" then
		self:acknowledge("Shop")
	end

	local keys = { Rebirths = true }
	for key in pairs(RebirthConfig.Requirements) do
		keys[key] = true
	end
	for _, override in pairs(RebirthConfig.Overrides) do
		for key in pairs(override.Requirements or {}) do
			keys[key] = true
		end
	end
	for key in pairs(keys) do
		self.Data[key] = self.DataController:GetValue(key)
		self:watch(key, function(value)
			self.Data[key] = value
			-- Rebirth resets several values together; evaluate once after replication callbacks.
			if not self.RebirthUpdateQueued then
				self.RebirthUpdateQueued = true
				task.defer(function()
					self.RebirthUpdateQueued = false
					self:updateRebirth()
				end)
			end
		end)
	end
	self:updateRebirth()

	hud.Destroying:Once(function()
		for _, connection in ipairs(self.Connections) do
			connection:Disconnect()
		end
		table.clear(self.Connections)
	end)
end

-- LifeCycle
function ButtonAlertsController:KnitInit()
	self.ButtonsController = knit.GetController("ButtonsController")
	self.DataController = knit.GetController("DataController")
	self.NotificationController = knit.GetController("NotificationController")
	self.PanelController = knit.GetController("PanelController")
	self.EggController = knit.GetController("EggController")
	self.AnimalLoadoutController = knit.GetController("AnimalLoadoutController")
end

return ButtonAlertsController
