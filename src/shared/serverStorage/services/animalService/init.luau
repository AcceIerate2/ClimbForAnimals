-- Roblox Services
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Packages
local knit = require(ReplicatedStorage.src.Packages.knit)

-->
local AnimalService = knit.CreateService({
	Name = "AnimalService",
})

-- Public Methods
function AnimalService:EquipAnimal(animalReferenceId: string) end

function AnimalService:UnEquipAnimal(animalReferenceId: string) end

function AnimalService:GiveAnimal(player: Player, animal: string)
	local referenceId: string, tool: Tool = self.InventoryService:GiveItem(player, {
		Name = animal,
		Type = "Animal",
		CustomData = {},
	})
end

-- LifeCycle
function AnimalService:KnitInit()
	self.InventoryService = knit.GetService("InventoryService")
end

return AnimalService
