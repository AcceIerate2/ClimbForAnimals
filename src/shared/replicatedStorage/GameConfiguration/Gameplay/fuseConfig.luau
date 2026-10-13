-- Roblox Services
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Config Modules
local EggConfig = require(ReplicatedStorage.src.GameConfiguration.Gameplay.eggConfig)

-->
local Config = {
	Enabled = true,
	SlotCount = 3,
	Duration = 10,
	DurationByVariant = {}, -- Optional input-variant overrides, e.g. Golden = 900.
	WeightMode = "Average", -- Average, Highest, or Sum (weights, not visual scales).
	ResetOnRemoval = true, -- False pauses remaining time until all slots are filled again.
	UpdateInterval = 1,
	RequestCooldown = 0.2,
}

-- Public Methods
function Config.GetVariant(item): string
	return item.CustomData and item.CustomData.Variant or item.Variant or "Normal"
end

function Config.GetNextVariant(variant: string): string?
	-- The existing variant list is ordered Normal -> Golden -> Diamond -> Ruby.
	for index, entry in ipairs(EggConfig.Variants) do
		if entry.Name == variant then
			local nextEntry = EggConfig.Variants[index + 1]
			return nextEntry and nextEntry.Name
		end
	end
	return nil
end

function Config.IsSelected(state, reference: string): boolean
	for _, selected in pairs(state and state.Slots or {}) do
		if selected == reference then
			return true
		end
	end
	return false
end

function Config.CanSelect(item, state, inventory): boolean
	if not item or item.Handler ~= "Animal" or not Config.GetNextVariant(Config.GetVariant(item)) then
		return false
	end
	for _, reference in pairs(state and state.Slots or {}) do
		local selected = inventory[reference]
		if selected and (selected.Name ~= item.Name or Config.GetVariant(selected) ~= Config.GetVariant(item)) then
			return false
		end
	end
	return true
end

function Config.GetResult(state, inventory)
	local first, variant, scaleSum, highest = nil, nil, 0, 0
	local seen = {}
	for index = 1, Config.SlotCount do
		local reference = state.Slots[tostring(index)]
		local item = reference and inventory[reference]
		if not item or seen[reference] or not Config.CanSelect(item, state, inventory) then
			return nil
		end
		seen[reference] = true
		first = first or item
		variant = Config.GetVariant(item)
		local scale = item.CustomData and item.CustomData.AssetScale or 1
		if type(scale) ~= "number" or scale ~= scale or scale <= 0 or scale == math.huge then
			return nil
		end
		-- Weight = species base weight * scale^3. Averaging scale directly is incorrect.
		scaleSum += scale ^ 3
		highest = math.max(highest, scale ^ 3)
	end
	local weightScale = Config.WeightMode == "Highest" and highest
		or (Config.WeightMode == "Sum" and scaleSum or scaleSum / Config.SlotCount)
	return {
		Name = first.Name,
		Handler = "Animal",
		CustomData = {
			Variant = Config.GetNextVariant(variant),
			AssetScale = weightScale ^ (1 / 3),
			Gender = first.CustomData and first.CustomData.Gender or "Male",
		},
	}
end

function Config.GetDuration(variant: string): number
	return math.max(0, Config.DurationByVariant[variant] or Config.Duration)
end

return Config
