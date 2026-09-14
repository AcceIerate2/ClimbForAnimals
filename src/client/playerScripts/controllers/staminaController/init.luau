-- Roblox Services
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Packages
local knit = require(ReplicatedStorage.src.Packages.knit)

-->
local StaminaController = knit.CreateController({
	Name = "StaminaController",
})

-- LifeCycle
function StaminaController:KnitInit()
	self.StaminaService = knit.GetService("StaminaService")
end

function StaminaController:KnitStart() end

return StaminaController
