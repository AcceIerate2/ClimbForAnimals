-- Roblox Services
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

-- Packages
local knit = require(ReplicatedStorage.src.Packages.knit)

-- Utility Modules
local animalConfig = require(ReplicatedStorage.src.GameConfiguration.Gameplay.animalConfig)
local cFrameSerializer = require(ReplicatedStorage.src.utility.cFrameSerializer)

-- Constants
local AssetsFolder = ReplicatedStorage.Assets
local AnimalAssets = AssetsFolder.Animals

-- Helper Functions
local function getAnimalAsset(animalName: string)
	return AnimalAssets:FindFirstChild(animalName):Clone()
end

-- Types
type PlayerProfile = {
	[string]: { Asset: Model, Connections: { RBXScriptConnection }, Animations: { [string]: AnimationTrack } },
}

-->
local AnimalService = knit.CreateService({
	Name = "AnimalService",
	Profiles = {} :: {
		[Player]: PlayerProfile,
	},
})

-- Client Exposed Methods
function AnimalService.Client:EquipAnimal(player: Player, animalReferenceName: string, cFrame: CFrame)
	return self.Server:EquipAnimal(player, animalReferenceName, cFrame)
end

-- Private Methods
function AnimalService:getProfile(player: Player): PlayerProfile
	return self.Profiles[player]
end

function AnimalService:validateCFrame(cFrame: CFrame) end

-- Public Methods
function AnimalService:EquipAnimal(player: Player, animalReferenceName: string, cFrame: CFrame)
	local valueObject = self.DataService:GetValueObject(player, "EquippedAnimals")
	valueObject:Update(function(mutator)
		mutator[animalReferenceName] = {
			CFrame = cFrameSerializer.Serialize(cFrame),
		}
	end)

	self.InventoryService:RemoveTool(player, animalReferenceName)
	local base = self.BaseService:GetPlayerBase(player)
	local fences = base.Fences

	local animalName = animalReferenceName:split("_")[1]
	local animalAsset = getAnimalAsset(animalName)
	animalAsset:PivotTo(cFrame)
	animalAsset.Name = animalReferenceName
	animalAsset.Parent = base.Animals

	local profile = self:getProfile(player) :: PlayerProfile
	profile[animalReferenceName] = {}
	profile[animalReferenceName].Asset = animalAsset
	profile[animalReferenceName].Connections = {}
	profile[animalReferenceName].Animations = {}

	local elapsed = 0
	local cashPerSecond = animalConfig[animalName].CashPerSecond

	table.insert(profile.animalReferenceName.Connections, RunService.Heartbeat:Connect(function(deltaTime: number) end))
end

function AnimalService:UnEquipAnimal(player: Player, animalReferenceName: string)
	local profile = self:getProfile(player) :: PlayerProfile
	local data = profile[animalReferenceName]

	-- Clear Connections
	for _, connection: RBXScriptConnection in pairs(data.Connections) do
		if typeof(connection) == "RBXScriptConnection" then
			connection:Disconnect()
		end
	end
	table.clear(data.Connections)

	-- Clear Animation Tracks
	for _, animationTrack: AnimationTrack in pairs(data.Animations) do
		animationTrack:Destroy()
	end
	table.clear(data.Animations)

	-- Destroy Asset
	if data.Asset then
		data.Asset:Destroy()
	end

	-- Give Tool Back
	self.InventoryService:StoreInBackpack(player, animalReferenceName, "Animal")
end

function AnimalService:GiveAnimal(player: Player, animal: string)
	return self.InventoryService:GiveItem(player, {
		Name = animal,
		Handler = "Animal",
		CustomData = {},
	})
end

function AnimalService:Connect(player: Player)
	self.Profiles[player] = {}
end

function AnimalService:Disconnect(player: Player)
	local profile = self.Profiles[player] :: PlayerProfile

	for referenceName, data in pairs(profile) do
		-- Clear Connections
		for _, connection in pairs(data.Connections) do
			if typeof(connection) == "RBXScriptConnection" then
				connection:Disconnect()
			end
		end
		table.clear(self.Connections)

		-- Clear Animation Tracks
		for _, animationTrack in pairs(data.Animations) do
			animationTrack:Destroy()
		end
		table.clear(data.Animations)

		-- Destroy Asset
		if data.Asset then
			data.Asset:Destroy()
		end
	end

	self.Profiles[player] = nil
end

-- LifeCycle
function AnimalService:KnitInit()
	self.InventoryService = knit.GetService("InventoryService")
	self.BaseService = knit.GetService("BaseService")
	self.DataService = knit.GetService("DataService")
end

return AnimalService
