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
-- The badge over the sign is on only while the upgrade is actually affordable, so a glance at the
-- plot says what can be bought. NextCost is nil at max level, which keeps it off for good.
function BaseUpgradeButton:syncNotification()
	if not self.Notification then
		return
	end

	local cash = self.DataController:GetValue("Cash")
	local affordable = self.NextCost ~= nil and typeof(cash) == "number" and cash >= self.NextCost
	if self.Notification.Enabled ~= affordable then
		self.Notification.Enabled = affordable
	end
end

function BaseUpgradeButton:sync(level: number)
	local nextLevel = baseUpgradeConfig.Levels[level + 1]
	if not nextLevel then
		self.NextCost = nil
		self.CostLabel.Text = `Max`
		self.ProgressLabel.Text = `Lvl {level} > Max`
		self.Button.Active = false
		self.Button.Interactable = false
		self.ButtonsController:Unlink(self.Button)
		self.Button:RemoveTag("GuiButton")
		self:syncNotification()
		return
	end

	self.NextCost = nextLevel.UpgradeCost
	self.CostLabel.Text = `${NumberShortner(nextLevel.UpgradeCost)}`
	self.ProgressLabel.Text = `Lvl {level} > Lvl {level + 1}`
	self:syncNotification()
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

	-- The badge lives on an attachment next to the sign's SurfaceGui, inside the same part.
	local attachment = self.Gui.Parent:WaitForChild("PlotUpdateAttachment")
	self.Notification = attachment:WaitForChild("UpdPlotNotification") :: BillboardGui
	self.Notification.Enabled = false

	self:connect()
	self:sync(self.DataController:GetValue("BaseLevel"))

	self.DataController:GetValueChangedSignal("BaseLevel"):Connect(function(newLevel: number)
		self:sync(newLevel)
	end)

	self.DataController:GetValueChangedSignal("Cash"):Connect(function()
		self:syncNotification()
	end)
end

return BaseUpgradeButton
