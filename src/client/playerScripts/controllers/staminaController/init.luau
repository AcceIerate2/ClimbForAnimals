-- Roblox Services
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

-- Packages
local Signal = require(ReplicatedStorage.src.Packages.Signal)
local knit = require(ReplicatedStorage.src.Packages.knit)

-- Config Modules
local staminaConfig = require(ReplicatedStorage.src.GameConfiguration.Gameplay.staminaConfig)
local staminaUpgradeConfig = require(ReplicatedStorage.src.GameConfiguration.Economy.staminaUpgradeConfig)

-->
local MaxClimbStepPerFrame = 50

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

function StaminaController:GetMaxStamina(): number
	return staminaUpgradeConfig.GetMaxStamina(self.DataController:GetValue("StaminaLevel"))
end

function StaminaController:getConsumptionRate()
	return self.DataController:GetValue("StaminaConsumptionRate")
end

function StaminaController:updateStamina()
	self.Stamina = math.max(self.Stamina - staminaConfig.BaseConsumptionAmount, 0)
end

function StaminaController:getStaminaPercent()
	return (self.Stamina / self:GetMaxStamina()) * 100
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
	local rootPart = character:WaitForChild("HumanoidRootPart") :: BasePart

	self.Signals.ToggleVisibility:Fire(true)
	self.Signals.UpdateStamina:Fire(self.Stamina)

	local lastHeight = rootPart.Position.Y
	local climbed = 0

	table.insert(
		self.Connections,
		RunService.RenderStepped:Connect(function(deltaTime: number)
			local isMoving = self.ClimbController:IsMoving()
			local height = rootPart.Position.Y
			local rise = height - lastHeight
			lastHeight = height

			if isMoving and not self.ClimbController.Boosting and rise > 0 and rise <= MaxClimbStepPerFrame then
				climbed += rise
				local studsPerPoint = self:getConsumptionRate()
				local drained = false
				while climbed >= studsPerPoint and self.Stamina > 0 do
					climbed -= studsPerPoint
					self:updateStamina()
					drained = true
				end
				if drained then
					self.Signals.UpdateStamina:Fire(self.Stamina)
				end
			end

			local percent = self:getStaminaPercent()
			if percent <= staminaConfig.SlowdownThresholdPercent then
				-- Once per empty bar: climbing back on while still tired stays quiet until a refill.
				if not self.TiredNotified then
					self.TiredNotified = true
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
	self.Stamina = self:GetMaxStamina()
	self.TiredNotified = false
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

	-- Refill whenever the player stands in the lobby, however they got there (teleports included).
	RunService.Heartbeat:Connect(function()
		if self.Stamina >= self:GetMaxStamina() or self.ZoneController.Zone ~= "Lobby" then
			return
		end
		local character = Players.LocalPlayer.Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		if
			humanoid
			and humanoid.FloorMaterial ~= Enum.Material.Air
			and self.SpeedStateController.State ~= "Climbing"
		then
			self:Reset()
		end
	end)

	self.DataController:GetValueChangedSignal("StaminaLevel"):Connect(function()
		local max = self:GetMaxStamina()
		if self.LastMax and self.LastMax > 0 and max ~= self.LastMax then
			-- Buying a level keeps the bar where it is instead of dropping the fill.
			self.Stamina = math.clamp(self.Stamina / self.LastMax * max, 0, max)
		end
		self.LastMax = max
		self.Signals.UpdateStamina:Fire(self.Stamina)
	end)
	self.LastMax = self:GetMaxStamina()

	self.SpeedStateController.Signals.StateChanged:Connect(function(data: { NewState: string, WalkSpeed: number })
		if data.NewState == "Climbing" then
			self:connect()
		else
			self:disconnect()
		end
	end)
end

return StaminaController
