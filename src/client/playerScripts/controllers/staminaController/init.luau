-- Roblox Services
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

-- Packages
local Signal = require(ReplicatedStorage.src.Packages.Signal)
local knit = require(ReplicatedStorage.src.Packages.knit)

-- Utility Modules
local PlayTween = require(ReplicatedStorage.src.utility.PlayTween)

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
function StaminaController:getConsumptionRate()
	return self.DataController:GetValue("StaminaConsumptionRate")
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
	local playedAnimation = false
	local elapsed = 0
	table.insert(
		self.Connections,
		RunService.RenderStepped:Connect(function(deltaTime: number)
			elapsed += deltaTime
			if elapsed < self:getConsumptionRate() then
				return
			end

			elapsed = 0

			local isMoving = self.ClimbController:IsMoving()
			self.Stamina = math.round(
				math.clamp(self.Stamina - (isMoving and staminaConfig.BaseConsumptionRate or 0), 0, math.huge)
			)

			local percent = (self.Stamina / staminaConfig.MaxStamina) * 100
			if percent <= 15 then
				if not pushedNotification then
					pushedNotification = true
					self.NotificationController:Push({
						Message = "You are getting tired!",
						Color = Color3.fromRGB(255, 255, 255),
						Sound = "Generic",
					})
				end

				if not playedAnimation then
					playedAnimation = true
					PlayTween(humanoid, TweenInfo.new(5), {
						WalkSpeed = 16,
					})

					local connection
					connection = humanoid:GetPropertyChangedSignal("WalkSpeed"):Connect(function()
						self.AnimationController:UpdateTrackState("Climb", "AdjustSpeed", { humanoid.WalkSpeed / 16 })

						self.AnimationController:UpdateTrackState(
							"RightClimb",
							"AdjustSpeed",
							{ humanoid.WalkSpeed / 16 }
						)

						self.AnimationController:UpdateTrackState(
							"LeftClimb",
							"AdjustSpeed",
							{ humanoid.WalkSpeed / 16 }
						)

						if humanoid.WalkSpeed == 16 then
							connection:Disconnect()
							connection = nil
							return
						end
					end)
				end

				self.Multiplier = 16 / self.SpeedStateController:GetWalkSpeed()
			end

			if isMoving then
				self.Signals.UpdateStamina:Fire(self.Stamina)
			end
		end)
	)
end

-- LifeCycle
function StaminaController:KnitInit()
	self.SpeedStateController = knit.GetController("SpeedStateController")
	self.DataController = knit.GetController("DataController")
	self.ClimbController = knit.GetController("ClimbController")
	self.NotificationController = knit.GetController("NotificationController")
	self.AnimationController = knit.GetController("AnimationController")
end

function StaminaController:KnitStart()
	self.Stamina = staminaConfig.MaxStamina
	self.SpeedStateController.Signals.StateChanged:Connect(function(data: { NewState: string, WalkSpeed: number })
		if data.NewState == "Climbing" then
			self:connect()
		else
			self:disconnect()
			self.Stamina = staminaConfig.MaxStamina
			self.Multiplier = 1
		end
	end)
end

return StaminaController
