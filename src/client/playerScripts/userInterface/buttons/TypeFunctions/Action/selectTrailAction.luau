-- Roblox Services
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Packages
local knit = require(ReplicatedStorage.src.Packages.knit)

-->
return function(button: GuiButton)
	knit.GetController("TrailsShopController"):SelectTrail(button:GetAttribute("TrailName"))
end
