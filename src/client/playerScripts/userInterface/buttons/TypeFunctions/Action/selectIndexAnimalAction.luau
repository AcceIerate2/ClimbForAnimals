-- Roblox Services
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Packages
local knit = require(ReplicatedStorage.src.Packages.knit)

return function(button: GuiButton)
	knit.GetController("IndexController"):Select(button:GetAttribute("AnimalName"))
end
