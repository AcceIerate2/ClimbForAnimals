-- Roblox Services
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Packages
local knit = require(ReplicatedStorage.src.Packages.knit)

-->
local PassIds = {
	[3713831619] = {
		ShopKey = "Hatch2x",
		Grant = function(player: Player)
			knit.GetService("EggGrowService"):SetHatchSpeedMultiplier(player, 2)
		end,
	},

	[3713831694] = {
		ShopKey = "Cash2x",
		Grant = function(player: Player)
			local dataService = knit.GetService("DataService")
			dataService:GetValueObject(player, "AllTimeCashMultiplier"):Set(2)
			player:SetAttribute("AllTimeCashMultiplier", 2)
		end,
	},
}

return PassIds
