-- Roblox Services
local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")

-- Pacxkages
local Signal = require(ReplicatedStorage.src.Packages.Signal)
local knit = require(ReplicatedStorage.src.Packages.knit)

-- Utility Modules
local InstanceCreator = require(ReplicatedStorage.src.utility.InstanceCreator)
local PlayTween = require(ReplicatedStorage.src.utility.PlayTween)
local WaitForUiDesc = require(ReplicatedStorage.src.utility.WaitForUiDesc)
local particleEmitter = require(ReplicatedStorage.src.utility.particleEmitter)

-- Constants
local Player = Players.LocalPlayer
local AssetsFolder = ReplicatedStorage:WaitForChild("Assets")
local ImpactVfx = AssetsFolder:WaitForChild("Vfx"):WaitForChild("ImpactVfx")

local raycastParams = RaycastParams.new()
raycastParams.FilterType = Enum.RaycastFilterType.Exclude

local Camera = workspace.CurrentCamera
local FallingWindSfx = WaitForUiDesc(SoundService, "Sound", { Name = "FallingWind" })

-- Helper Functions
local function raycast(character: Model, distance: number)
	raycastParams.FilterDescendantsInstances = { character }
	return workspace:Raycast(character:GetPivot().Position, Vector3.new(0, -distance, 0), raycastParams)
end

local function getRayPosition(character: Model, distance: number): Vector3
	local raycastResult = raycast(character, distance)
	return raycastResult and raycastResult.Position
end

local function isJumping(character): boolean
	local humanoidRootPart = character:FindFirstChild("HumanoidRootPart")
	return humanoidRootPart and humanoidRootPart.AssemblyLinearVelocity.Y > 0 or false
end

local function getImpactReferencePart(character)
	return InstanceCreator("Part", "Part", workspace, {
		Position = (getRayPosition(character, 30) or character:GetPivot().Position) + Vector3.new(0, 0.5, 0),
		Size = Vector3.new(1, 1, 1),
		Transparency = 1,
		CanCollide = false,
		Anchored = true,
	})
end

local function clearCharacterVelocity(character: Model)
	local humanoidRootPart = character:FindFirstChild("HumanoidRootPart")
	if not humanoidRootPart then
		return
	end

	local velocity = humanoidRootPart.AssemblyLinearVelocity
	humanoidRootPart.AssemblyLinearVelocity = Vector3.new(velocity.X, -workspace.Gravity, velocity.Z)
	humanoidRootPart.AssemblyAngularVelocity = Vector3.zero
end

local function createRock(startPosition: Vector3)
	local rock = InstanceCreator("Part", "Part", workspace, {
		Size = Vector3.new(0.5, 0.5, 0.5),
		Color = Color3.fromRGB(122, 72, 39),
		Position = startPosition,
		Anchored = true,
		CanCollide = false,
		CanTouch = false,
		CanQuery = false,
		Massless = true,
	})

	local angle = math.random() * math.pi * 2
	local radius = math.sqrt(math.random()) * 6
	local offset = Vector3.new(math.cos(angle) * radius, math.random(2, 20) / 10, math.sin(angle) * radius)

	PlayTween(rock, TweenInfo.new(1, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Position = startPosition + offset,
		Transparency = 1,
		Orientation = Vector3.new(math.random(1, 180), math.random(1, 180), math.random(1, 180)),
	}, function()
		rock:Destroy()
	end)
end

local function rockDebris(startPosition: Vector3)
	for i = 50, 1, -1 do
		createRock(startPosition)
	end
end

local function impactVibration(duration: number, intensity: number)
	local elapsed = 0
	local connection

	connection = RunService.RenderStepped:Connect(function(deltaTime)
		elapsed += deltaTime
		if elapsed >= duration then
			connection:Disconnect()
			return
		end

		local fade = 1 - (elapsed / duration)
		local strength = intensity * fade
		Camera.CFrame *= CFrame.Angles(
			math.rad(math.random(-100, 100) / 100 * strength),
			math.rad(math.random(-100, 100) / 100 * strength),
			0
		)
	end)
end

local function toggleFallingWindSfxVolume(volume: number)
	local shouldPlay = volume > 0
	FallingWindSfx.Volume = shouldPlay and 0 or 0.5
	if shouldPlay then
		FallingWindSfx:Play()
	end

	PlayTween(FallingWindSfx, TweenInfo.new(0.25), {
		Volume = volume,
	}, function()
		if not shouldPlay then
			FallingWindSfx:Stop()
		end
	end)
end

local function disableFallingSound(character: Model)
	local humanoidRootPart = character:WaitForChild("HumanoidRootPart")
	local freeFallingSound = humanoidRootPart:WaitForChild("FreeFalling", 5)
	if freeFallingSound then
		freeFallingSound.Volume = 0
	end
end

-->
local FallController = knit.CreateController({
	Name = "FallController",
	Connections = {},
	Signals = {
		FallingChanged = Signal.new(), -- (isFalling: boolean)
	},
})

