-- Roblox Services
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Config Modules
local treadmillConfig = require(ReplicatedStorage.src.GameConfiguration.Gameplay.treadmillConfig)

-->
return {
	DataTemplate = {
		Speed = 0,
		Rebirths = 0,
		Cash = math.huge,

		TreadmillLevel = treadmillConfig.BaseLevel,

		LastSeen = 0,
		JoinedBefore = false,

		PurchaseHistory = {},
	},
}
