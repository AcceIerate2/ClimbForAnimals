-- Roblox Services
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Packages
local knit = require(ReplicatedStorage.src.Packages.knit)

-->
local ClimbController = knit.CreateController({
	Name = "ClimbController",
})

-- LifeCycle
function ClimbController:KnitStart() end

return ClimbController
