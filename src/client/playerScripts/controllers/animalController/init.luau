-- Roblox Services
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Packages
local knit = require(ReplicatedStorage.src.Packages.knit)

-->
local AnimalController = knit.CreateController({
	Name = "AnimalController",
})

-- Public Methods
function AnimalController:Place(referenceName) end

-- LifeCycle
function AnimalController:KnitInit()
	self.AnimalService = knit.GetService("AnimalService")
end

return AnimalController
