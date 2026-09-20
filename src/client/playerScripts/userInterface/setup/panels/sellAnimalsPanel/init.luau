-- Roblox Services
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Packages
local knit = require(ReplicatedStorage.src.Packages.knit)

-- Utility Modules
local NumberShortner = require(ReplicatedStorage.src.utility.NumberShortner)
local ScrollingCanvas = require(ReplicatedStorage.src.utility.scrollingCanvas)

-- Config Modules
local SellConfig = require(ReplicatedStorage.src.GameConfiguration.Economy.animalSellConfig)

-- Modules
local Row = require(script.row)

-->
local SellAnimalsPanel = {
	Rows = {},
	Data = {},
	Connections = {},
	LinkedButtons = {},
}

-- Private Methods
function SellAnimalsPanel:update()
	if not self.Ready or not self.Frame.Visible then
		return
	end
	local inventory = self.Data.Inventory or {}
	local equipped = self.Data.EquippedAnimals or {}
	for referenceName, row in pairs(self.Rows) do
		local item = inventory[referenceName]
		if not item or (item.Handler ~= "Animal" and item.Handler ~= "Egg") then
			Row.Destroy(row, self.Buttons)
			self.Rows[referenceName] = nil
		end
	end

	local ordered = {}
	local total = 0
	for referenceName, item in pairs(inventory) do
		if item.Handler ~= "Animal" and item.Handler ~= "Egg" then
			continue
		end
		local quote = SellConfig.GetQuote(item, self.Data.CashMultiplier, self.Data.AllTimeCashMultiplier)
		total += quote and quote.Price or 0
		table.insert(ordered, { ReferenceName = referenceName, Item = item, Quote = quote })
	end

	table.sort(ordered, function(a, b)
		local aEgg, bEgg = a.Item.Handler == "Egg", b.Item.Handler == "Egg"
		if aEgg ~= bEgg then
			return not aEgg
		end
		local aPrice, bPrice = a.Quote and a.Quote.Price or 0, b.Quote and b.Quote.Price or 0
		if aPrice ~= bPrice then
			return aPrice > bPrice
		end
		return a.ReferenceName < b.ReferenceName
	end)

	for index, entry in ipairs(ordered) do
		local referenceName = entry.ReferenceName
		local row = self.Rows[referenceName]
		if not row then
			row = Row.Create(self.Template, referenceName, self.Buttons)
			self.Rows[referenceName] = row
		end
		row.Frame.LayoutOrder = index
		Row.Update(
			row,
			entry.Item,
			equipped[referenceName] ~= nil and equipped[referenceName] ~= false,
			entry.Quote,
			self.Controller.Pending
		)
	end

	self.Header.Text = `SELL ALL ANIMALS FOR ${NumberShortner(total)}`
	self.SellAll.Interactable = not self.Controller.Pending
	self.SellAll.Active = not self.Controller.Pending
end

function SellAnimalsPanel:queueUpdate()
	if not self.Ready or self.UpdateQueued then
		return
	end
	self.UpdateQueued = true
	task.defer(function()
		self.UpdateQueued = false
		self:update()
	end)
end

function SellAnimalsPanel:link(button: GuiButton)
	self.Buttons:Unlink(button)
	CollectionService:AddTag(button, "GuiButton")
	self.Buttons:Link(button)
	table.insert(self.LinkedButtons, button)
end

-- LifeCycle
function SellAnimalsPanel:Init(player: Player)
	self.Controller = knit.GetController("AnimalSellController")
	self.Buttons = knit.GetController("ButtonsController")
	local dataController = knit.GetController("DataController")
	self.Frame = player.PlayerGui:WaitForChild("Panels"):WaitForChild("SellAnimals")
	local body = self.Frame:WaitForChild("Body")
	local content = body:WaitForChild("Content")
	local scrolling = content:WaitForChild("Holder"):WaitForChild("ScrollingFrame")
	self.Template = scrolling:WaitForChild("PetsTemplate")
	self.Template.Visible = false
	local layout = scrolling:FindFirstChildOfClass("UIListLayout")
	if layout then
		layout.SortOrder = Enum.SortOrder.LayoutOrder
	end
	for _, connection in ipairs(ScrollingCanvas.Connect(scrolling)) do
		table.insert(self.Connections, connection)
	end

	self.SellAll = content:FindFirstChild("SellAll") or body:WaitForChild("SellAll")
	self.SellAll:SetAttribute("Type", "Action")
	self.SellAll:SetAttribute("Action", "SellAllAnimals")
	self:link(self.SellAll)
	local header = self.Frame:FindFirstChild("Header") or body:WaitForChild("Header")
	self.Header = header:WaitForChild("Header")
	local close = header:WaitForChild("Shop")
	close:SetAttribute("Type", "PanelToggler")
	close:SetAttribute("PanelName", "SellAnimals")
	self:link(close)

	for _, key in ipairs({ "Inventory", "EquippedAnimals", "CashMultiplier", "AllTimeCashMultiplier" }) do
		self.Data[key] = dataController:GetValue(key)
		table.insert(
			self.Connections,
			dataController:GetValueChangedSignal(key):Connect(function(value)
				self.Data[key] = value
				self:queueUpdate()
			end)
		)
	end
	table.insert(
		self.Connections,
		self.Controller.Changed:Connect(function()
			self:queueUpdate()
		end)
	)
	table.insert(
		self.Connections,
		self.Frame:GetPropertyChangedSignal("Visible"):Connect(function()
			self:queueUpdate()
		end)
	)
	self.Ready = true
	self:update()

	self.Frame.Destroying:Once(function()
		self.Ready = false
		for _, connection in ipairs(self.Connections) do
			connection:Disconnect()
		end
		for _, row in pairs(self.Rows) do
			Row.Destroy(row, self.Buttons)
		end
		for _, button in ipairs(self.LinkedButtons) do
			self.Buttons:Unlink(button)
		end
		table.clear(self.Rows)
		table.clear(self.Connections)
	end)
end

return SellAnimalsPanel
