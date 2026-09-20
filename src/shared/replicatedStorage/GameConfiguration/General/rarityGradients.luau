-- Gradient per rarity, for the tiers a single colour cannot express.
-- Applied by animalController: it clears any previous UIGradient on the label and builds a new
-- one from this data, the same way the reference clones a Gradient instance per rarity.
-- Rotation 90 = vertical, 0 = horizontal. Tint is the solid stand-in for surfaces a gradient
-- cannot paint by multiplying a colour, such as the tinted background of an inventory row.
return {
	Divine = {
		Tint = Color3.fromRGB(110, 60, 255),
		Rotation = 90,
		Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, Color3.fromRGB(0, 120, 255)),
			ColorSequenceKeypoint.new(1, Color3.fromRGB(150, 0, 255)),
		}),
	},

	Celestial = {
		Tint = Color3.fromRGB(0, 120, 220),
		Rotation = 90,
		Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, Color3.fromRGB(0, 170, 255)),
			ColorSequenceKeypoint.new(1, Color3.fromRGB(0, 40, 140)),
		}),
	},

	Eternal = {
		Tint = Color3.fromRGB(255, 60, 180),
		Rotation = 0,
		Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 0, 0)),
			ColorSequenceKeypoint.new(0.17, Color3.fromRGB(255, 150, 0)),
			ColorSequenceKeypoint.new(0.34, Color3.fromRGB(255, 255, 0)),
			ColorSequenceKeypoint.new(0.51, Color3.fromRGB(0, 255, 60)),
			ColorSequenceKeypoint.new(0.68, Color3.fromRGB(0, 170, 255)),
			ColorSequenceKeypoint.new(0.85, Color3.fromRGB(90, 0, 255)),
			ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 0, 200)),
		}),
	},
}
