-- Roblox Services
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

-- Packages
local knit = require(ReplicatedStorage.src.Packages.knit)
local promise = require(ReplicatedStorage.src.Packages.promise)

-- Utility Modules
local CollisionHandler = require(ReplicatedStorage.src.utility.CollisionHandler)

-- Modules
local BoostMotion = require(script.boostMotion)

-- Constants
local Player = Players.LocalPlayer
local PlayerModule = game.StarterPlayer:WaitForChild("PlayerModule")
local InputContexts = PlayerModule:WaitForChild("InputContexts")
local CharacterContext = InputContexts:WaitForChild("CharacterContext")
local MoveAction = CharacterContext:WaitForChild("MoveAction") :: InputAction
local BoostGroundHeightTolerance = 6 -- Root height above the climb start while grounded.
local BoostEntryHeightTolerance = 16 -- Allows jumping onto the bottom of the ladder.
local BoostHeight = 125 -- Total upward boost distance, including slowdown.
local BoostSpeedMultiplier = 15
local BoostTimeout = 8
local BoostSlowdownDuration = 1.2
local BoostControlReleaseProgress = 0.5 -- Unlock halfway through slowdown.
local BoostFovIncrease = 10
local ClimbSpeedMultiplier = 0.7
local BoostCooldown = 0.5 -- Seconds between boost starts, including cancelled boosts.
local BoostSpeedLimit = 100000 -- Saved Speed must be below this value.
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
	NextBoostAt = 0,
})

