-- Turns an animal's rolled size into its cash rate, mirroring the reference game:
-- the exponent is steeper below the cut and flattens above it, so a giant roll is worth a lot
-- without running away with the economy. The multiplier at the cut is CUT^BELOW_EXPONENT, which
-- makes the two halves meet exactly, and a 1x animal is always exactly its configured rate.

-- Roblox Services
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Config Modules
local animalConfig = require(ReplicatedStorage.src.GameConfiguration.Gameplay.animalConfig)
local eggConfig = require(ReplicatedStorage.src.GameConfiguration.Gameplay.eggConfig)

-- Constants
local CUT_SCALE = 5
local BELOW_EXPONENT = 1.7
local ABOVE_EXPONENT = 1.2
local CUT_MULTIPLIER = CUT_SCALE ^ BELOW_EXPONENT

local EarningCurve = {}

-- Cash multiplier for a rolled AssetScale (1x -> 1, 2x -> 3.25, 5x -> 15.4, 8x -> 26.4).
function EarningCurve.GetSizeMultiplier(assetScale: number?): number
	local scale = typeof(assetScale) == "number" and assetScale or 1
	if scale <= 0 then
		return 0
	end

	if scale <= CUT_SCALE then
		return scale ^ BELOW_EXPONENT
	end

	return (scale / CUT_SCALE) ^ ABOVE_EXPONENT * CUT_MULTIPLIER
end

-- Cash bonus for a variant (Normal 1, Golden 1.15, Diamond 1.25, Ruby 1.3).
function EarningCurve.GetVariantMultiplier(variant: string?): number
	if not variant then
		return 1
	end

	for _, entry in ipairs(eggConfig.Variants) do
		if entry.Name == variant then
			return entry.CashMultiplier or 1
		end
	end

	return 1 -- an unknown variant never penalises the player
end

-- The rate an animal of this species and size actually earns per second.
-- Single source of truth: the income loop, the offline reward and the head billboard all use it.
function EarningCurve.GetCashPerSecond(animalName: string, assetScale: number?, variant: string?): number
	local config = animalConfig[animalName]
	local base = config and config.CashPerSecond
	if typeof(base) ~= "number" or base ~= base or base <= 0 or base == math.huge then
		return 0
	end

	return base * EarningCurve.GetSizeMultiplier(assetScale) * EarningCurve.GetVariantMultiplier(variant)
end

return EarningCurve
