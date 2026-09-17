-- Roblox Services
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

-- Packages
local knit = require(ReplicatedStorage.src.Packages.knit)

-- Utility Modules
local InstanceCreator = require(ReplicatedStorage.src.utility.InstanceCreator)
local AnchorHandler = require(ReplicatedStorage.src.utility.AnchorHandler)

-- Modules
local Movement = require(script.movement)

-- Constants
local AssetsFolder = ReplicatedStorage.Assets
local AnimalAssets = AssetsFolder.Animals
local Player = Players.LocalPlayer
local Mouse = Player:GetMouse()

-- Types
type AnimalState = {
	ReferenceName: string,
	Name: string,
	OwnerId: number,
	From: CFrame,
	To: CFrame,
	StartedAt: number,
	Duration: number,
	Revision: number,
}

type AnimalData = {
	Asset: Model,
	Animations: { [string]: AnimationTrack },
	Connections: { RBXScriptConnection },
	State: AnimalState,
	Mode: string?,
	Revealing: boolean?,
}

-- Helper Functions
local function setupAnimalAsset(animalAsset: Model, root: BasePart)
	AnchorHandler(animalAsset, false)
	root.Anchored = true

	for _, descendant in animalAsset:GetDescendants() do
		if descendant:IsA("BasePart") then
			descendant.CanCollide = false
			descendant.CanTouch = false
			descendant.CanQuery = false
		elseif descendant:IsA("BaseScript") or descendant:IsA("ProximityPrompt") then
			descendant:Destroy()
		end
	end
end

-->
local AnimalController = knit.CreateController({
	Name = "AnimalController",
	Animals = {},
	Revisions = {},
	Pending = {},
})

-- Private Methods
function AnimalController:handleResponse(response: { Status: boolean, Reason: string? })
	if not response.Status and response.Reason then
		self.NotificationController:Push({
			Message = response.Reason,
			Color = Color3.fromRGB(255, 0, 0),
			Sound = "Decline",
		})
	end
end

function AnimalController:disconnectAnimal(referenceName: string)
	local animal = self.Animals[referenceName]
	if not animal then
		return
	end

	for _, connection: RBXScriptConnection in pairs(animal.Connections) do
		connection:Disconnect()
	end

	table.clear(animal.Connections)

	for _, track in pairs(animal.Animations) do
		track:Stop(0)
		track:Destroy()
	end

	animal.Asset:Destroy()
	self.Animals[referenceName] = nil
end

function AnimalController:loadAnimations(animal: AnimalData, animator: Animator)
	for _, name: string in { "Idle", "Walk" } do
		local animation = animal.Asset:FindFirstChild(name)
		if not animation or not animation:IsA("Animation") or animation.AnimationId == "" then
			continue
		end

		local success, track = pcall(function()
			return animator:LoadAnimation(animation)
		end)

		if not success then
			warn(`Couldn't load {animal.State.Name} {name} animation: {track}`)
			continue
		end

		track.Looped = true
		track.Priority = name == "Walk" and Enum.AnimationPriority.Movement or Enum.AnimationPriority.Idle

		animal.Animations[name] = track
	end
end

function AnimalController:connectAnimal(state: AnimalState)
	local asset = AnimalAssets:FindFirstChild(state.Name)
	if not asset or not asset:IsA("Model") then
		return
	end

	local model = asset:Clone()
	model.Name = state.ReferenceName

	local root = model.PrimaryPart
		or model:FindFirstChild("HumanoidRootPart", true)
		or model:FindFirstChildWhichIsA("BasePart", true)
	if not root or not root:IsA("BasePart") then
		model:Destroy()

		return
	end

	setupAnimalAsset(model, root)
	-- Only anchor the root; Motor6Ds/bones remain free to animate the custom rig.
	model:PivotTo(state.From)
	model.Parent = self.Folder

	local controller = model:FindFirstChildWhichIsA("AnimationController", true)
	if not controller then
		controller = InstanceCreator("AnimationController", "AnimationController", model)
	end

	local animator = controller:FindFirstChildOfClass("Animator")
	if not animator then
		animator = InstanceCreator("Animator", "Animator", controller)
	end

	local animal: AnimalData = {
		Asset = model,
		Animations = {},
		Connections = {},
		State = state,
	}

	self:loadAnimations(animal, animator)

	self.Animals[state.ReferenceName] = animal

	return animal
