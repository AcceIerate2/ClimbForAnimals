-- Roblox Services
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Packages
local Signal = require(ReplicatedStorage.src.Packages.Signal)
local knit = require(ReplicatedStorage.src.Packages.knit)

-- Constants
local Player = Players.LocalPlayer

-->
local SpeedStateController = knit.CreateController({
	Name = "SpeedStateController",
	Signals = {
		StateChanged = Signal.new(),
	},

	StateFunctions = {
		Climbing = function()
			return knit.GetController("DataController"):GetValue("Speed")
				* knit.GetController("StaminaController").Multiplier
		end,

		Idle = function()
			return 26
		end,

		Stealing = function()
			return 10
		end,

		Treadmill = function()
			return 0
		end,
	},
})

-- Private Methods
function SpeedStateController:updateWalkSpeed()
	local character = Player.Character
	if not character then
		return
	end

	local humanoid = character:FindFirstChildOfClass("Humanoid") or character:WaitForChild("Humanoid", 3)
	if not humanoid then
		return
	end

	humanoid.WalkSpeed = self:GetWalkSpeed()
end

-- Public Methods
function SpeedStateController:GetWalkSpeed()
	return self.StateFunctions[self.State]()
end

function SpeedStateController:UpdateState(newState: string)
	self.State = newState
	self:updateWalkSpeed()
	self.Signals.StateChanged:Fire({
		NewState = newState,
		WalkSpeed = self:GetWalkSpeed(),
	})
end

-- LifeCycle
function SpeedStateController:KnitInit()
	self.DataController = knit.GetController("DataController")
end

function SpeedStateController:KnitStart()
	self:UpdateState("Idle")
	self:updateWalkSpeed()
end

return SpeedStateController
