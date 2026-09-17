-- Roblox Services
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Packages
local knit = require(ReplicatedStorage.src.Packages.knit)

-- Constants
local AssetsFolder = ReplicatedStorage.Assets
local AnimalAssets = AssetsFolder.Animals

-- Helper Functions
local function getAnimalAsset(animalName: string)
	return AnimalAssets:FindFirstChild(animalName):Clone()
end

-->
local AnimalService = knit.CreateService({
	Name = "AnimalService",
	Connections = {} :: {
		[Player]: { [string]: { Connections: { RBXScriptConnection }, Animations: { [string]: AnimationTrack } } },
	},
})

-- Public Methods
function AnimalService:EquipAnimal(player: Player, animalReferenceName: string, cFrame: CFrame)
	local animalName = animalReferenceName:split("_")[1]
	local animalAsset = getAnimalAsset(animalName)
	animalAsset:PivotTo(cFrame)
	animalAsset.Name = animalReferenceName
	animalAsset.Parent = self.BaseService:GetPlayerBase(player).Animals
end

function AnimalService:UnEquipAnimal(animalReferenceName: string) end

function AnimalService:GiveAnimal(player: Player, animal: string)
	return self.InventoryService:GiveItem(player, {
		Name = animal,
		Handler = "Animal",
		CustomData = {},
	})
end

function AnimalService:Connect(player: Player) end

function AnimalService:Disconnect(player: Player) end

-- LifeCycle
function AnimalService:KnitInit()
	self.InventoryService = knit.GetService("InventoryService")
	self.BaseService = knit.GetService("BaseService")
end

return AnimalService