end

function AnimalController:updateAnimal(state: AnimalState)
	local referenceName = state.ReferenceName
	if state.Revision <= (self.Revisions[referenceName] or 0) then
		return
	end

	self.Revisions[referenceName] = state.Revision

	local animal = self.Animals[referenceName] or self:connectAnimal(state)
	if animal then
		animal.State = state
		animal.Revealing = false
	end
end

function AnimalController:updateAnimation(animal: AnimalData, animationName: string)
	if animal.Mode == animationName then
		return
	end

	animal.Mode = animationName

	for name: string, track: AnimationTrack in pairs(animal.Animations) do
		if name == animationName then
			track:Play(0.2)
		else
			track:Stop(0.2)
		end
	end
end

function AnimalController:updateMovement(now: number)
	for _, animal in pairs(self.Animals) do
		if animal.Revealing then
			continue
		end

		local pose, moving = Movement.GetPose(animal.State, now)
		self:updateAnimation(animal, moving and "Walk" or "Idle")

		animal.Asset:PivotTo(pose)
	end
end

-- Public Methods
function AnimalController:BeginReveal(referenceName: string, animalName: string, cFrame: CFrame): Model?
	local animal = self:connectAnimal({
		ReferenceName = referenceName,
		Name = animalName,
		OwnerId = Player.UserId,
		From = cFrame,
		To = cFrame,
		StartedAt = workspace:GetServerTimeNow(),
		Duration = 0,
		Revision = 0,
	})
	if not animal then
		return
	end

	animal.Revealing = true
	self:updateAnimation(animal, "Idle")

	return animal.Asset
end

function AnimalController:CancelReveal(referenceName: string)
	local animal = self.Animals[referenceName]
	if animal and animal.Revealing then
		self:disconnectAnimal(referenceName)
	end
end

function AnimalController:PlaceAnimal(referenceName: string)
	if self.Pending[referenceName] then
		return
	end

	self.Pending[referenceName] = true

	self.AnimalService
		:EquipAnimal(referenceName, Mouse.Hit)
		:andThen(function(response: { Status: boolean, Reason: string? })
			self:handleResponse(response)
		end)
		:catch(warn)
		:finally(function()
			self.Pending[referenceName] = nil
		end)
end

function AnimalController:UnEquipAnimal(referenceName: string)
	if self.Pending[referenceName] then
		return
	end

	self.Pending[referenceName] = true

	self.AnimalService
		:UnEquipAnimal(referenceName)
		:andThen(function(response: { Status: boolean, Reason: string? })
			self:handleResponse(response)
		end)
		:catch(warn)
		:finally(function()
			self.Pending[referenceName] = nil
		end)
end

-- LifeCycle
function AnimalController:KnitInit()
	self.AnimalService = knit.GetService("AnimalService")
	self.NotificationController = knit.GetController("NotificationController")
end

function AnimalController:KnitStart()
	self.Folder = InstanceCreator("Folder", "ClientAnimals", workspace)

	-- Subscribe before requesting the snapshot; revisions prevent a delayed
	-- snapshot from resurrecting a picked-up animal or rewinding its movement.
	self.AnimalService.AnimalChanged:Connect(function(state: AnimalState)
		self:updateAnimal(state)
	end)

	self.AnimalService.AnimalRemoved:Connect(function(referenceName: string, revision: number)
		if revision > (self.Revisions[referenceName] or 0) then
			self.Revisions[referenceName] = revision
			self:disconnectAnimal(referenceName)
		end
	end)

	self.AnimalService
		:GetAnimals()
		:andThen(function(states)
			for _, state in ipairs(states) do
				self:updateAnimal(state)
			end
		end)
		:catch(warn)

	RunService.RenderStepped:Connect(function()
		self:updateMovement(workspace:GetServerTimeNow())
	end)
end

return AnimalController
