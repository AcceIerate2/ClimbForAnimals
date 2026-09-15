-- Roblox Services
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Config Modules
local treadmillConfig = require(ReplicatedStorage.src.GameConfiguration.Economy.treadmillConfig)
local staminaConfig = require(ReplicatedStorage.src.GameConfiguration.Gameplay.staminaConfig)

-->
return {
	DataTemplate = {
		Speed = 250,
		Rebirths = 0,
		Cash = math.huge,

		Inventory = {},
		PlacedEggs = {},

		TreadmillLevel = treadmillConfig.BaseLevel,
		StaminaConsumptionRate = staminaConfig.BaseConsumptionAmount,

		BaseLevel = 1,
		MaxAnimals = 6,

		LastSeen = 0,
		JoinedBefore = false,

		PurchaseHistory = {},
	},
}
