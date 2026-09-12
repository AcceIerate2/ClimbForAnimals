-- Roblox Services
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Packages
local knit = require(ReplicatedStorage.src.Packages.knit)

-->
local SpeedStateController = knit.CreateController({
	Name = "SpeedStateController",
})

return SpeedStateController
