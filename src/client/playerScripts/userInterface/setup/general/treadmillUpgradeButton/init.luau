-- Roblox Services
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Packages
local knit = require(ReplicatedStorage.src.Packages.knit)

-- Utility Modules
local WaitForUiDesc = require(ReplicatedStorage.src.utility.WaitForUiDesc)
local NumberShortner = require(ReplicatedStorage.src.utility.NumberShortner)

-- Config Modules
local treadmillConfig = require(ReplicatedStorage.src.GameConfiguration.Gameplay.treadmillConfig)

-->
local TreadmillUpgradeButton = {}

function TreadmillUpgradeButton:syncGui()
	local currentLevel = self.TreadmillController:GetLevel()
	local isMaxLevel = currentLevel >= treadmillConfig.MaxLevel

	if not isMaxLevel then
		self.ProgressText.Text = `Lvl {currentLevel} > Lvl {currentLevel + 1}`
		self.CostText.Text = `${NumberShortner(self.TreadmillController:GetLevelCost(currentLevel + 1))}`
	else
		self.ButtonsController:Unlink(self.Button)
		self.ProgressText.Text = `Max Level`
		self.CostText.Text = "Max"
	end
end

function TreadmillUpgradeButton:connectButton()
	self.Button:AddTag("GuiButton")
	self.Button:SetAttribute("Type", "Action")
	self.Button:SetAttribute("Action", "UpgradeTreadmill")
end

-- LifeCycle
function TreadmillUpgradeButton:Init()
	self.BaseController = knit.GetController("BaseController")
	self.TreadmillController = knit.GetController("TreadmillController")
	self.DataController = knit.GetController("DataController")
	self.ButtonsController = knit.GetController("ButtonsController")

	self.Base = self.BaseController:GetBase()
	self.Gui = WaitForUiDesc(self.Base, "SurfaceGui", {
		Name = "TreadmillUpgradeGui",
	})

	self.Button = self.Gui:WaitForChild("Detection")
	self.ProgressText = self.Gui:WaitForChild("Progress")
	self.CostText = self.Button:WaitForChild("TextLabel")

	self:connectButton()
	self:syncGui()

	self.DataController:GetValueChangedSignal("TreadmillLevel"):Connect(function()
		self:syncGui()
	end)
end

return TreadmillUpgradeButton
