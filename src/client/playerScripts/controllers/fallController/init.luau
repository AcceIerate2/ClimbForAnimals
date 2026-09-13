-- Roblox Services
local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Pacxkages
local knit = require(ReplicatedStorage.src.Packages.knit)

-- Utility Modules
local InstanceCreator = require(ReplicatedStorage.src.utility.InstanceCreator)
local particleEmitter = require(ReplicatedStorage.src.utility.particleEmitter)

-- Constants
local Player = Players.LocalPlayer
local PlayerModule = game.StarterPlayer:WaitForChild("PlayerModule")
local InputContexts = PlayerModule:WaitForChild("InputContexts")
local CharacterContext = InputContexts:WaitForChild("CharacterContext")
local MoveAction = CharacterContext:WaitForChild("MoveAction") :: InputAction

local AssetsFolder = ReplicatedStorage:WaitForChild("Assets")
local ImpactVfx = AssetsFolder:WaitForChild("Vfx"):WaitForChild("ImpactVfx")

local raycastParams = RaycastParams.new()
raycastParams.FilterType = Enum.RaycastFilterType.Exclude

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
		Position = getRayPosition(character, 30) + Vector3.new(0, 0.5, 0),
		Size = Vector3.new(1, 1, 1),
		Transparency = 1,
		CanCollide = false,
		Anchored = true,
	})
end

local function clearCharacterVelocity(character: Model)
	for _, basePart in pairs(character:GetDescendants()) do
		if not basePart:IsA("BasePart") then
			continue
		end

		basePart.AssemblyAngularVelocity = Vector3.zero
		basePart.AssemblyLinearVelocity = Vector3.zero
	end
end

-->
local FallController = knit.CreateController({
	Name = "FallController",
	Connections = {},
})

-- Private Methods
function FallController:impactEffects(character: any)
	task.spawn(function()
		repeat
			task.wait()
		until raycast(character, 1)
		clearCharacterVelocity(character)
	end)

	MoveAction.Enabled = false
	task.delay(0.35, function()
		MoveAction.Enabled = true
	end)

	self.AnimationController:Play("FrontFlip", true)

	local impactReferencePart = getImpactReferencePart(character)
	Debris:addItem(impactReferencePart, 5)

	self.AudioController:PlaySound("Impact", { PlayOver = true, Parent = impactReferencePart })
	particleEmitter(ImpactVfx, impactReferencePart)
end

function FallController:connect(character)
	local humanoid = character:FindFirstChild("Humanoid") :: Humanoid

	local isFalling = false
	table.insert(
		self.Connections,
		humanoid.StateChanged:Connect(function(old: Enum.HumanoidStateType, new: Enum.HumanoidStateType)
			if new == Enum.HumanoidStateType.Freefall then
				task.wait(1)
				if isJumping(character) or raycast(character, 30) then
					return
				end

				isFalling = true
				self.AnimationController:Play("Falling", true)
			elseif isFalling and old == Enum.HumanoidStateType.Freefall and new == Enum.HumanoidStateType.Landed then
				isFalling = false
				self:impactEffects(character)
			end
		end)
	)
end

-- LifeCycle
function FallController:KnitInit()
	self.AnimationController = knit.GetController("AnimationController")
	self.AudioController = knit.GetController("AudioController")
end

function FallController:KnitStart()
	local connection
	local function disconnect()
		if typeof(connection) == "RBXScriptConnection" then
			connection:Disconnect()
			connection = nil
		end
	end

	local function connect(character)
		self:connect(character)
	end

	if Player.Character then
		connect(Player.Character)
	end

	Player.CharacterAdded:Connect(function(character)
		disconnect()
		connect(character)
	end)
end

return FallController
