-- Roblox Services
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Packages
local knit = require(ReplicatedStorage.src.Packages.knit)

-- Utility Modules
local NumberShortner = require(ReplicatedStorage.src.utility.NumberShortner)

-- Constants
local RobuxIcon = utf8.char(0xE002)
local DebugPassPrompts = false -- TEMPORARY: set false to restore disabled "Unavailable" pass buttons.

-->
local ShopPanel = {
	Connections = {},
	LinkedButtons = {},
	Items = {},
}

-- Private Methods
function ShopPanel:link(button)
	self.Buttons:Unlink(button)
	CollectionService:AddTag(button, "GuiButton")
	self.Buttons:Link(button)
	table.insert(self.LinkedButtons, button)
end

function ShopPanel:updateItem(entry)
	local owned = entry.Item.PurchaseType == "GamePass" and self.Controller:OwnsPass(entry.Item.Id)
	local testPrompt = DebugPassPrompts and entry.Item.PurchaseType == "GamePass" and entry.Available == false
	entry.Button:SetAttribute("DebugPurchasePrompt", testPrompt)
	entry.Label.Text = owned and "Owned" or testPrompt and "Test Purchase" or entry.PriceText or "Loading..."
	entry.Button.Interactable = not owned and (entry.Available == true or testPrompt)
end

function ShopPanel:refresh()
	if self.Loading or self.Destroyed then
		return
	end

	self.Loading = true
	local catalog = self.Controller:GetShopCatalog()
	if self.Destroyed then
		return
	end

	if not catalog then
		for _, entry in pairs(self.Items) do
			if not entry.Item then
				entry.Label.Text = "Unavailable"
			end
		end
		self.Loading = false
		return
	end

	for _, item in ipairs(catalog) do
		local entry = self.Items[item.Key]
		if not entry then
			continue
		end

		entry.Item = item
		entry.Button:SetAttribute("Type", "Purchase")
		entry.Button:SetAttribute("PurchaseType", item.PurchaseType)
		entry.Button:SetAttribute("Id", item.Id)
		if not entry.Linked then
			self:link(entry.Button)
			entry.Linked = true
		end

		if entry.Amount and type(item.CashAmount) == "number" then
			entry.Amount.Text = `${NumberShortner(item.CashAmount)}`
		end
		self:updateItem(entry)

		local info = self.Controller:getMonetizationItemInfo(item.PurchaseType, item.Id)
		if self.Destroyed then
			return
		end

		entry.Available = info ~= nil and type(info.PriceInRobux) == "number" and info.IsForSale ~= false
		entry.PriceText = entry.Available and `{RobuxIcon} {info.PriceInRobux}` or "Unavailable"
		self:updateItem(entry)
	end

	self.Loading = false
end

-- LifeCycle
function ShopPanel:Init(player: Player)
	self.Controller = knit.GetController("MonetizationController")
	self.Buttons = knit.GetController("ButtonsController")
	self.Frame = player.PlayerGui:WaitForChild("Panels"):WaitForChild("Shop")
	local content = self.Frame:WaitForChild("Body"):WaitForChild("Content")
	local scrolling = content:WaitForChild("Holder"):WaitForChild("ScrollingFrame")
	local cash = scrolling:WaitForChild("Cash")

	for _, name in ipairs({ "Hatch2x", "Cash2x" }) do
		local button = scrolling:WaitForChild(name):WaitForChild("PurchaseBtn")
		self.Items[name] = { Button = button, Label = button:WaitForChild("TextLabel") }
	end

	for index = 1, 5 do
		local name = `cashProduct{index}`
		local button = cash:WaitForChild(name)
		local frame = button:WaitForChild("Frame")
		self.Items[name] = {
			Button = button,
			Label = frame:WaitForChild("price"),
			Amount = frame:WaitForChild("cashAmount"),
		}
	end

	for _, entry in pairs(self.Items) do
		entry.Label.Text = "Loading..."
		entry.Button.Interactable = false
	end

	local header = self.Frame:FindFirstChild("Header") or self.Frame.Body:FindFirstChild("Header")
	local close = header and (header:FindFirstChild("Close", true) or header:FindFirstChildWhichIsA("GuiButton", true))
	if close and close:IsA("GuiButton") then
		close:SetAttribute("Type", "PanelToggler")
		close:SetAttribute("PanelName", "Shop")
		self:link(close)
	end

	table.insert(
		self.Connections,
		self.Controller.OwnershipChanged:Connect(function()
			for _, entry in pairs(self.Items) do
				if entry.Item then
					self:updateItem(entry)
				end
			end
		end)
	)

	table.insert(
		self.Connections,
		self.Frame:GetPropertyChangedSignal("Visible"):Connect(function()
			if self.Frame.Visible then
				self:refresh()
			end
		end)
	)

	self.Frame.Destroying:Once(function()
		self.Destroyed = true
		for _, connection in ipairs(self.Connections) do
			connection:Disconnect()
		end
		for _, button in ipairs(self.LinkedButtons) do
			self.Buttons:Unlink(button)
		end
	end)

	task.spawn(function()
		self:refresh()
	end)
end

return ShopPanel