-- Private Methods
function FallController:connectFovHandler(character: Model)
	local humanoidRootPart = character:WaitForChild("HumanoidRootPart")
	if not humanoidRootPart then
		return
	end

	local fallTime = 0

	table.insert(
		self.Connections,
		RunService.RenderStepped:Connect(function(deltaTime: number)
			if self.CameraController.BoostFovActive or self.PanelController.ActivePanel then
				fallTime = 0
				return
			end

			if not self.IsFalling then
				fallTime = 0
				Camera.FieldOfView = 70
				return
			end

			local downwardsVelocity = -humanoidRootPart.AssemblyLinearVelocity.Y
			if downwardsVelocity <= 5 then
				return
			end

			fallTime += deltaTime
			local raycastResult = raycast(character, 5000)
			local groundPosition = raycastResult and raycastResult.Position
			if not groundPosition then
				return
			end

			local distanceFromGround = raycastResult.Distance
			local gravity = workspace.Gravity

			local timeForImpact = (
				-downwardsVelocity + math.sqrt(downwardsVelocity ^ 2 + 2 * gravity * distanceFromGround)
			) / gravity

			local expandAlpha = math.clamp(fallTime / 0.75, 0, 1)
			local returnAlpha = math.clamp(timeForImpact / 0.8, 0, 1)
			local effectAlpha = math.min(expandAlpha, returnAlpha)

			local targetFov = 70 + (30 * effectAlpha)
			local smoothingAlpha = 1 - math.exp(-10 * deltaTime)

			Camera.FieldOfView += (targetFov - Camera.FieldOfView) * smoothingAlpha
		end)
	)
end

function FallController:impactEffects(character: any, humanoid: Humanoid)
	clearCharacterVelocity(character)

	humanoid.WalkSpeed = 0
	task.delay(0.25, function()
		humanoid.WalkSpeed = self.SpeedStateController:GetWalkSpeed()
	end)

	local impactReferencePart = getImpactReferencePart(character)
	Debris:addItem(impactReferencePart, 5)

	self.AudioController:PlaySfx("Impact", { PlayOver = true, Parent = impactReferencePart })

	particleEmitter(ImpactVfx, impactReferencePart)
	rockDebris(impactReferencePart.Position)
	impactVibration(1, 1)
end

function FallController:resetStamina()
	if self.ZoneController.Zone == "Lobby" then
		self.StaminaController:Reset()
	end
end

function FallController:disconnect()
	for _, connection in pairs(self.Connections) do
		if typeof(connection) == "RBXScriptConnection" then
			connection:Disconnect()
		end
	end
	table.clear(self.Connections)
end

function FallController:connect(character)
	disableFallingSound(character)
	self:connectFovHandler(character)

	local humanoid = character:WaitForChild("Humanoid") :: Humanoid
	humanoid:SetStateEnabled(Enum.HumanoidStateType.FallingDown, false)

	self.IsFalling = false
	table.insert(
		self.Connections,
		humanoid.StateChanged:Connect(function(old: Enum.HumanoidStateType, new: Enum.HumanoidStateType)
			if new == Enum.HumanoidStateType.Freefall then
				task.delay(0.5, function()
					if humanoid:GetState() ~= Enum.HumanoidStateType.Freefall then
						return
					end

					local ySize = character:GetExtentsSize().Y
					local minimumDistanceToGround = ySize * 3
					if isJumping(character) or raycast(character, minimumDistanceToGround) then
						return
					end

					self.IsFalling = true
					self.Signals.FallingChanged:Fire(true)
					toggleFallingWindSfxVolume(0.5)
					self.AnimationController:Play("Falling", true)
				end)
			elseif
				self.IsFalling
				and old == Enum.HumanoidStateType.Freefall
				and new == Enum.HumanoidStateType.Landed
			then
				toggleFallingWindSfxVolume(0)
				self.IsFalling = false
				self.Signals.FallingChanged:Fire(false)
				self:impactEffects(character, humanoid)
				self.AnimationController:Play("FrontFlip", true)
				self:resetStamina()
			elseif self.IsFalling and old == Enum.HumanoidStateType.Freefall then
				toggleFallingWindSfxVolume(0)
				self.IsFalling = false
				self.Signals.FallingChanged:Fire(false)
				self.AnimationController:Stop("Falling")
			end
		end)
	)
end

function FallController:listenToCharacterController()
	self.CharacterController.CharacterAdded:Connect(function(character)
		self:disconnect()
		self:connect(character)
	end)

	self.CharacterController.CharacterRemoved:Connect(function()
		self:disconnect()
	end)
end

-- LifeCycle
function FallController:KnitInit()
	self.AnimationController = knit.GetController("AnimationController")
	self.AudioController = knit.GetController("AudioController")
	self.SpeedStateController = knit.GetController("SpeedStateController")
	self.CharacterController = knit.GetController("CharacterController")
	self.CameraController = knit.GetController("CameraController")
	self.PanelController = knit.GetController("PanelController")
	self.ZoneController = knit.GetController("ZoneController")
	self.StaminaController = knit.GetController("StaminaController")
	self:listenToCharacterController()
end

function FallController:KnitStart()
	-- Temporary
	workspace:WaitForChild("NightWall"):Destroy()
end

return FallController
