-- Roblox Services
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Packages
local knit = require(ReplicatedStorage.src.Packages.knit)

-- Utility Modules
local Spring = require(ReplicatedStorage.src.utility.Spring)

-- Constants
local _tweenInfo = TweenInfo.new(0.15, Enum.EasingStyle.Linear, Enum.EasingDirection.Out)

-->
local RightButtons = {
	Visible = true,
}

-- Private Methods
function RightButtons:toggleVisibility(visible: boolean)
	self.Visible = visible
	self.VisibilityRevision = (self.VisibilityRevision or 0) + 1
	local revision = self.VisibilityRevision
	if visible then
		self.Frame.Visible = true
	end

	Spring.target(self.Frame, 0.75, 6, {
		Position = self.Frame:GetAttribute(visible and "VisiblePosition" or "HiddenPosition"),
	})

	Spring.completed(self.Frame, function()
		if self.VisibilityRevision == revision and not self.Visible then
			self.Frame.Visible = false
		end
	end)
end

-- LifeCycle
function RightButtons:Init(player: Player)
	self.Frame = player.PlayerGui:WaitForChild("Hud"):WaitForChild("RightMain"):WaitForChild("Right")
	local hudController = knit.GetController("HudController")
	self:toggleVisibility(hudController:AreRightButtonsVisible())

	hudController.Signals.ToggleRightButtonsVisibility:Connect(function(visible: boolean?)
		self:toggleVisibility(if visible == nil then not self.Visible else visible)
	end)
end

return RightButtons
