-- Roblox Services
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Packages
local knit = require(ReplicatedStorage.src.Packages.knit)

-->
local BaseUpgradeController = knit.CreateController({
	Name = "BaseUpgradeController",
})

-- LifeCycle
function BaseUpgradeController:KnitInit() end

return BaseUpgradeController
