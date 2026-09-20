-- Roblox Services
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Packages
local knit = require(ReplicatedStorage.src.Packages.knit)

-->
local LobbyController = knit.CreateController({
	Name = "LobbyController",
})

-- LifeCycle
function LobbyController:KnitInit()
	self.PanelController = knit.GetController("PanelController")
end

function LobbyController:KnitStart()
	local tends = workspace:WaitForChild("Tends")
	local robuxShop = tends:WaitForChild("RobuxShop")
	local sellAnimals = tends:WaitForChild("SellAnimals")

	self.PanelController:BindHitbox(robuxShop:WaitForChild("Hitbox"), "Shop")
	self.PanelController:BindHitbox(sellAnimals:WaitForChild("Hitbox"), "SellAnimals")
end

return LobbyController
