-- Roblox Services
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

-- Packages
local knit = require(ReplicatedStorage.src.Packages.knit)

-- Utility Modules
local PlayTween = require(ReplicatedStorage.src.utility.PlayTween)

-- Modules
local OverlayFrame = require(script.OverlayFrame)

-- Constants
local Player = Players.LocalPlayer
local TweenConfig = TweenInfo.new(0.15)

-->
local PaymentProcessingOverlay = {
	Revision = 0,
}

-- Private Methods
function PaymentProcessingOverlay:toggleVisibility(visible: boolean)
	self.Revision += 1
	local revision = self.Revision

	if self.Tween then
		local tween = self.Tween
		self.Tween = nil
		tween:Cancel()
	end

	if visible and not self.ActiveFrame then
		local frame = OverlayFrame(self.PlayerGui)
		self.ActiveFrame = frame
		self.SpinConnection = RunService.RenderStepped:Connect(function(deltaTime: number)
			frame.Container.spinningIcon.Rotation += 50 * deltaTime
		end)
	end

	local frame = self.ActiveFrame
	if not frame then
		return
	end

	self.Tween = PlayTween(frame.Container, TweenConfig, {
		GroupTransparency = visible and 0 or 1,
	}, function()
		-- Cancelled fades must not clear a newer tween or destroy a reopened overlay.
		if self.Revision ~= revision then
			return
		end

		self.Tween = nil
		if not visible then
			self.SpinConnection:Disconnect()
			self.SpinConnection = nil
			self.ActiveFrame = nil
			frame:Destroy()
		end
	end)
end

-- LifeCycle
function PaymentProcessingOverlay:Init()
	if self.StateConnection then
		return
	end

	self.PlayerGui = Player:WaitForChild("PlayerGui")
	self.MonetizationController = knit.GetController("MonetizationController")
	self.StateConnection = self.MonetizationController.PurchaseProcessingChanged:Connect(function(isProcessing: boolean)
		self:toggleVisibility(isProcessing)
	end)
	self:toggleVisibility(self.MonetizationController.PromptActive)
end

return PaymentProcessingOverlay
