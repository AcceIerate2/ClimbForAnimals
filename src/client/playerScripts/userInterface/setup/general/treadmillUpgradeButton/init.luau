-- Roblox Services
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Packages
local knit = require(ReplicatedStorage.src.Packages.knit)

-- Utility Modules
local WaitForUiDesc = require(ReplicatedStorage.src.utility.WaitForUiDesc)
local NumberShortner = require(ReplicatedStorage.src.utility.NumberShortner)

-- Config Modules
local treadmillConfig = require(ReplicatedStorage.src.GameConfiguration.Economy.treadmillConfig)

-->
local TreadmillUpgradeButton = {}

-- The badge over the sign is on only while the upgrade is actually affordable, so a glance at the
-- plot says what can be bought. NextCost is nil at max level, which keeps it off for good.
function TreadmillUpgradeButton:syncNotification()
	if not self.Notification then
		return
	end

	local cash = self.DataController:GetValue("Cash")
	local affordable = self.NextCost ~= nil and typeof(cash) == "number" and cash >= self.NextCost
	if self.Notification.Enabled ~= affordable then
		self.Notification.Enabled = affordable
	end
end

function TreadmillUpgradeButton:syncGui()
	local currentLevel = self.TreadmillController:GetLevel()
	local isMaxLevel = currentLevel >= treadmillConfig.MaxLevel

	if not isMaxLevel then
		self.NextCost = self.TreadmillController:GetLevelCost(currentLevel + 1)
		self.ProgressText.Text = `Lvl {currentLevel} > Lvl {currentLevel + 1}`
		self.CostText.Text = `${NumberShortner(self.NextCost)}`
	else
		self.NextCost = nil
		self.ButtonsController:Unlink(self.Button)
		self.ProgressText.Text = `Lvl {currentLevel} > Max`
		self.CostText.Text = "Max"
		self.Button:RemoveTag("GuiButton")
	end

	self:syncNotification()
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

	-- The badge lives on an attachment next to the sign's SurfaceGui, inside the same part.
	local attachment = self.Gui.Parent:WaitForChild("PlotUpdateAttachment")
	self.Notification = attachment:WaitForChild("UpdPlotNotification") :: BillboardGui
	self.Notification.Enabled = false

	self:connectButton()
	self:syncGui()

	self.DataController:GetValueChangedSignal("TreadmillLevel"):Connect(function()
		self:syncGui()
	end)

	self.DataController:GetValueChangedSignal("Cash"):Connect(function()
		self:syncNotification()
	end)
end

return TreadmillUpgradeButton
