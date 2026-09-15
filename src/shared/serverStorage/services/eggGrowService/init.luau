-- Roblox Services
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Packages
local knit = require(ReplicatedStorage.src.Packages.knit)

-->
local EggGrowService = knit.CreateService({
	Name = "EggGrowService",
})

-- LifeCycle
function EggGrowService:KnitInit()
	self.DataService = knit.GetService("DataService")
end

return EggGrowService
