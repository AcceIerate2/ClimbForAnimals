-- Roblox Services
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Packages
local knit = require(ReplicatedStorage.src.Packages.knit)

-->
return function(_button: GuiButton)
	knit.GetController("OfflineCashController"):Claim()
end
