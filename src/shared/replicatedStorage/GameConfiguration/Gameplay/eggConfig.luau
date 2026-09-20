local EggConfig = {}

-- Egg size roll (same logic as the reference): weighted tier -> uniform value inside the tier -> doubling chance
EggConfig.ScaleTiers = {
	{ Min = 0.85, Max = 1.05, Weight = 2000 }, -- normal
	{ Min = 1.45, Max = 1.55, Weight = 250 }, -- 1.5x
	{ Min = 1.9, Max = 2.1, Weight = 125 }, -- 2x
	{ Min = 2.85, Max = 3.15, Weight = 62.5 }, -- 3x
	{ Min = 3.8, Max = 4.2, Weight = 31.25 }, -- 4x
	{ Min = 0.3, Max = 0.45, Weight = 18 }, -- small
	{ Min = 0.1, Max = 0.2, Weight = 5 }, -- tiny
	{ Min = 5.8, Max = 6.2, Weight = 15.625 }, -- huge
	{ Min = 9.5, Max = 12.5, Weight = 3 }, -- giant
	{ Min = 12, Max = 17, Weight = 0.05 }, -- mega
	{ Min = 20, Max = 35, Weight = 0.0001 }, -- colossal
}
EggConfig.ScaleDoubleChance = 0.01
EggConfig.MaxScale = 150
EggConfig.MinVisualScale = 0.6 -- rendered size limits (relative to the model's own size)
EggConfig.MaxVisualScale = 8
EggConfig.PlacedGrowthMultiplier = 1.3 -- a placed egg grows up to this much of its rolled size

-- Variants: rolled once per spawned egg. The egg model, the animal rig and the aura all come
-- from Assets.<Eggs|Animals>.<Name>, and CashMultiplier feeds utility.earningCurve.
-- Weights are relative, so they do not need to add up to 100.
EggConfig.Variants = {
	{ Name = "Normal", Weight = 90, CashMultiplier = 1 },
	{ Name = "Golden", Weight = 7, CashMultiplier = 1.15 },
	{ Name = "Diamond", Weight = 2.5, CashMultiplier = 1.25 },
	{ Name = "Ruby", Weight = 0.5, CashMultiplier = 1.3 },
}

-- Spawn
EggConfig.SpawnAreaName = "SpawnEggs" -- part inside each island (Structures.Islands.<Biome>)
EggConfig.EggsPerCycle = 5
EggConfig.EggSpacing = 2 -- extra studs between spawned eggs

-- Nest (Assets.Eggs.Nest, egg sits on its EggSpotBottom part): scaled to the egg footprint
EggConfig.NestFootprintRatio = 1.2
EggConfig.MinNestScale = 0.15
EggConfig.MaxNestScale = 8 -- matches MaxVisualScale, so the nest never lags behind its egg

-- Steal / carry / drop
EggConfig.StealPrompt = {
	ActionText = "Steal",
	HoldDuration = 1.2,
	MaxActivationDistance = 8,
	Height = 3, -- studs above the egg's base: a giant egg's centre is out of the player's reach
}
-- Position relative to the UpperTorso, with a 90-degree right turn around the egg's hold point.
EggConfig.CarryOffset = CFrame.new(0, 0, -1.5) * CFrame.Angles(0, math.rad(-90), 0)
-- The island's floor part (same name in every island). It is both the surface eggs are
-- spawned on and the region where a carried egg may be dropped.
EggConfig.AreaName = "Area"
EggConfig.DropAreaHeight = 25 -- studs above the area that still count as inside it

-- Eggs: models in ReplicatedStorage.Assets.Eggs.<Variant>.<Biome>.<EggName>
-- Weight = spawn chance among the eggs of the same biome | HatchDuration in seconds
-- HatchDuration is transposed card by card from the reference areas in depth order, so it
-- always grows with the biome: the floor goes 10s -> 2min and the top 5min -> 12h, with the
-- deliberate jump on the last cards (they are meant to be left overnight, and the hatch clock
-- runs offline). The rolled size stretches it further, up to 20x, in eggHandler.GetHatchDuration.
-- The weights follow one shape in every biome (30/22/17/13/9/5/3/2, and 45/33/22 where there
-- are only three eggs), ordered from the cheapest animal to the most expensive. Keeping the
-- same shape everywhere is what the reference does: the deeper biome pays more because its
-- animals are worth more, never because its odds are worse.
-- The animal side (CashPerSecond, WalkSpeed, ModelWeight) lives in animalConfig
EggConfig.Eggs = {
	-- Forest
	Bunny = {
		Biome = "Forest",
		Rarity = "Common",
		Weight = 22,
		HatchDuration = 15, -- 15s
		EggColor = Color3.fromRGB(255, 255, 255),
		Animal = "Bunny",
	},
	Chicken = {
		Biome = "Forest",
		Rarity = "Common",
		Weight = 30,
		HatchDuration = 10, -- 10s
		EggColor = Color3.fromRGB(250, 240, 200),
		Animal = "Chicken",
	},
	["Guienna Pig"] = {
		Biome = "Forest",
		Rarity = "Common",
		Weight = 17,
		HatchDuration = 25, -- 25s
		EggColor = Color3.fromRGB(255, 85, 0),
		Animal = "Guienna Pig",
	},
	["Golden Retriver"] = {
		Biome = "Forest",
		Rarity = "Uncommon",
		Weight = 13,
		HatchDuration = 40, -- 40s
		EggColor = Color3.fromRGB(255, 255, 127),
		Animal = "Golden Retriver",
	},
	Horse = {
		Biome = "Forest",
		Rarity = "Rare",
		Weight = 9,
		HatchDuration = 50, -- 50s
		EggColor = Color3.fromRGB(150, 105, 70),
		Animal = "Horse",
	},
	Llama = {
		Biome = "Forest",
		Rarity = "Epic",
		Weight = 5,
		HatchDuration = 90, -- 1m 30s
		EggColor = Color3.fromRGB(225, 200, 160),
		Animal = "Llama",
	},
	Owl = {
		Biome = "Forest",
		Rarity = "Legendary",
		Weight = 3,
		HatchDuration = 120, -- 2m
		EggColor = Color3.fromRGB(119, 77, 0),
		Animal = "Owl",
	},
	Wolf = {
		Biome = "Forest",
		Rarity = "Legendary",
		Weight = 2,
		HatchDuration = 300, -- 5m
		EggColor = Color3.fromRGB(130, 135, 145),
		Animal = "Wolf",
	},

	-- Winter
	Crab = {
		Biome = "Winter",
		Rarity = "Common",
		Weight = 30,
		HatchDuration = 15, -- 15s
		EggColor = Color3.fromRGB(255, 0, 0),
		Animal = "Crab",
	},
	Pigeon = {
		Biome = "Winter",
		Rarity = "Common",
		Weight = 22,
		HatchDuration = 20, -- 20s
		EggColor = Color3.fromRGB(150, 155, 170),
		Animal = "Pigeon",
	},
	Tuna = {
		Biome = "Winter",
		Rarity = "Uncommon",
		Weight = 17,
		HatchDuration = 30, -- 30s
		EggColor = Color3.fromRGB(55, 95, 140),
		Animal = "Tuna",
	},
	["Sail Fish"] = {
		Biome = "Winter",
		Rarity = "Rare",
		Weight = 13,
		HatchDuration = 50, -- 50s
		EggColor = Color3.fromRGB(90, 130, 175),
		Animal = "Sail Fish",
	},
	stingray = {
		Biome = "Winter",
		Rarity = "Rare",
		Weight = 9,
		HatchDuration = 90, -- 1m 30s
		EggColor = Color3.fromRGB(110, 120, 135),
		Animal = "stingray",
	},
	Seal = {
		Biome = "Winter",
		Rarity = "Epic",
		Weight = 5,
		HatchDuration = 120, -- 2m
		EggColor = Color3.fromRGB(200, 205, 215),
		Animal = "Seal",
	},
	["Polar Bear"] = {
		Biome = "Winter",
		Rarity = "Legendary",
		Weight = 3,
		HatchDuration = 300, -- 5m
		EggColor = Color3.fromRGB(235, 245, 250),
		Animal = "Polar Bear",
	},
	Mamoth = {
		Biome = "Winter",
		Rarity = "Mythic",
		Weight = 2,
		HatchDuration = 1500, -- 25m
		EggColor = Color3.fromRGB(120, 95, 85),
		Animal = "Mamoth",
	},

	-- Ocean
	["Coral Goby"] = {
		Biome = "Ocean",
		Rarity = "Common",
		Weight = 30,
		HatchDuration = 20, -- 20s
		EggColor = Color3.fromRGB(245, 130, 130),
		Animal = "Coral Goby",
	},
	["Gold Fish"] = {
		Biome = "Ocean",
		Rarity = "Common",
		Weight = 22,
		HatchDuration = 30, -- 30s
		EggColor = Color3.fromRGB(245, 155, 50),
		Animal = "Gold Fish",
	},
	["Butter Fly Fish"] = {
		Biome = "Ocean",
		Rarity = "Uncommon",
		Weight = 17,
		HatchDuration = 45, -- 45s
		EggColor = Color3.fromRGB(250, 230, 140),
		Animal = "Butter Fly Fish",
	},
	["Sea Horse"] = {
		Biome = "Ocean",
		Rarity = "Rare",
		Weight = 9,
		HatchDuration = 150, -- 2m 30s
		EggColor = Color3.fromRGB(235, 150, 70),
		Animal = "Sea Horse",
	},
	["Box Fish"] = {
		Biome = "Ocean",
		Rarity = "Rare",
		Weight = 13,
		HatchDuration = 75, -- 1m 15s
		EggColor = Color3.fromRGB(250, 220, 70),
		Animal = "Box Fish",
	},
	["Cow Fish"] = {
		Biome = "Ocean",
		Rarity = "Epic",
		Weight = 5,
		HatchDuration = 240, -- 4m
		EggColor = Color3.fromRGB(240, 210, 90),
		Animal = "Cow Fish",
	},
	["Puffer Fish"] = {
		Biome = "Ocean",
		Rarity = "Legendary",
		Weight = 3,
		HatchDuration = 300, -- 5m
		EggColor = Color3.fromRGB(225, 200, 150),
		Animal = "Puffer Fish",
	},
	["Lion Fish"] = {
		Biome = "Ocean",
		Rarity = "Mythic",
		Weight = 2,
		HatchDuration = 1800, -- 30m
		EggColor = Color3.fromRGB(190, 70, 60),
		Animal = "Lion Fish",
	},

	-- Desert
	Goat = {
		Biome = "Desert",
		Rarity = "Common",
		Weight = 30,
		HatchDuration = 30, -- 30s
		EggColor = Color3.fromRGB(205, 185, 150),
		Animal = "Goat",
	},
	Lizard = {
		Biome = "Desert",
		Rarity = "Common",
		Weight = 22,
		HatchDuration = 40, -- 40s
		EggColor = Color3.fromRGB(150, 165, 95),
		Animal = "Lizard",
	},
	Ostrich = {
		Biome = "Desert",
		Rarity = "Uncommon",
		Weight = 17,
		HatchDuration = 60, -- 1m
		EggColor = Color3.fromRGB(170, 150, 130),
		Animal = "Ostrich",
	},
	Kangaroo = {
		Biome = "Desert",
		Rarity = "Rare",
		Weight = 13,
		HatchDuration = 120, -- 2m
		EggColor = Color3.fromRGB(185, 115, 75),
		Animal = "Kangaroo",
	},
	Pony = {
		Biome = "Desert",
		Rarity = "Rare",
		Weight = 9,
		HatchDuration = 150, -- 2m 30s
		EggColor = Color3.fromRGB(185, 140, 100),
		Animal = "Pony",
	},
	Bull = {
		Biome = "Desert",
		Rarity = "Epic",
		Weight = 5,
		HatchDuration = 270, -- 4m 30s
		EggColor = Color3.fromRGB(95, 65, 50),
		Animal = "Bull",
	},
	Giraffee = {
		Biome = "Desert",
		Rarity = "Legendary",
		Weight = 3,
		HatchDuration = 360, -- 6m
		EggColor = Color3.fromRGB(225, 170, 100),
		Animal = "Giraffee",
	},
	Lion = {
		Biome = "Desert",
		Rarity = "Mythic",
		Weight = 2,
		HatchDuration = 5400, -- 1h 30m
		EggColor = Color3.fromRGB(215, 165, 90),
		Animal = "Lion",
	},

	-- Crystal Mines
	Hamster = {
		Biome = "Crystal Mines",
		Rarity = "Common",
		Weight = 30,
		HatchDuration = 45, -- 45s
		EggColor = Color3.fromRGB(230, 190, 140),
		Animal = "Hamster",
	},
	Snail = {
		Biome = "Crystal Mines",
		Rarity = "Common",
		Weight = 22,
		HatchDuration = 60, -- 1m
		EggColor = Color3.fromRGB(140, 130, 90),
		Animal = "Snail",
	},
	Bat = {
		Biome = "Crystal Mines",
		Rarity = "Uncommon",
		Weight = 17,
		HatchDuration = 120, -- 2m
		EggColor = Color3.fromRGB(85, 75, 95),
		Animal = "Bat",
	},
	Cat = {
		Biome = "Crystal Mines",
		Rarity = "Rare",
		Weight = 13,
		HatchDuration = 240, -- 4m
		EggColor = Color3.fromRGB(130, 120, 135),
		Animal = "Cat",
	},
	Jellyfish = {
		Biome = "Crystal Mines",
		Rarity = "Rare",
		Weight = 9,
		HatchDuration = 300, -- 5m
		EggColor = Color3.fromRGB(170, 0, 255),
		Animal = "Jellyfish",
	},
	Bear = {
		Biome = "Crystal Mines",
		Rarity = "Epic",
		Weight = 5,
		HatchDuration = 900, -- 15m
		EggColor = Color3.fromRGB(110, 80, 60),
		Animal = "Bear",
	},
	WobbeGong = {
		Biome = "Crystal Mines",
		Rarity = "Legendary",
		Weight = 3,
		HatchDuration = 6300, -- 1h 45m
		EggColor = Color3.fromRGB(150, 130, 100),
		Animal = "WobbeGong",
	},
	Moth = {
		Biome = "Crystal Mines",
		Rarity = "Mythic",
		Weight = 2,
		HatchDuration = 14400, -- 4h
		EggColor = Color3.fromRGB(175, 160, 180),
		Animal = "Moth",
	},

	-- Jungle
	Frog = {
		Biome = "Jungle",
		Rarity = "Common",
		Weight = 30,
		HatchDuration = 60, -- 1m
		EggColor = Color3.fromRGB(110, 200, 90),
		Animal = "Frog",
	},
	Surgeonfish = {
		Biome = "Jungle",
		Rarity = "Uncommon",
		Weight = 22,
		HatchDuration = 90, -- 1m 30s
		EggColor = Color3.fromRGB(60, 110, 200),
		Animal = "Surgeonfish",
	},
	Turtle = {
		Biome = "Jungle",
		Rarity = "Rare",
		Weight = 17,
		HatchDuration = 180, -- 3m
		EggColor = Color3.fromRGB(80, 130, 85),
		Animal = "Turtle",
	},
	Parrot = {
		Biome = "Jungle",
		Rarity = "Epic",
		Weight = 13,
		HatchDuration = 240, -- 4m
		EggColor = Color3.fromRGB(60, 180, 90),
		Animal = "Parrot",
	},
	Capybara = {
		Biome = "Jungle",
		Rarity = "Legendary",
		Weight = 9,
		HatchDuration = 420, -- 7m
		EggColor = Color3.fromRGB(160, 120, 85),
		Animal = "Capybara",
	},
	Crocodile = {
		Biome = "Jungle",
		Rarity = "Mythic",
		Weight = 5,
		HatchDuration = 7200, -- 2h
		EggColor = Color3.fromRGB(95, 120, 75),
		Animal = "Crocodile",
	},
	Gorilla = {
		Biome = "Jungle",
		Rarity = "Divine",
		Weight = 3,
		HatchDuration = 16200, -- 4h 30m
		EggColor = Color3.fromRGB(70, 70, 75),
		Animal = "Gorilla",
	},
	Elephant = {
		Biome = "Jungle",
		Rarity = "Celestial",
		Weight = 2,
		HatchDuration = 18000, -- 5h
		EggColor = Color3.fromRGB(140, 140, 145),
		Animal = "Elephant",
	},

	-- Mystic Isles
	Trumpet = {
		Biome = "Mystic Isles",
		Rarity = "Common",
		Weight = 30,
		HatchDuration = 75, -- 1m 15s
		EggColor = Color3.fromRGB(215, 175, 95),
		Animal = "Trumpet",
	},
	["Angel Fish"] = {
		Biome = "Mystic Isles",
		Rarity = "Uncommon",
		Weight = 22,
		HatchDuration = 120, -- 2m
		EggColor = Color3.fromRGB(200, 220, 235),
		Animal = "Angel Fish",
	},
	["Moorish Idol"] = {
		Biome = "Mystic Isles",
		Rarity = "Rare",
		Weight = 17,
		HatchDuration = 240, -- 4m
		EggColor = Color3.fromRGB(245, 215, 100),
		Animal = "Moorish Idol",
	},
	Koala = {
		Biome = "Mystic Isles",
		Rarity = "Epic",
		Weight = 13,
		HatchDuration = 360, -- 6m
		EggColor = Color3.fromRGB(180, 185, 190),
		Animal = "Koala",
	},
	["Sword Fish"] = {
		Biome = "Mystic Isles",
		Rarity = "Legendary",
		Weight = 9,
		HatchDuration = 600, -- 10m
		EggColor = Color3.fromRGB(120, 145, 170),
		Animal = "Sword Fish",
	},
	["Rosy Moth"] = {
		Biome = "Mystic Isles",
		Rarity = "Mythic",
		Weight = 5,
		HatchDuration = 720, -- 12m
		EggColor = Color3.fromRGB(230, 160, 180),
		Animal = "Rosy Moth",
	},
	Snake = {
		Biome = "Mystic Isles",
		Rarity = "Divine",
		Weight = 3,
		HatchDuration = 8100, -- 2h 15m
		EggColor = Color3.fromRGB(170, 85, 255),
		Animal = "Snake",
	},
	Whale = {
		Biome = "Mystic Isles",
		Rarity = "Celestial",
		Weight = 2,
		HatchDuration = 19800, -- 5h 30m
		EggColor = Color3.fromRGB(85, 110, 140),
		Animal = "Whale",
	},

	-- PreHistoric
	Ankylosaurus = {
		Biome = "PreHistoric",
		Rarity = "Common",
		Weight = 30,
		HatchDuration = 90, -- 1m 30s
		EggColor = Color3.fromRGB(255, 170, 127),
		Animal = "Ankylosaurus",
	},
	Triceratops = {
		Biome = "PreHistoric",
		Rarity = "Uncommon",
		Weight = 22,
		HatchDuration = 180, -- 3m
		EggColor = Color3.fromRGB(140, 130, 95),
		Animal = "Triceratops",
	},
	PLESIOSAUR = {
		Biome = "PreHistoric",
		Rarity = "Rare",
		Weight = 17,
		HatchDuration = 300, -- 5m
		EggColor = Color3.fromRGB(255, 170, 255),
		Animal = "PLESIOSAUR",
	},
	Spinosaurus = {
		Biome = "PreHistoric",
		Rarity = "Epic",
		Weight = 13,
		HatchDuration = 480, -- 8m
		EggColor = Color3.fromRGB(0, 170, 255),
		Animal = "Spinosaurus",
	},
	["T-Rex"] = {
		Biome = "PreHistoric",
		Rarity = "Legendary",
		Weight = 9,
		HatchDuration = 660, -- 11m
		EggColor = Color3.fromRGB(110, 100, 70),
		Animal = "T-Rex",
	},
	Velicoraptor = {
		Biome = "PreHistoric",
		Rarity = "Mythic",
		Weight = 5,
		HatchDuration = 9000, -- 2h 30m
		EggColor = Color3.fromRGB(0, 170, 255),
		Animal = "Velicoraptor",
	},
	Azhdarchid = {
		Biome = "PreHistoric",
		Rarity = "Divine",
		Weight = 3,
		HatchDuration = 10800, -- 3h
		EggColor = Color3.fromRGB(72, 72, 72),
		Animal = "Azhdarchid",
	},
	Brachiosaurus = {
		Biome = "PreHistoric",
		Rarity = "Celestial",
		Weight = 2,
		HatchDuration = 21600, -- 6h
		EggColor = Color3.fromRGB(255, 0, 0),
		Animal = "Brachiosaurus",
	},

	-- Divine Heights
	Microraptor = {
		Biome = "Divine Heights",
		Rarity = "Common",
		Weight = 30,
		HatchDuration = 120, -- 2m
		EggColor = Color3.fromRGB(175, 130, 85),
		Animal = "Microraptor",
	},
	Garuda = {
		Biome = "Divine Heights",
		Rarity = "Uncommon",
		Weight = 22,
		HatchDuration = 240, -- 4m
		EggColor = Color3.fromRGB(255, 0, 0),
		Animal = "Garuda",
	},
	Simurgh = {
		Biome = "Divine Heights",
		Rarity = "Rare",
		Weight = 17,
		HatchDuration = 420, -- 7m
		EggColor = Color3.fromRGB(90, 175, 165),
		Animal = "Simurgh",
	},
	Unicorn = {
		Biome = "Divine Heights",
		Rarity = "Epic",
		Weight = 13,
		HatchDuration = 780, -- 13m
		EggColor = Color3.fromRGB(240, 230, 250),
		Animal = "Unicorn",
	},
	Sphinx = {
		Biome = "Divine Heights",
		Rarity = "Legendary",
		Weight = 9,
		HatchDuration = 9000, -- 2h 30m
		EggColor = Color3.fromRGB(225, 195, 130),
		Animal = "Sphinx",
	},
	Dragon = {
		Biome = "Divine Heights",
		Rarity = "Mythic",
		Weight = 5,
		HatchDuration = 10800, -- 3h
		EggColor = Color3.fromRGB(190, 50, 50),
		Animal = "Dragon",
	},
	Chriema = {
		Biome = "Divine Heights",
		Rarity = "Divine",
		Weight = 3,
		HatchDuration = 25200, -- 7h
		EggColor = Color3.fromRGB(255, 85, 0),
		Animal = "Chriema",
	},
	["Fire Phoenix"] = {
		Biome = "Divine Heights",
		Rarity = "Celestial",
		Weight = 2,
		HatchDuration = 43200, -- 12h
		EggColor = Color3.fromRGB(255, 85, 0),
		Animal = "Fire Phoenix",
	},

	-- Celestial
	Hydra = {
		Biome = "Celestial",
		Rarity = "Eternal",
		Weight = 45,
		HatchDuration = 28800, -- 8h
		EggColor = Color3.fromRGB(120, 70, 190),
		Animal = "Hydra",
	},
	Kitsune = {
		Biome = "Celestial",
		Rarity = "Eternal",
		Weight = 33,
		HatchDuration = 50400, -- 14h
		EggColor = Color3.fromRGB(215, 130, 220),
		Animal = "Kitsune",
	},
	["Red Dragon"] = {
		Biome = "Celestial",
		Rarity = "Eternal",
		Weight = 22,
		HatchDuration = 57600, -- 16h
		EggColor = Color3.fromRGB(170, 35, 45),
		Animal = "Red Dragon",
	},
}

return EggConfig
