-- Paints a rarity or variant label the same way everywhere (the animal billboard above the
-- head and the egg billboard while it grows). Kept in one place so the top rarities' gradients
-- do not have to be reimplemented per controller.

-- Roblox Services
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Config Modules
local rarityColors = require(ReplicatedStorage.src.GameConfiguration.General.rarityColors)
local rarityGradients = require(ReplicatedStorage.src.GameConfiguration.General.rarityGradients)
local variantColors = require(ReplicatedStorage.src.GameConfiguration.General.variantColors)

-- Constants
local GradientName = "RarityGradient"

local RarityStyle = {}

-- A UIGradient multiplies TextColor3, so the base colour for the gradient tiers is white in
-- rarityColors. Any previous gradient is cleared because labels are reused.
function RarityStyle.ApplyRarity(label: TextLabel, rarity: string?)
	local previous = label:FindFirstChildOfClass("UIGradient")
	if previous then
		previous:Destroy()
	end

	local color = rarity and rarityColors[rarity]
	if color then
		label.TextColor3 = color
	end

	local gradient = rarity and rarityGradients[rarity]
	if gradient then
		local instance = Instance.new("UIGradient")
		instance.Name = GradientName
		instance.Color = gradient.Color
		instance.Rotation = gradient.Rotation or 0
		instance.Parent = label
	end
end

function RarityStyle.ApplyVariant(label: TextLabel, variant: string?)
	local color = variant and variantColors[variant]
	if color then
		label.TextColor3 = color
	end
end

return RarityStyle
