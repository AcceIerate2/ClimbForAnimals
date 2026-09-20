-- Paints a rarity or variant label the same way everywhere (the animal billboard above the
-- head and the egg billboard while it grows). Kept in one place so the top rarities' gradients
-- do not have to be reimplemented per controller.

-- Roblox Services
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Config Modules
local rarityColors = require(ReplicatedStorage.src.GameConfiguration.General.rarityColors)
local rarityGradients = require(ReplicatedStorage.src.GameConfiguration.General.rarityGradients)
local variantColors = require(ReplicatedStorage.src.GameConfiguration.General.variantColors)
local variantGradients = require(ReplicatedStorage.src.GameConfiguration.General.variantGradients)

-- Utility Modules
local PlayTween = require(ReplicatedStorage.src.utility.PlayTween)

-- Constants
local GradientName = "RarityGradient"

local RarityStyle = {}

-- A UIGradient multiplies TextColor3, so the base colour for the gradient tiers is white in
-- rarityColors. Any previous gradient is cleared because labels are reused.
-- Labels are reused, so any previous gradient goes first. Passing nil just clears.
local function applyGradient(label: TextLabel, data: { Color: ColorSequence, Rotation: number? }?)
	local previous = label:FindFirstChildOfClass("UIGradient")
	if previous then
		previous:Destroy()
	end

	if not data then
		return
	end

	local instance = Instance.new("UIGradient")
	instance.Name = GradientName
	instance.Color = data.Color
	instance.Rotation = data.Rotation or 0
	instance.Parent = label
end

-- A gradient tier's base colour is white so the gradient can multiply it, which makes it
-- useless as a solid tint. Those tiers carry a Tint of their own for that.
function RarityStyle.GetTintColor(rarity: string?): Color3?
	local gradient = rarity and rarityGradients[rarity]
	if gradient and gradient.Tint then
		return gradient.Tint
	end

	return rarity and rarityColors[rarity]
end

function RarityStyle.ApplyRarity(label: TextLabel, rarity: string?)
	local color = rarity and rarityColors[rarity]
	if color then
		label.TextColor3 = color
	end

	applyGradient(label, rarity and rarityGradients[rarity])
end

-- Sweeps the label's gradient across once, for an announcement that should catch the eye. A
-- rarity with no gradient of its own gets a temporary one built from its colour, so every tier can
-- shine. One tween per call, nothing per frame.
function RarityStyle.Shine(label: TextLabel, duration: number?): Tween
	local gradient = label:FindFirstChildOfClass("UIGradient")
	if not gradient then
		local color = label.TextColor3
		label.TextColor3 = Color3.new(1, 1, 1)

		gradient = Instance.new("UIGradient")
		gradient.Name = GradientName
		gradient.Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, color),
			ColorSequenceKeypoint.new(0.5, Color3.new(1, 1, 1)),
			ColorSequenceKeypoint.new(1, color),
		})
		gradient.Parent = label
	end

	gradient.Offset = Vector2.new(-1, 0)

	return PlayTween(gradient, TweenInfo.new(duration or 1.1, Enum.EasingStyle.Sine), {
		Offset = Vector2.new(1, 0),
	})
end

function RarityStyle.ApplyVariant(label: TextLabel, variant: string?)
	local color = variant and variantColors[variant]
	if color then
		label.TextColor3 = color
	end
end

-- The "GOLDEN!" / "DIAMOND!" / "RUBY!" title above a variant egg. Here the gradient carries the
-- colour, so the base has to be white -- a UIGradient multiplies TextColor3.
function RarityStyle.ApplyVariantGradient(label: TextLabel, variant: string?): boolean
	local gradient = variant and variantGradients[variant]
	label.TextColor3 = Color3.new(1, 1, 1)
	applyGradient(label, gradient)

	return gradient ~= nil
end

return RarityStyle
