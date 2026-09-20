-- Gradient per variant, for the "GOLDEN!" / "DIAMOND!" / "RUBY!" title above a variant egg.
-- Same shape as rarityGradients so rarityStyle can apply either one the same way. A UIGradient
-- multiplies TextColor3, so a label using these must have a white base colour.
-- Golden mirrors the values authored in Assets.Eggs.EggStats; the other two follow its recipe:
-- the variant's own tone at the top, a brighter highlight of the same hue at the bottom.
-- Rotation -90 = top to bottom, like the authored one.
return {
	Golden = {
		Rotation = -90,
		Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 170, 0)),
			ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 255, 0)),
		}),
	},

	Diamond = {
		Rotation = -90,
		Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, Color3.fromRGB(0, 140, 255)),
			ColorSequenceKeypoint.new(1, Color3.fromRGB(170, 250, 255)),
		}),
	},

	Ruby = {
		Rotation = -90,
		Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, Color3.fromRGB(190, 20, 50)),
			ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 120, 130)),
		}),
	},
}
