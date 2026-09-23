-- Roblox Services
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Utility Modules
local EarningCurve = require(ReplicatedStorage.src.utility.earningCurve)

-- Config Modules
local RebirthConfig = require(ReplicatedStorage.src.GameConfiguration.Economy.rebirthConfig)

-->
local AnimalSellConfig = {
	IncomeSeconds = 60, -- Sale price = this many seconds of the animal's base income.
}

-- Shared by the UI preview and authoritative server calculation.
function AnimalSellConfig.GetQuote(item, rebirthMultiplier: number?, allTimeMultiplier: number?)
	if type(item) ~= "table" or item.Handler ~= "Animal" then
		return nil
	end

	local custom = item.CustomData or {}
	-- Base income: size and variant only. Like the reference, the sale price ignores rebirth and
	-- the cash gamepass, so a bonus never makes selling better than keeping the animal.
	local baseIncome = EarningCurve.GetCashPerSecond(item.Name, custom.AssetScale, custom.Variant)
	local price = math.round(baseIncome * AnimalSellConfig.IncomeSeconds)
	-- Income is only shown in the row, so it keeps the bonuses and matches the plot billboard.
	local income = baseIncome * RebirthConfig.ForSource(rebirthMultiplier, "AnimalIncome") * (allTimeMultiplier or 1)
	if baseIncome ~= baseIncome or baseIncome <= 0 or baseIncome == math.huge or price <= 0 or price >= 2 ^ 53 then
		return nil
	end

	return { Income = income, Price = price }
end

return AnimalSellConfig
