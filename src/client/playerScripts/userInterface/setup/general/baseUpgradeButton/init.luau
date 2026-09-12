-- Roblox Services
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Packages
local knit = require(ReplicatedStorage.src.Packages.knit)

-- Utility Modules
local WaitForUiDesc = require(ReplicatedStorage.src.utility.WaitForUiDesc)
local NumberShortner = require(ReplicatedStorage.src.utility.NumberShortner)

-- Config Modules
local baseUpgradeConfig = require(ReplicatedStorage.src.GameConfiguration.Economy.baseUpgradeConfig)

-->
local BaseUpgradeButton = {}

-- Private Methods
function BaseUpgradeButton:sync(level: number)
	local LevelConfig = baseUpgradeConfig.Levels[level]
	self.CostLabel.Text = `${NumberShortner(LevelConfig.UpgradeCost)}`
	self.ProgressLabel.Text = `Lvl {level} > Lvl {level + 1}`

	if level >= #baseUpgradeConfig.Levels then
		self.CostLabel.Text = `Max`
		self.ProgressLabel.Text = `Lvl {level} > Max`
		self.ButtonsController:Unlink(self.Button)
		self.Button:RemoveTag("GuiButton")
	end
end
function BaseUpgradeButton:connect()
	self.Button:AddTag("GuiButton")
	self.Button:SetAttribute("Type", "Action")
	self.Button:SetAttribute("Action", "UpgradeBase")
end

-- LifeCycle
function BaseUpgradeButton:Init(player: Player)
	self.BaseUpgradeController = knit.GetController("BaseUpgradeController")
	self.BaseController = knit.GetController("BaseController")
	self.DataController = knit.GetController("DataController")
	self.ButtonsController = knit.GetController("ButtonsController")

	self.Base = self.BaseController:GetBase()
	self.Gui = WaitForUiDesc(self.Base, "SurfaceGui", {
		Name = "BaseUpgradeGui",
	})

	self.Button = self.Gui:WaitForChild("Detection")
	self.ProgressLabel = self.Gui:WaitForChild("Progress")
	self.CostLabel = self.Button:WaitForChild("TextLabel")

	self:connect()
	self:sync(self.DataController:GetValue("BaseLevel"))

	self.DataController:GetValueChangedSignal("BaseLevel"):Connect(function(newLevel: number)
		self:sync(newLevel)
	end)
end

return BaseUpgradeButton
