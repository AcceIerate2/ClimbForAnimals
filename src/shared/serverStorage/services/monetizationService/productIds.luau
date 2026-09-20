-- Roblox Services
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Packages
local knit = require(ReplicatedStorage.src.Packages.knit)

-- Receipt-backed products keep their own durable reward records.
local function eggProduct(action: string, rarity: string?)
	return {
		Action = action,
		Rarity = rarity,
		ProcessReceipt = function(player: Player, receipt)
			return knit.GetService("EggPurchaseService"):ProcessReceipt(player, receipt)
		end,
	}
end

-- Register all developer product IDs here. Simple reward functions are also supported.
local function cashProduct(shopKey: string, amount: number)
	return {
		Action = "CashPack",
		ShopKey = shopKey,
		CashAmount = amount,
		ProcessReceipt = function(player: Player, receipt)
			return knit.GetService("MonetizationService"):ProcessCashPackReceipt(player, receipt)
		end,
	}
end

-- Cash pack amounts are fixed grants; edit the amounts here to rebalance the shop.
local ProductIds = {
	[3713831826] = cashProduct("cashProduct1", 3000),
	[3713831881] = cashProduct("cashProduct2", 40000),
	[3713831956] = cashProduct("cashProduct3", 250000),
	[3713831998] = cashProduct("cashProduct4", 1500000),
	[3713832029] = cashProduct("cashProduct5", 5000000),

	[3713833755] = {
		Action = "SkipRebirth",
		ProcessReceipt = function(player: Player, receipt)
			return knit.GetService("RebirthService"):ProcessReceipt(player, receipt)
		end,
	},

	[3713415676] = eggProduct("SkipTimer", "Common"),
	[3713415701] = eggProduct("SkipTimer", "Uncommon"),
	[3713415714] = eggProduct("SkipTimer", "Rare"),
	[3713415721] = eggProduct("SkipTimer", "Epic"),
	[3713415736] = eggProduct("SkipTimer", "Legendary"),
	[3713415752] = eggProduct("SkipTimer", "Mythic"),
	[3713415768] = eggProduct("SkipTimer", "Divine"),
	[3713415783] = eggProduct("SkipTimer", "Celestial"),
	[3713415794] = eggProduct("SkipTimer", "Eternal"),
	[3713415927] = eggProduct("GrowAll"),
}

return ProductIds
