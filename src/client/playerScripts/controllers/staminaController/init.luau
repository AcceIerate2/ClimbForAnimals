-- Roblox Services
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

-- Packages
local Signal = require(ReplicatedStorage.src.Packages.Signal)
local knit = require(ReplicatedStorage.src.Packages.knit)

-- Constants
local Player = Players.LocalPlayer

-->
local StaminaController = knit.CreateController({
	Name = "StaminaController",
	Signals = {
		ToggleVisibility = Signal.new(),
		UpdateStamina = Signal.new(),
	},
	Connections = {},
})

-- Private Methods
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
	local character = Player.Character
	local humanoid = character:WaitForChild("Humanoid") :: Humanoid

	self.Signals.ToggleVisibility:Fire(true)
	self.Signals.UpdateStamina:Fire(self.Stamina)

	local elapsed = 0
	table.insert(
		self.Connections,
		RunService.RenderStepped:Connect(function(deltaTime: number)
			elapsed += deltaTime
			if elapsed < 1 then
				return
			end

			elapsed = 0

			local isMoving = math.abs(humanoid.MoveDirection.Magnitude) > 0
			self.Stamina = math.round(
				math.clamp(
					self.Stamina - (isMoving and (1 * (self.SpeedStateController:GetWalkSpeed() / 26))) or 0,
					0,
					math.huge
				)
			)

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
end

function StaminaController:KnitStart()
	self.Stamina = self.DataController:GetValue("MaxStamina")
	self.SpeedStateController.Signals.StateChanged:Connect(function(data: { NewState: string })
		if data.NewState == "Climbing" then
			self:connect()
		else
			self.Stamina = self.DataController:GetValue("MaxStamina")
			self:disconnect()
		end
	end)
end

return StaminaController
