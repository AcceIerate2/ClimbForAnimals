-- Roblox Services
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Utility Modules
local EarningCurve = require(ReplicatedStorage.src.utility.earningCurve)

-- Config Modules
local RebirthConfig = require(ReplicatedStorage.src.GameConfiguration.Economy.rebirthConfig)

-->
local AnimalSellConfig = {
	IncomeSeconds = 10, -- Sale price = this many seconds of the animal's effective income.
}

-- Shared by the UI preview and authoritative server calculation.
function AnimalSellConfig.GetQuote(item, rebirthMultiplier: number?, allTimeMultiplier: number?)
	if type(item) ~= "table" or item.Handler ~= "Animal" then
		return nil
	end

	local custom = item.CustomData or {}
	local income = EarningCurve.GetCashPerSecond(item.Name, custom.AssetScale, custom.Variant)
	income *= RebirthConfig.ForSource(rebirthMultiplier, "AnimalIncome") * (allTimeMultiplier or 1)
	local price = math.round(income * AnimalSellConfig.IncomeSeconds)
	if income ~= income or income <= 0 or income == math.huge or price <= 0 or price >= 2 ^ 53 then
		return nil
	end

	return { Income = income, Price = price }
end

return AnimalSellConfig
