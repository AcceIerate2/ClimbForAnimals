-- Roblox Services
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Packages
local knit = require(ReplicatedStorage.src.Packages.knit)

-- Utility Modules
local NumberShortner = require(ReplicatedStorage.src.utility.NumberShortner)

-- Constants
local PanelName = "OfflineEarnings"

-->
local OfflineCashController = knit.CreateController({
	Name = "OfflineCashController",
	Claiming = false,
	Claimed = false,
})

-- Public Methods
function OfflineCashController:GetPendingCash(): number
	return self.DataController:GetValue("PendingOfflineCash")
end

function OfflineCashController:Claim()
	if self.Claiming or self.Claimed then
		return
	end

	self.Claiming = true
	self.CashFlowService
		:ClaimOfflineCash()
		:andThen(function(response)
			if response.Status then
				self.Claimed = true
			end

			if response.Status and self.PanelController.ActivePanel == PanelName then
				self.PanelController:TogglePanel(PanelName)
			end

			self.NotificationController:Push({
				Message = response.Status and `Claimed ${NumberShortner(response.Amount)} offline cash!`
					or response.Reason,
				Color = response.Status and Color3.fromRGB(115, 255, 0) or Color3.fromRGB(255, 0, 0),
				Sound = response.Status and "Generic" or "Decline",
			})
		end)
		:catch(function(message)
			warn(message)
			self.NotificationController:Push({
				Message = "Couldn't claim offline cash. Please try again.",
				Color = Color3.fromRGB(255, 0, 0),
				Sound = "Decline",
			})
		end)
		:finally(function()
			self.Claiming = false
		end)
end

-- LifeCycle
function OfflineCashController:KnitInit()
	self.CashFlowService = knit.GetService("CashFlowService")
	self.DataController = knit.GetController("DataController")
	self.NotificationController = knit.GetController("NotificationController")
	self.PanelController = knit.GetController("PanelController")
end

function OfflineCashController:KnitStart()
	-- Buttons bind the panel toggle signal after Knit starts.
	Players.LocalPlayer:WaitForChild("ClientReady")

	local panel = Players.LocalPlayer.PlayerGui:WaitForChild("Panels"):WaitForChild(PanelName)
	local visibilityConnection = panel:GetPropertyChangedSignal("Visible"):Connect(function()
		if not panel.Visible and not self.Claimed and not self.Claiming and self:GetPendingCash() > 0 then
			self:Claim()
		end
	end)

	panel.Destroying:Once(function()
		visibilityConnection:Disconnect()
	end)

	local function showPendingCash(amount: number)
		if amount > 0 and self.PanelController.ActivePanel ~= PanelName then
			self.PanelController:TogglePanel(PanelName)
		end
	end

	self.DataController:GetValueChangedSignal("PendingOfflineCash"):Connect(showPendingCash)
	showPendingCash(self:GetPendingCash())
end

return OfflineCashController
