-- Roblox Services
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

-- Packages
local knit = require(ReplicatedStorage.src.Packages.knit)
local promise = require(ReplicatedStorage.src.Packages.promise)

-- Utility Modules
local InstanceCreator = require(ReplicatedStorage.src.utility.InstanceCreator)
local PlayTween = require(ReplicatedStorage.src.utility.PlayTween)

-- Constants
local Player = Players.LocalPlayer
local PlayerModule = game.StarterPlayer:WaitForChild("PlayerModule")
local InputContexts = PlayerModule:WaitForChild("InputContexts")
local CharacterContext = InputContexts:WaitForChild("CharacterContext")
local MoveAction = CharacterContext:WaitForChild("MoveAction") :: InputAction
local ClimbAnimations = {
	Idle = {
		Name = "Climb",
		Speed = 0,
	},

	Vertical = {
		Name = "Climb",
		Speed = 1,
	},

	Right = {
		Name = "RightClimb",
		Speed = 1,
	},

	Left = {
		Name = "LeftClimb",
		Speed = 1,
	},
}

-- Helper Functions
local function clearCharacterVelocity(character: Model)
	local humanoidRootPart = character:FindFirstChild("HumanoidRootPart")
	if not humanoidRootPart then
		return
	end

	local velocity = humanoidRootPart.AssemblyLinearVelocity
	humanoidRootPart.AssemblyLinearVelocity = Vector3.new(velocity.X, 0, velocity.Z)
	humanoidRootPart.AssemblyAngularVelocity = Vector3.zero
end

local function alignToClimbFace(character: Model, humanoidRootPart: BasePart)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { character }

	local lookVector = humanoidRootPart.CFrame.LookVector
	local result =
		workspace:Blockcast(humanoidRootPart.CFrame - lookVector * 2, Vector3.new(2, 3, 1), lookVector * 5, params)
	if not result or not result.Instance:IsA("TrussPart") then
		return
	end

	local normal = Vector3.new(result.Normal.X, 0, result.Normal.Z).Unit
	local surfacePosition = result.Position
	local targetPosition = Vector3.new(surfacePosition.X, humanoidRootPart.Position.Y, surfacePosition.Z) + normal * 1

	humanoidRootPart.CFrame = CFrame.lookAt(targetPosition, targetPosition - normal, Vector3.yAxis)
	task.delay(0.125, function()
		if not humanoidRootPart.Parent then
			return
		end

		local orientation = humanoidRootPart.Orientation
		humanoidRootPart.Orientation = Vector3.new(orientation.X, math.round(orientation.Y / 90) * 90, orientation.Z)
	end)
end

-->
local ClimbController = knit.CreateController({
	Name = "ClimbController",
	Connections = {},
	CharacterConnections = {},
	MovementState = nil,
})

-- Private Methods
function ClimbController:disconnect()
	-- Disconnect Connections
	for _, connection: RBXScriptConnection in pairs(self.Connections) do
		if typeof(connection) == "RBXScriptConnection" then
			connection:Disconnect()
		end
	end
	table.clear(self.Connections)

	-- Stop/Clear Animation Related Stuff
	self.MovementState = nil
	self.AnimationController:Stop("Climb")
	self.AnimationController:Stop("LeftClimb")
	self.AnimationController:Stop("RightClimb")
end

function ClimbController:getMovementState(moveDirection: Vector2): string
	if math.abs(moveDirection.X) > 0.25 then
		return moveDirection.X > 0 and "Right" or "Left"
	end

	if math.abs(moveDirection.Y) > 0.05 then
		return "Vertical"
	end

	return "Idle"
end

function ClimbController:updateAnimation(movementState: string, humanoid: Humanoid)
	if self.MovementState == movementState then
		return
	end

	self.MovementState = movementState

	local animationData = ClimbAnimations[movementState]
	local animationName = animationData.Name
	local animationSpeed = (humanoid.WalkSpeed * animationData.Speed) / 16

	if not self.AnimationController:IsPlaying(animationName) then
		self.AnimationController:Play(animationName, true, { 0.1, 1, animationSpeed })
		return
	end

	self.AnimationController:UpdateTrackState(animationName, "AdjustSpeed", { animationSpeed })
