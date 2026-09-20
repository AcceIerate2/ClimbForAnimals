-- Roblox Services
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Packages
local knit = require(ReplicatedStorage.src.Packages.knit)

-- Utility Modules
local Spring = require(ReplicatedStorage.src.utility.Spring)
local ScrollingCanvas = require(ReplicatedStorage.src.utility.scrollingCanvas)
local NumberShortner = require(ReplicatedStorage.src.utility.NumberShortner)
local EarningCurve = require(ReplicatedStorage.src.utility.earningCurve)

-- Config Modules
local baseUpgradeConfig = require(ReplicatedStorage.src.GameConfiguration.Economy.baseUpgradeConfig)
local animalConfig = require(ReplicatedStorage.src.GameConfiguration.Gameplay.animalConfig)
local RebirthConfig = require(ReplicatedStorage.src.GameConfiguration.Economy.rebirthConfig)

-- Modules
local Row = require(script.row)

local Animals = { Rows = {}, Connections = {}, Visible = false, VisibilityRevision = 0 }

-- Private Methods
function Animals:toggleVisibility(visible: boolean)
	self.Visible = visible
	self.VisibilityRevision += 1
	local revision = self.VisibilityRevision
	if visible then
		self.Frame.Visible = true
	end

	Spring.target(self.Frame, 0.75, 6, {
		Position = visible and self.VisiblePosition or self.HiddenPosition,
	})
	Spring.completed(self.Frame, function()
		if self.VisibilityRevision == revision and not self.Visible then
			self.Frame.Visible = false
		end
	end)
end

function Animals:updateAnimals()
	local inventory = self.Data.Inventory
	local equipped = self.Data.EquippedAnimals
	local slots = self.Data.MaxAnimals
	local count = 0
	for _ in pairs(equipped) do
		count += 1
	end
	self.Header.Text = `ACTIVE {count}/{slots}`

	local nextLevel = baseUpgradeConfig.Levels[self.Data.BaseLevel + 1]
	local price = nextLevel and nextLevel.UpgradeCost
	if self.BuySlotLabel then
		self.BuySlotLabel.Text = price and `+1 EQUIP (${NumberShortner(price)})` or "MAX SLOTS"
	end
	self.BuySlot.Active = price ~= nil
	self.BuySlot.Interactable = price ~= nil
	self.BuySlot.AutoButtonColor = price ~= nil

	for referenceName, row in pairs(self.Rows) do
		local item = inventory[referenceName]
		if not item or item.Handler ~= "Animal" or not animalConfig[item.Name] then
			Row.Destroy(row, self.ButtonsController)
			self.Rows[referenceName] = nil
		end
	end

	local ordered = {}
	for referenceName, item in pairs(inventory) do
		if item.Handler == "Animal" and animalConfig[item.Name] then
			local row = self.Rows[referenceName]
			if not row then
				row = Row.Create(self.Template, referenceName, item, self.ButtonsController)
				self.Rows[referenceName] = row
			end
			Row.Update(
				row,
				item,
				equipped[referenceName] ~= nil,
				RebirthConfig.ForSource(self.Data.CashMultiplier, "AnimalIncome")
					* (self.Data.AllTimeCashMultiplier or 1)
			)
			local custom = item.CustomData or {}
			table.insert(ordered, {
				ReferenceName = referenceName,
				Income = EarningCurve.GetCashPerSecond(item.Name, custom.AssetScale, custom.Variant),
			})
		end
	end

	table.sort(ordered, function(a, b)
		if a.Income == b.Income then
			return a.ReferenceName < b.ReferenceName
		end
		return a.Income > b.Income
	end)
	for index, entry in ipairs(ordered) do
		self.Rows[entry.ReferenceName].Frame.LayoutOrder = index
	end
end

function Animals:linkButton(button: GuiButton, action: string)
	self.ButtonsController:Unlink(button)
	button:SetAttribute("Type", "Action")
	button:SetAttribute("Action", action)
	CollectionService:AddTag(button, "GuiButton")
	self.ButtonsController:Link(button)
end

-- LifeCycle
function Animals:Init(player: Player)
	self.AnimalLoadoutController = knit.GetController("AnimalLoadoutController")
	self.ButtonsController = knit.GetController("ButtonsController")
	local dataController = knit.GetController("DataController")

	self.Frame = player.PlayerGui:WaitForChild("General"):WaitForChild("Animals")
	local body = self.Frame:WaitForChild("Body")
	self.Header = body:WaitForChild("Header"):WaitForChild("header")
	self.Container = body:WaitForChild("Holder"):WaitForChild("ScrollingFrame")
	self.Template = self.Container:WaitForChild("AnimalTemplate")
	self.Template.Visible = false
	for _, connection in ipairs(ScrollingCanvas.Connect(self.Container)) do
		table.insert(self.Connections, connection)
	end
	self.BuySlot = self.Frame:WaitForChild("BuySlot")
	self.EquipBest = self.Frame:WaitForChild("EquipBest")
	self.EquipBest.Active = true
	self.EquipBest.Interactable = true
	self.BuySlotLabel = self.BuySlot:FindFirstChildWhichIsA("TextLabel", true)
		or (self.BuySlot:IsA("TextButton") and self.BuySlot)

	self.VisiblePosition = self.Frame:GetAttribute("VisiblePosition") or self.Frame.Position
	self.HiddenPosition = self.Frame:GetAttribute("HiddenPosition")
		or UDim2.new(1.5, 0, self.VisiblePosition.Y.Scale, self.VisiblePosition.Y.Offset)
	self.Frame.Position = self.HiddenPosition
	self.Frame.Visible = false

	self:linkButton(body:WaitForChild("Close"), "CloseAnimals")
	self:linkButton(self.BuySlot, "UpgradeBase")
	self:linkButton(self.EquipBest, "EquipBestAnimals")
	table.insert(
		self.Connections,
		self.AnimalLoadoutController.Signals.ToggleVisibility:Connect(function(visible)
			self:toggleVisibility(visible)
		end)
	)

	self.Data = {}
	for _, key in ipairs({
		"Inventory",
		"EquippedAnimals",
		"MaxAnimals",
		"BaseLevel",
		"CashMultiplier",
		"AllTimeCashMultiplier",
	}) do
		self.Data[key] = dataController:GetValue(key)
		table.insert(
			self.Connections,
			dataController:GetValueChangedSignal(key):Connect(function(value)
				self.Data[key] = value
				if self.Ready and not self.UpdateQueued then
					self.UpdateQueued = true
					task.defer(function()
						self.UpdateQueued = false
						if self.Ready then
							self:updateAnimals()
						end
					end)
				end
			end)
		)
	end
	self.Ready = true
	self:updateAnimals()
	self:toggleVisibility(self.AnimalLoadoutController.Visible)

	self.Frame.Destroying:Once(function()
		self.Ready = false
		for _, connection in ipairs(self.Connections) do
			connection:Disconnect()
		end
		table.clear(self.Connections)
		for _, row in pairs(self.Rows) do
			Row.Destroy(row, self.ButtonsController)
		end
		table.clear(self.Rows)
		self.ButtonsController:Unlink(self.BuySlot)
		self.ButtonsController:Unlink(self.EquipBest)
		self.ButtonsController:Unlink(body.Close)
		self.AnimalLoadoutController:SetVisible(false)
	end)
end

return Animals
