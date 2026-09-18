-- Gradient per rarity, for the tiers a single colour cannot express.
-- Applied by animalController: it clears any previous UIGradient on the label and builds a new
-- one from this data, the same way the reference clones a Gradient instance per rarity.
-- Rotation 90 = vertical, 0 = horizontal.
return {
	Divine = {
		Rotation = 90,
		Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, Color3.fromRGB(0, 120, 255)),
			ColorSequenceKeypoint.new(1, Color3.fromRGB(150, 0, 255)),
		}),
	},

	Celestial = {
		Rotation = 90,
		Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, Color3.fromRGB(0, 170, 255)),
			ColorSequenceKeypoint.new(1, Color3.fromRGB(0, 40, 140)),
		}),
	},

	Eternal = {
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
