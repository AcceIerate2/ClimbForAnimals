-- Roblox Services
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Packages
local knit = require(ReplicatedStorage.src.Packages.knit)

-->
local EggPlacementController = knit.CreateController({
	Name = "EggPlacementController",
})

-- Public Methods
function EggPlacementController:Place(referenceName: string) end

-- LifeCycle
function EggPlacementController:KnitInit()
	self.EggPlacementService = knit.GetService("EggPlacementService")
	self.DataController = knit.GetController("DataController")
end

return EggPlacementController
