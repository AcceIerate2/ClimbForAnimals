-- Roblox Services
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Packages
local knit = require(ReplicatedStorage.src.Packages.knit)

-- Utility
local Spring = require(ReplicatedStorage.src.utility.Spring)

-- Constants
local _tweenInfo = TweenInfo.new(0.15, Enum.EasingStyle.Linear, Enum.EasingDirection.Out)

-->
local Eggs = {}

-- Private Methods
function Eggs:toggleVisibility(visible: boolean)
	if visible then
		self.Frame.Position = self.Frame:GetAttribute("HiddenPosition")
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
function Eggs:Init(player: Player)
	self.Frame = player.PlayerGui:WaitForChild("General"):WaitForChild("Eggs")
	self:toggleVisibility(false)
	knit.GetController("EggController").Signals.ToggleVisibility:Connect(function(visible: boolean)
		self:toggleVisibility(visible)
	end)
end

return Eggs
