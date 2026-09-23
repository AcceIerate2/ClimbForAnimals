-- Roblox Services
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Packages
local knit = require(ReplicatedStorage.src.Packages.knit)

-- Utility Modules
local NumberShortner = require(ReplicatedStorage.src.utility.NumberShortner)

-- Config Modules
local Config = require(ReplicatedStorage.src.GameConfiguration.Economy.staminaUpgradeConfig)
local TutorialConfig = require(ReplicatedStorage.src.GameConfiguration.Gameplay.tutorialConfig)

-->
local StaminaPanel = { Connections = {}, LinkedButtons = {} }

-- Private Methods
function StaminaPanel:update()
	local level = Config.NormalizeLevel(self.Level)
	local price = Config.GetPrice(level)
	if price and TutorialConfig.IsFreeStamina(self.Tutorial, level, Config.BaseLevel) then
		price = 0
	end
	-- Stamina points, the same numbers the HUD bar shows, instead of the level index.
	self.CurrentLevel.Text = tostring(Config.GetMaxStamina(level))
	self.NewLevel.Text = price and tostring(Config.GetMaxStamina(level + 1)) or "MAX"
	self.Price.Text = self.Controller.Pending and "..."
		or (price == 0 and "FREE" or (price and `${NumberShortner(price)}` or "MAX"))
	-- Keep insufficient-funds and maximum-level feedback reachable through the button.
	self.Purchase.Active = not self.Controller.Pending
	self.Purchase.Interactable = not self.Controller.Pending
end

function StaminaPanel:link(button, buttonType, key, value)
	self.Buttons:Unlink(button)
	button:SetAttribute("Type", buttonType)
	button:SetAttribute(key, value)
	CollectionService:AddTag(button, "GuiButton")
	self.Buttons:Link(button)
	table.insert(self.LinkedButtons, button)
end

-- LifeCycle
function StaminaPanel:Init(player: Player)
	self.Controller = knit.GetController("StaminaUpgradeController")
	self.Buttons = knit.GetController("ButtonsController")
	local data = knit.GetController("DataController")
	local frame = player.PlayerGui:WaitForChild("Panels"):WaitForChild("Stamina")
	local requirements = frame:WaitForChild("Body"):WaitForChild("Content"):WaitForChild("Requirements")
	local stud = requirements:WaitForChild("Stud")
	self.CurrentLevel = stud:WaitForChild("CurrentLevel")
	self.NewLevel = stud:WaitForChild("NewLevel")
	self.Purchase = requirements:WaitForChild("PurchaseBtn")
	self.Price = self.Purchase:WaitForChild("TextLabel")
	self:link(self.Purchase, "Action", "Action", "UpgradeStamina")

	local header = frame:FindFirstChild("Header") or frame.Body:FindFirstChild("Header")
	local close = header
		and (
			header:FindFirstChild("Close", true)
			or header:FindFirstChild("Shop")
			or header:FindFirstChildWhichIsA("GuiButton", true)
		)
	if close then
		self:link(close, "PanelToggler", "PanelName", "Stamina")
	end

	self.Level = data:GetValue("StaminaLevel")
	self.Tutorial = data:GetValue("Tutorial")
	table.insert(
		self.Connections,
		data:GetValueChangedSignal("Tutorial"):Connect(function(state)
			self.Tutorial = state
			self:update()
		end)
	)
	table.insert(
		self.Connections,
		data:GetValueChangedSignal("StaminaLevel"):Connect(function(level)
			self.Level = level
			self:update()
		end)
	)
	table.insert(
		self.Connections,
		self.Controller.Changed:Connect(function()
			self:update()
		end)
	)
	self:update()

	frame.Destroying:Once(function()
		for _, connection in ipairs(self.Connections) do
			connection:Disconnect()
		end
		for _, button in ipairs(self.LinkedButtons) do
			self.Buttons:Unlink(button)
		end
	end)
end

return StaminaPanel