end

function ClimbController:boost(humanoid: Humanoid)
	local humanoidRootPart = humanoid.Parent and humanoid.Parent:FindFirstChild("HumanoidRootPart")
	return promise.new(function(resolve, reject, onCancel)
		self.AudioController:PlaySfx("Boost", {
			PlayOver = false,
		})
	end)
end

function ClimbController:resetStamina()
	if self.ZoneController.Zone == "Lobby" then
		self.StaminaController:Reset()
	end
end

function ClimbController:connect(character: Model)
	local humanoidRootPart = character:WaitForChild("HumanoidRootPart") :: BasePart
	local humanoid = character:WaitForChild("Humanoid") :: Humanoid
	alignToClimbFace(character, humanoidRootPart)

	table.insert(
		self.Connections,
		RunService.RenderStepped:Connect(function(deltaTime: number)
			if humanoid:GetState() ~= Enum.HumanoidStateType.Climbing then
				return
			end

			local moveDirection = MoveAction:GetState() :: Vector2
			local right = math.abs(moveDirection.X) < 0.05 and 0 or math.clamp(moveDirection.X, -1, 1)
			local vertical = math.abs(moveDirection.Y) < 0.05 and 0 or math.clamp(moveDirection.Y, -1, 1)

			local movementState = self:getMovementState(moveDirection)
			self:updateAnimation(movementState, humanoid)

			Player:Move(Vector3.new(0, 0, -vertical), true)
			if right == 0 then
				return
			end

			local offset = humanoidRootPart.CFrame.RightVector
				* math.clamp(right * humanoid.WalkSpeed * deltaTime, -0.5, 0.5)
			humanoidRootPart.CFrame = humanoidRootPart.CFrame + offset
		end)
	)
end

function ClimbController:disableDefaultClimbingAnimation(humanoid: Humanoid)
	local animator = humanoid:FindFirstChildOfClass("Animator")
	if not animator then
		return
	end

	for _, track: AnimationTrack in animator:GetPlayingAnimationTracks() do
		track:Stop()
	end
end

function ClimbController:disconnectCharacter()
	self:disconnect()
	for _, connection in self.CharacterConnections do
		connection:Disconnect()
	end
	table.clear(self.CharacterConnections)
end

function ClimbController:listenToCharacterController()
	local function connect(character)
		local humanoid = character:WaitForChild("Humanoid")

		table.insert(
			self.CharacterConnections,
			humanoid.StateChanged:Connect(function(old: Enum.HumanoidStateType, new: Enum.HumanoidStateType)
				local isClimbing = new == Enum.HumanoidStateType.Climbing
				local wasClimbing = old == Enum.HumanoidStateType.Climbing

				if isClimbing then
					self.SpeedStateController:UpdateState("Climbing")
					self:disableDefaultClimbingAnimation(humanoid)
					self:connect(character)
				elseif wasClimbing then
					clearCharacterVelocity(character)
					self.SpeedStateController:UpdateState("Idle")
					self:disconnect()
					self:resetStamina()
				end
			end)
		)
	end

	self.CharacterController.CharacterAdded:Connect(function(character)
		self:disconnectCharacter()
		connect(character)
	end)

	self.CharacterController.CharacterRemoved:Connect(function()
		self:disconnectCharacter()
	end)
end

-- Public Methods
function ClimbController:IsMoving(): boolean
	return self.MovementState ~= nil and self.MovementState ~= "Idle"
end

-- LifeCycle
function ClimbController:KnitInit()
	self.AnimationController = knit.GetController("AnimationController")
	self.DataController = knit.GetController("DataController")
	self.SpeedStateController = knit.GetController("SpeedStateController")
	self.AudioController = knit.GetController("AudioController")
	self.CharacterController = knit.GetController("CharacterController")
	self.ZoneController = knit.GetController("ZoneController")
	self.StaminaController = knit.GetController("StaminaController")
	self:listenToCharacterController()
end

return ClimbController
