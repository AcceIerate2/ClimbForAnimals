-- Roblox Services
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Packages
local knit = require(ReplicatedStorage.src.Packages.knit)

-->
local AnimalService = knit.CreateService({
	Name = "AnimalService",
})

-- Public Methods
function AnimalService:EquipAnimal(animalReferenceName: string) end

function AnimalService:UnEquipAnimal(animalReferenceName: string) end

function AnimalService:GiveAnimal(player: Player, animal: string)
	return self.InventoryService:GiveItem(player, {
		Name = animal,
		Handler = "Animal",
		CustomData = {},
	})
end

-- LifeCycle
function AnimalService:KnitInit()
	self.InventoryService = knit.GetService("InventoryService")
end

return AnimalService
