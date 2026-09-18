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
	if visible then
		self.Frame.Visible = true
	end

	Spring.target(self.Frame, 0.75, 6, {
		Position = self.Frame:GetAttribute(visible and "VisiblePosition" or "HiddenPosition"),
	})

	Spring.completed(self.Frame, function()
		if not visible then
			self.Frame.Visible = false
		end
	end)
end

-- LifeCycle
function RightButtons:Init(player: Player)
	self.Frame = player.PlayerGui:WaitForChild("Hud"):WaitForChild("RightMain"):WaitForChild("Right")
	self:toggleVisibility(true)

	knit.GetController("HudController").Signals.ToggleRightButtonsVisibility:Connect(function()
		self:toggleVisibility(not self.Visible)
		self.Visible = not self.Visible
	end)
end

return RightButtons
