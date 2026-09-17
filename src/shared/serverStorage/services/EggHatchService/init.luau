-- Roblox Services
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Packages
local eggConfig = require(ReplicatedStorage.src.GameConfiguration.Gameplay.eggConfig)
local knit = require(ReplicatedStorage.src.Packages.knit)

-->
local EggHatchService = knit.CreateService({
	Name = "EggHatchService",
})

-- Client Exposed Methods
function EggHatchService.Client:Hatch(player: Player, referenceName: string)
	return self.Server:Hatch(player, referenceName)
end

-- Private Methods
function EggHatchService:validateHatch(player: Player, referenceName: string)
	local placedEggsVO = self.DataService:GetValueObject(player, "PlacedEggs")
	local eggData = placedEggsVO:Get()[referenceName]
	if not eggData then
		return false, "Egg was not placed"
	end

	if not eggData.CanHatch then
		return false, "Can't hatch right now!"
	end

	return true
end

-- Public Methods
function EggHatchService:Hatch(player: Player, referenceName: string)
	local validated, reason = self:validateHatch(player, referenceName)
	if not validated then
		return { Status = false, Reason = reason }
	end

	local placedEggsVO = self.DataService:GetValueObject(player, "PlacedEggs")
	placedEggsVO:Update(function(mutator)
		mutator[referenceName] = nil
	end)

	local eggName = referenceName:split("_")[1]
	local eggData = eggConfig[eggName]
	local animal = eggData.Animal
	self.AnimalService:GiveAnimal(player, animal)

	return { Status = true }
end

-- LifeCycle
function EggHatchService:KnitInit()
	self.DataService = knit.GetService("DataService")
	self.AnimalService = knit.GetService("AnimalService")
end

return EggHatchService