-- Private Methods
function ClimbController:disconnect()
	if self.StopBoost then
		self.StopBoost(false)
	end

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
	return promise.new(function(resolve, _reject, onCancel)
		local speed = self.DataController:GetValue("Speed")
		if
			not humanoidRootPart
			or humanoid.Health <= 0
			or BoostHeight <= 0
			or self.Boosting
			or os.clock() < self.NextBoostAt
			or speed >= BoostSpeedLimit
			or humanoid:GetState() ~= Enum.HumanoidStateType.Climbing
		then
			resolve(false)
			return
		end

		self.NextBoostAt = os.clock() + BoostCooldown
		local startHeight = humanoidRootPart.Position.Y
		local motion = BoostMotion.Create(
			BoostHeight,
			self.SpeedStateController:GetWalkSpeed() * ClimbSpeedMultiplier,
			BoostSpeedMultiplier,
			BoostSlowdownDuration
		)
		local jumpEnabled = humanoid:GetStateEnabled(Enum.HumanoidStateType.Jumping)
		local autoRotate = humanoid.AutoRotate
		local camera = workspace.CurrentCamera
		local originalFov = camera and camera.FieldOfView
		local useFov = camera ~= nil and self.PanelController.ActivePanel == nil
		self.CameraController.BoostFovActive = useFov
		if useFov then
			self.CameraController:UpdateFov(originalFov + BoostFovIncrease)
		end

		local attachment = Instance.new("Attachment")
		attachment.Name = "ClimbBoostAttachment"
		attachment.Parent = humanoidRootPart

		local velocity = Instance.new("LinearVelocity")
		velocity.Name = "ClimbBoostVelocity"
		velocity.Attachment0 = attachment
		velocity.RelativeTo = Enum.ActuatorRelativeTo.World
		velocity.VelocityConstraintMode = Enum.VelocityConstraintMode.Vector
		velocity.ForceLimitsEnabled = false
		velocity.VectorVelocity = Vector3.zero
		velocity.Parent = humanoidRootPart

		local highlight = Instance.new("Highlight")
		highlight.Name = "ClimbBoostHighlight"
		highlight.Adornee = humanoid.Parent
		highlight.FillColor = Color3.new(1, 1, 1)
		highlight.FillTransparency = 0.25
		highlight.OutlineTransparency = 1
		highlight.DepthMode = Enum.HighlightDepthMode.Occluded
		highlight.Parent = humanoid.Parent

		self.Boosting = true
		self.BoostControlsLocked = true
		humanoid.AutoRotate = false
		humanoid.Jump = false
		humanoid:SetStateEnabled(Enum.HumanoidStateType.Jumping, false)

		local connection
		local finished = false
		local controlsReleased = false
		local function finish(completed: boolean)
			if finished then
				return
			end
			finished = true
			if connection then
				connection:Disconnect()
			end
			self.Boosting = false
			self.BoostControlsLocked = false
			self.StopBoost = nil
			highlight:Destroy()
			velocity:Destroy()
			attachment:Destroy()
			if humanoidRootPart.Parent and (completed or not controlsReleased) then
				local input = MoveAction:GetState() :: Vector2
				local vertical = math.abs(input.Y) < 0.05 and 0 or math.clamp(input.Y, -1, 1)
				local exitSpeed = completed
						and self.SpeedStateController:GetWalkSpeed() * ClimbSpeedMultiplier * vertical
					or 0
				local currentVelocity = humanoidRootPart.AssemblyLinearVelocity
				humanoidRootPart.AssemblyLinearVelocity = Vector3.new(currentVelocity.X, exitSpeed, currentVelocity.Z)
			end
			self.CameraController.BoostFovActive = false
			if useFov and workspace.CurrentCamera == camera and not self.PanelController.ActivePanel then
				self.CameraController:UpdateFov(originalFov)
			end

			if humanoid.Parent then
				humanoid.WalkSpeed = self.SpeedStateController:GetWalkSpeed()
				if not controlsReleased then
					humanoid.Jump = false
				end
				humanoid:SetStateEnabled(Enum.HumanoidStateType.Jumping, jumpEnabled)
				humanoid.AutoRotate = autoRotate
			end
			resolve(completed)
		end

		self.StopBoost = finish
		onCancel(function()
			finish(false)
		end)

		local elapsed = 0
		connection = RunService.PreSimulation:Connect(function(deltaTime: number)
			if
				not humanoidRootPart.Parent
				or humanoid.Health <= 0
				or humanoid:GetState() ~= Enum.HumanoidStateType.Climbing
			then
				finish(false)
				return
			end

			local remainingHeight = math.max(0, startHeight + BoostHeight - humanoidRootPart.Position.Y)
			if elapsed >= motion.Duration or remainingHeight <= 0 then
				finish(true)
				return
			end
			if elapsed >= BoostTimeout then
				finish(false)
				return
			end
			if deltaTime <= 0 then
				return
			end

			local nextElapsed = math.min(elapsed + deltaTime, motion.Duration)
			local progress = BoostMotion.Progress(motion, elapsed)
			-- Smoothstep eases both ends instead of braking hardest on the first frame.
			local strength = 1 - progress * progress * (3 - 2 * progress)
			if useFov then
				if self.PanelController.ActivePanel or workspace.CurrentCamera ~= camera then
					useFov = false
					self.CameraController.BoostFovActive = false
				else
					self.CameraController:UpdateFov(originalFov + BoostFovIncrease * strength)
				end
			end

			highlight.FillTransparency = 1 - 0.75 * strength

			local distance = BoostMotion.Distance(motion, nextElapsed) - BoostMotion.Distance(motion, elapsed)
			local boostSpeed = math.min(distance, remainingHeight) / deltaTime
			if not controlsReleased and progress >= BoostControlReleaseProgress then
				controlsReleased = true
				self.BoostControlsLocked = false
				humanoid:SetStateEnabled(Enum.HumanoidStateType.Jumping, jumpEnabled)
				humanoid.AutoRotate = autoRotate
				-- Keep the remaining boost vertical, leaving sideways movement free.
				velocity.LineDirection = Vector3.yAxis
				velocity.VelocityConstraintMode = Enum.VelocityConstraintMode.Line
			end

			if controlsReleased then
				local moveDirection = MoveAction:GetState() :: Vector2
				local vertical = math.abs(moveDirection.Y) < 0.05 and 0 or math.clamp(moveDirection.Y, -1, 1)
				local handoff = math.clamp(
					(progress - BoostControlReleaseProgress) / math.max(1 - BoostControlReleaseProgress, 0.001),
					0,
					1
				)
				handoff = handoff * handoff * (3 - 2 * handoff)
				velocity.LineVelocity = boostSpeed * (1 + (vertical - 1) * handoff)
			else
				velocity.VectorVelocity = Vector3.new(0, boostSpeed, 0)
				humanoid.Jump = false
				Player:Move(humanoidRootPart.CFrame.LookVector, false)
			end

			elapsed += deltaTime
		end)

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
			if self.BoostControlsLocked and movementState == "Idle" then
				movementState = "Vertical"
			end
			self:updateAnimation(movementState, humanoid)

			if self.BoostControlsLocked then
				Player:Move(humanoidRootPart.CFrame.LookVector, false)
				return
			end

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
		local root = character:WaitForChild("HumanoidRootPart")
		local boostArmed = false

		local function updateBoostReady()
			local height = root.Position.Y - self.ZoneController:GetClimbStartHeight()
			if self.ZoneController.Zone ~= "Lobby" or height > BoostEntryHeightTolerance then
				boostArmed = false
			elseif
				humanoid.Health > 0
				and humanoid:GetState() == Enum.HumanoidStateType.Running
				and humanoid.FloorMaterial ~= Enum.Material.Air
				and height <= BoostGroundHeightTolerance
				and not self.Boosting
			then
				boostArmed = true
			end
		end

		updateBoostReady()
		table.insert(self.CharacterConnections, RunService.Heartbeat:Connect(updateBoostReady))

		table.insert(
			self.CharacterConnections,
			humanoid.StateChanged:Connect(function(old: Enum.HumanoidStateType, new: Enum.HumanoidStateType)
				local isClimbing = new == Enum.HumanoidStateType.Climbing
				local wasClimbing = old == Enum.HumanoidStateType.Climbing

				if isClimbing then
					local root = character:FindFirstChild("HumanoidRootPart")
					-- A jump from the lobby can reach the ladder while rising or falling.
					-- boostArmed records the grounded start and is consumed on first contact.
					local canEnterBoost = old == Enum.HumanoidStateType.Running
						or old == Enum.HumanoidStateType.Jumping
						or old == Enum.HumanoidStateType.Freefall
					local shouldBoost = boostArmed
						and canEnterBoost
						and self.ZoneController.Zone == "Lobby"
						and self.SpeedStateController.State == "Idle"
						and root ~= nil
						and root.Position.Y <= self.ZoneController:GetClimbStartHeight() + BoostEntryHeightTolerance

					-- Only returning to the ground at the bottom rearms the next climb.
					boostArmed = false

					-- Only collides with the InvisibleWalls while climbing
					CollisionHandler.SetInstanceOrGroup(character, "ClimbingCollisions")
					self.SpeedStateController:UpdateState("Climbing")
					self:disableDefaultClimbingAnimation(humanoid)
					self:connect(character)
					if shouldBoost then
						self:boost(humanoid):catch(warn)
					end
				elseif wasClimbing then
					CollisionHandler.SetInstanceOrGroup(character, "PlayerCollisions")
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
	self.CameraController = knit.GetController("CameraController")
	self.PanelController = knit.GetController("PanelController")
	self:listenToCharacterController()
end

return ClimbController
