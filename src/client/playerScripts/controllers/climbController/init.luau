-- Roblox Services
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

-- Packages
local knit = require(ReplicatedStorage.src.Packages.knit)
local promise = require(ReplicatedStorage.src.Packages.promise)
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
local function highlight(parent)
	return InstanceCreator("Highlight", "Highlight", parent, {
		FillTransparency = 0.125,
		FillColor = Color3.fromRGB(255, 255, 255),
		OutlineTransparency = 1,
	})
end

-->
local ClimbController = knit.CreateController({
	Name = "ClimbController",
	Connections = {},
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

function ClimbController:updateAnimation(movementState: string)
	if self.MovementState == movementState then
		return
	end

	self.MovementState = movementState

	local animationData = ClimbAnimations[movementState]
	local animationName = animationData.Name
	local animationSpeed = (self.DataController:GetValue("Speed") * animationData.Speed) / 16

	if not self.AnimationController:IsPlaying(animationName) then
		self.AnimationController:Play(animationName, true, { 0.1, 1, animationSpeed })
		return
	end

	self.AnimationController:UpdateTrackState(animationName, "AdjustSpeed", { animationSpeed })
end

function ClimbController:boost(humanoid: Humanoid)
	local humanoidRootPart = humanoid.Parent and humanoid.Parent:FindFirstChild("HumanoidRootPart")
	return promise.new(function(resolve, reject, onCancel)
		self.AudioController:PlaySound("Boost", {
			PlayOver = false,
		})

		self.AnimationController:Play("Climb")
		MoveAction.Enabled = false

		local lastWalkSpeed = humanoid.WalkSpeed
		humanoid.WalkSpeed = 50

		local highlight = highlight(humanoid.Parent)
		PlayTween(highlight, TweenInfo.new(3), {
			FillTransparency = 3,
		}, function()
			highlight:Destroy()
		end)

		local finalPosition = humanoidRootPart
		humanoid:MoveTo(workspace.ClimbRelativePart.CFrame.Position + Vector3.new(0, 20, 0))
		humanoid.MoveToFinished:Once(function()
			MoveAction.Enabled = true
			resolve()
		end)
	end)
end

function ClimbController:connect(character: Model)
	local climbRelativePart = workspace.ClimbRelativePart
	local humanoidRootPart = character:WaitForChild("HumanoidRootPart") :: BasePart
	local humanoid = character:WaitForChild("Humanoid") :: Humanoid

	humanoidRootPart.Orientation = climbRelativePart.Orientation

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
			self:updateAnimation(movementState)

			Player:Move(Vector3.new(0, 0, -vertical), true)
			if right == 0 then
				return
			end

			humanoidRootPart.CFrame += climbRelativePart.CFrame.RightVector * right * humanoid.WalkSpeed * deltaTime
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

function ClimbController:listenToCharacterAdded()
	local localConnections = {}

	local function disconnect()
		for _, connection in pairs(localConnections) do
			if typeof(connection) == "RBXScriptConnection" then
				connection:Disconnect()
			end
		end

		table.clear(localConnections)
	end

	local function connect(character: Model)
		local humanoid = character:FindFirstChildOfClass("Humanoid") :: Humanoid
		if not humanoid then
			return
		end

		table.insert(
			localConnections,
			humanoid.StateChanged:Connect(function(old: Enum.HumanoidStateType, new: Enum.HumanoidStateType)
				local isClimbing = new == Enum.HumanoidStateType.Climbing
				local wasClimbing = old == Enum.HumanoidStateType.Climbing

				if isClimbing then
					self.SpeedStateController:UpdateState("Climbing")
					self:disableDefaultClimbingAnimation(humanoid)

					self:boost(humanoid):andThen(function()
						self:connect(character)
					end)
				elseif wasClimbing then
					self.SpeedStateController:UpdateState("Idle")
					self:disconnect()
				end
			end)
		)
	end

	if Player.Character then
		connect(Player.Character)
	end

	Player.CharacterAdded:Connect(function(newCharacter: Model)
		self:disconnect()
		disconnect()
		connect(newCharacter)
	end)
end

-- LifeCycle
function ClimbController:KnitInit()
	self.AnimationController = knit.GetController("AnimationController")
	self.DataController = knit.GetController("DataController")
	self.SpeedStateController = knit.GetController("SpeedStateController")
	self.AudioController = knit.GetController("AudioController")
end

function ClimbController:KnitStart()
	self:listenToCharacterAdded()
end

return ClimbController
