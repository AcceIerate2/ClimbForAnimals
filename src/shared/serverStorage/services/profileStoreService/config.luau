-- Roblox Services
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Config Modules
local treadmillConfig = require(ReplicatedStorage.src.GameConfiguration.Economy.treadmillConfig)
local staminaConfig = require(ReplicatedStorage.src.GameConfiguration.Gameplay.staminaConfig)
local baseUpgradeConfig = require(ReplicatedStorage.src.GameConfiguration.Economy.baseUpgradeConfig)
local rebirthConfig = require(ReplicatedStorage.src.GameConfiguration.Economy.rebirthConfig)

-->
return {
	DataTemplate = {
		Speed = 250,
		Rebirths = 0,
		Cash = 1000, -- 999B for testing; never math.huge, it turns the cash tween into NaN

		CashMultiplier = rebirthConfig.GetMultiplier(0),
		AllTimeCashMultiplier = 1, -- Permanent gamepass bonus, separate from rebirths.
		HatchSpeedMultiplier = 1,
		RebirthPurchases = { Credits = 0, Receipts = {} },

		PendingOfflineCash = 0,
		LastOfflineSeconds = 0,

		Inventory = {},
		PlacedEggs = {},
		EquippedAnimals = {},
		AnimalIndex = { Discovered = {}, Claimed = {} },
		Tutorial = { Initialized = false, Step = "Climb", Completed = false, FreeStaminaUsed = false },

		TreadmillLevel = treadmillConfig.BaseLevel,
		StaminaConsumptionRate = staminaConfig.BaseConsumptionAmount,
		StaminaLevel = 0, -- Initialized to level 1; 0 migrates existing drain upgrades on join.

		BaseLevel = 1,
		MaxAnimals = baseUpgradeConfig.Levels[1].MaxAnimals,

		LastSeen = 0,
		JoinedBefore = false,
		GroupRewardClaimed = false,
		DailyRewards = { Day = 1, LastClaim = 0 },

		TrailInventory = {}, -- { [trailName] = true }
		EquippedTrail = "", -- "" = no trail equipped

		EggPurchases = { SkipTimer = 0, SkipTimerCredits = {}, GrowAll = 0, Receipts = {}, Targets = {} },
		PurchaseHistory = {},
	},
}
