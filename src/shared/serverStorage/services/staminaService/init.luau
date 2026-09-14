-- Roblox Services
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

-- Packages
local knit = require(ReplicatedStorage.src.Packages.knit)

-- Helper Functions
local function clearConnections(connectionsTable: { RBXScriptConnection })
	for _, connection: RBXScriptConnection in pairs(connectionsTable or {}) do
		if typeof(connection) == "RBXScriptConnection" then
			connection:Disconnect()
		end
	end
	table.clear(connectionsTable or {})
end

-->
local StaminaService = knit.CreateService({
	Name = "StaminaService",
	Client = {
		DisableAutoClimb = knit.CreateSignal(),
		UpdateStamina = knit.CreateSignal(),
		ToggleVisibility = knit.CreateSignal(),
	},

	Connections = {},
	StaminaConnections = {},
	StaminaValues = {},
})

-- Private Methods
-- Public Methods
function StaminaService:Connect(player: Player, character: any)
	self.Connections[player] = {}
	self.StaminaConnections[player] = {}

	local humanoid = character:FindFirstChildOfClass("Humanoid") :: Humanoid
	local humanoidRootPart = character:FindFirstChild("HumanoidRootPart") :: BasePart

	table.insert(
		self.Connections[player],
		humanoid.StateChanged:Connect(function(oldState: Enum.HumanoidStateType, newState: Enum.HumanoidStateType)
			if newState == Enum.HumanoidStateType.Climbing then
				if self.StaminaValues[player] then
					return
				end

				self.StaminaValues[player] = self.DataService:GetValue(player, "MaxStamina")

				self.Client.ToggleVisibility:Fire(player, true)
				self.Client.UpdateStamina:Fire(player, self.StaminaValues[player])

				local elapsed = 0

				table.insert(
					self.StaminaConnections[player],
					RunService.Heartbeat:Connect(function(deltaTime: number)
						elapsed += deltaTime
						if elapsed < 1 then
							return
						end

						elapsed = 0

						local isClimbing = humanoid.MoveDirection.Magnitude > 0
						self.StaminaValues[player] -= isClimbing and 1 or 0

						if isClimbing then
							self.Client.UpdateStamina:Fire(player, self.StaminaValues[player])
						end

						if self.StaminaValues[player] <= 0 then
							self:Disconnect(player)
							self.Client.ToggleVisibility:Fire(player, false)
						end
					end)
				)
			else
				self:Disconnect(player)
				self.Client.ToggleVisibility:Fire(player, false)
			end
		end)
	)
end

function StaminaService:Disconnect(player: Player)
	clearConnections(self.StaminaConnections[player])
	self.StaminaValues[player] = nil
end

function StaminaService:ClearReferences(player: Player)
	self:Disconnect(player)
	clearConnections(self.Connections[player])

	self.Connections[player] = nil
	self.StaminaConnections[player] = nil
end

-- LifeCycle
function StaminaService:KnitInit()
	self.PlayerService = knit.GetService("PlayerService")
	self.DataService = knit.GetService("DataService")
end

function StaminaService:KnitStart()
	self.PlayerService.CharacterReset:Connect(function(player: Player, newCharacter: any)
		self:Disconnect(player)
		self:Connect(player, newCharacter)
	end)
end

return StaminaService
