-- Roblox Services
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

-- Packages
local Signal = require(ReplicatedStorage.src.Packages.Signal)
local knit = require(ReplicatedStorage.src.Packages.knit)

-- Config Modules
local staminaConfig = require(ReplicatedStorage.src.GameConfiguration.Gameplay.staminaConfig)

-->
local StaminaController = knit.CreateController({
	Name = "StaminaController",

	Signals = {
		ToggleVisibility = Signal.new(),
		UpdateStamina = Signal.new(),
	},

	Connections = {},
	Multiplier = 1,
})

-- Private Methods
function StaminaController:pushTiredNotification()
	self.NotificationController:Push({
		Message = "You are getting tired!",
		Color = Color3.fromRGB(255, 255, 255),
		Sound = "Generic",
	})
end

function StaminaController:updateWalkSpeed(humanoid: Humanoid, percent: number, deltaTime: number)
	local alpha = 1 - math.clamp(percent / staminaConfig.SlowdownThresholdPercent, 0, 1)
	local startSpeed = self.SpeedStateController:GetWalkSpeed()
	local targetSpeed = startSpeed + (staminaConfig.MinimumWalkSpeed - startSpeed) * alpha
	local smoothing = staminaConfig.WalkSpeedSmoothing

	humanoid.WalkSpeed += (targetSpeed - humanoid.WalkSpeed) * math.clamp(smoothing * deltaTime, 0, 1)
	self.Multiplier = staminaConfig.MinimumWalkSpeed / self.SpeedStateController:GetWalkSpeed()
end

function StaminaController:updateClimbingAnimations(humanoid: Humanoid, isMoving: number)
	local newAnimationSpeed = isMoving and humanoid.WalkSpeed / staminaConfig.MinimumWalkSpeed or 0
	self.AnimationController:UpdateTrackState("Climb", "AdjustSpeed", { newAnimationSpeed })
	self.AnimationController:UpdateTrackState("RightClimb", "AdjustSpeed", { newAnimationSpeed })
	self.AnimationController:UpdateTrackState("LeftClimb", "AdjustSpeed", { newAnimationSpeed })
end

function StaminaController:getConsumptionRate()
	return self.DataController:GetValue("StaminaConsumptionRate")
end

function StaminaController:updateStamina(isMoving: boolean)
	self.Stamina =
		math.round(math.clamp(self.Stamina - (isMoving and staminaConfig.BaseConsumptionAmount or 0), 0, math.huge))
end

function StaminaController:getStaminaPercent()
	return (self.Stamina / staminaConfig.MaxStamina) * 100
end

function StaminaController:disconnect()
	for _, connection in pairs(self.Connections) do
		if typeof(connection) == "RBXScriptConnection" then
			connection:Disconnect()
		end
	end

	table.clear(self.Connections)
	self.Signals.ToggleVisibility:Fire(false)
end

function StaminaController:connect()
	local character = Players.LocalPlayer.Character
	local humanoid = character:WaitForChild("Humanoid") :: Humanoid

	self.Signals.ToggleVisibility:Fire(true)
	self.Signals.UpdateStamina:Fire(self.Stamina)

	local pushedNotification = false
	local elapsed = 0

	table.insert(
		self.Connections,
		RunService.RenderStepped:Connect(function(deltaTime: number)
			elapsed += deltaTime

			local isMoving = self.ClimbController:IsMoving()
			if elapsed >= self:getConsumptionRate() then
				elapsed = 0

				self:updateStamina(isMoving)

				if isMoving then
					self.Signals.UpdateStamina:Fire(self.Stamina)
				end
			end

			local percent = self:getStaminaPercent()
			if percent <= staminaConfig.SlowdownThresholdPercent then
				if not pushedNotification then
					pushedNotification = true
					self:pushTiredNotification()
				end

				self:updateWalkSpeed(humanoid, percent, deltaTime)
				self:updateClimbingAnimations(humanoid, isMoving)
			end
		end)
	)
end

-- Public Methods
function StaminaController:Reset()
	self.Stamina = staminaConfig.MaxStamina
	self.Multiplier = 1
end

-- LifeCycle
function StaminaController:KnitInit()
	self.SpeedStateController = knit.GetController("SpeedStateController")
	self.DataController = knit.GetController("DataController")
	self.ClimbController = knit.GetController("ClimbController")
	self.NotificationController = knit.GetController("NotificationController")
	self.AnimationController = knit.GetController("AnimationController")
	self.ZoneController = knit.GetController("ZoneController")
end

function StaminaController:KnitStart()
	self:Reset()

	self.SpeedStateController.Signals.StateChanged:Connect(function(data: { NewState: string, WalkSpeed: number })
		if data.NewState == "Climbing" then
			self:connect()
		else
			self:disconnect()
		end
	end)
end

return StaminaController
