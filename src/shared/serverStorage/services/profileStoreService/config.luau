-- Roblox Services
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Config Modules
local treadmillConfig = require(ReplicatedStorage.src.GameConfiguration.Economy.treadmillConfig)

-->
return {
	DataTemplate = {
		Speed = 0,
		Rebirths = 0,
		Cash = math.huge,

		TreadmillLevel = treadmillConfig.BaseLevel,
		MaxStamina = 100,

		BaseLevel = 1,
		MaxAnimals = 6,

		LastSeen = 0,
		JoinedBefore = false,

		PurchaseHistory = {},
	},
}
