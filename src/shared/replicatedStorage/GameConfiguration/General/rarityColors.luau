-- Solid text colour per rarity.
-- Divine, Celestial and Eternal are white on purpose: a UIGradient multiplies TextColor3,
-- so their real colours come from rarityGradients and the base must stay white.
return {
	Common = Color3.fromRGB(255, 255, 255),
	Uncommon = Color3.fromRGB(157, 255, 0),
	Rare = Color3.fromRGB(0, 217, 255),
	Epic = Color3.fromRGB(255, 0, 76),
	Legendary = Color3.fromRGB(255, 230, 0),
	Mythic = Color3.fromRGB(255, 0, 0),
	Divine = Color3.fromRGB(255, 255, 255),
	Celestial = Color3.fromRGB(255, 255, 255),
	Eternal = Color3.fromRGB(255, 255, 255),
}
