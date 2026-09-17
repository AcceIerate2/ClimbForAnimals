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
EggConfig.PlacedGrowthMultiplier = 3 -- a placed egg grows up to this much of its rolled size

-- Spawn
EggConfig.SpawnAreaName = "SpawnEggs" -- part inside each island (Structures.Islands.<Biome>)
EggConfig.EggsPerCycle = 5
EggConfig.EggSpacing = 2 -- extra studs between spawned eggs

-- Nest (Assets.Eggs.Nest, egg sits on its EggSpotBottom part): scaled to the egg footprint
EggConfig.NestFootprintRatio = 1.2
EggConfig.MinNestScale = 0.15
EggConfig.MaxNestScale = 3

-- Steal / carry / drop
EggConfig.StealPrompt = {
	ActionText = "Steal",
	HoldDuration = 1.2,
	MaxActivationDistance = 8,
}
EggConfig.CarryOffset = CFrame.new(0, 0, -1.5) -- where the egg bottom sits, relative to the UpperTorso
EggConfig.DropAreaSuffix = "Area" -- drop area part inside each island: <Biome>Area (e.g. ForestArea)
EggConfig.DropAreaHeight = 25 -- studs above the drop area that still count as inside it

-- Eggs: models in ReplicatedStorage.Assets.Eggs.<Variant>.<Biome>.<EggName>
-- Weight = spawn chance among the eggs of the same biome | HatchDuration in seconds
-- The animal side (CashPerSecond, WalkSpeed, ModelWeight) lives in animalConfig
EggConfig.Eggs = {
	-- Forest
	Horse = {
		Biome = "Forest",
		Rarity = "Common",
		Weight = 30,
		HatchDuration = 10,
		EggColor = Color3.fromRGB(150, 105, 70),
		Animal = "Horse",
	},
	Wolf = {
		Biome = "Forest",
		Rarity = "Common",
		Weight = 30,
		HatchDuration = 10,
		EggColor = Color3.fromRGB(130, 135, 145),
		Animal = "Wolf",
	},
	Chicken = {
		Biome = "Forest",
		Rarity = "Uncommon",
		Weight = 15,
		HatchDuration = 30,
		EggColor = Color3.fromRGB(250, 240, 200),
		Animal = "Chicken",
	},
	["Guienna Pig"] = {
		Biome = "Forest",
		Rarity = "Uncommon",
		Weight = 15,
		HatchDuration = 30,
		EggColor = Color3.fromRGB(255, 85, 0),
		Animal = "Guienna Pig",
	},
	Bunny = {
		Biome = "Forest",
		Rarity = "Rare",
		Weight = 6,
		HatchDuration = 60,
		EggColor = Color3.fromRGB(255, 255, 255),
		Animal = "Bunny",
	},
	Llama = {
		Biome = "Forest",
		Rarity = "Rare",
		Weight = 6,
		HatchDuration = 60,
		EggColor = Color3.fromRGB(225, 200, 160),
		Animal = "Llama",
	},
	["Golden Retriver"] = {
		Biome = "Forest",
		Rarity = "Epic",
		Weight = 2.5,
		HatchDuration = 300,
		EggColor = Color3.fromRGB(255, 255, 127),
		Animal = "Golden Retriver",
	},
	Owl = {
		Biome = "Forest",
		Rarity = "Legendary",
		Weight = 1,
		HatchDuration = 900,
		EggColor = Color3.fromRGB(119, 77, 0),
		Animal = "Owl",
	},

	-- Winter
	Mamoth = {
		Biome = "Winter",
		Rarity = "Common",
		Weight = 30,
		HatchDuration = 10,
		EggColor = Color3.fromRGB(120, 95, 85),
		Animal = "Mamoth",
	},
	["Sail Fish"] = {
		Biome = "Winter",
		Rarity = "Common",
		Weight = 30,
		HatchDuration = 10,
		EggColor = Color3.fromRGB(90, 130, 175),
		Animal = "Sail Fish",
	},
	["Polar Bear"] = {
		Biome = "Winter",
		Rarity = "Uncommon",
		Weight = 15,
		HatchDuration = 30,
		EggColor = Color3.fromRGB(235, 245, 250),
		Animal = "Polar Bear",
	},
	stingray = {
		Biome = "Winter",
		Rarity = "Uncommon",
		Weight = 15,
		HatchDuration = 30,
		EggColor = Color3.fromRGB(110, 120, 135),
		Animal = "stingray",
	},
	Crab = {
		Biome = "Winter",
		Rarity = "Rare",
		Weight = 6,
		HatchDuration = 60,
		EggColor = Color3.fromRGB(255, 0, 0),
		Animal = "Crab",
	},
	Pigeon = {
		Biome = "Winter",
		Rarity = "Rare",
		Weight = 6,
		HatchDuration = 60,
		EggColor = Color3.fromRGB(150, 155, 170),
		Animal = "Pigeon",
	},
	Tuna = {
		Biome = "Winter",
		Rarity = "Epic",
		Weight = 2.5,
		HatchDuration = 300,
		EggColor = Color3.fromRGB(55, 95, 140),
		Animal = "Tuna",
	},
	Seal = {
		Biome = "Winter",
		Rarity = "Legendary",
		Weight = 1,
		HatchDuration = 900,
		EggColor = Color3.fromRGB(200, 205, 215),
		Animal = "Seal",
	},

	-- Ocean
	["Cow Fish"] = {
		Biome = "Ocean",
		Rarity = "Common",
		Weight = 30,
		HatchDuration = 10,
		EggColor = Color3.fromRGB(240, 210, 90),
		Animal = "Cow Fish",
	},
	["Lion Fish"] = {
		Biome = "Ocean",
		Rarity = "Common",
		Weight = 30,
		HatchDuration = 10,
		EggColor = Color3.fromRGB(190, 70, 60),
		Animal = "Lion Fish",
	},
	["Box Fish"] = {
		Biome = "Ocean",
		Rarity = "Uncommon",
		Weight = 15,
		HatchDuration = 30,
		EggColor = Color3.fromRGB(250, 220, 70),
		Animal = "Box Fish",
	},
	["Sea Horse"] = {
		Biome = "Ocean",
		Rarity = "Uncommon",
		Weight = 15,
		HatchDuration = 30,
		EggColor = Color3.fromRGB(235, 150, 70),
		Animal = "Sea Horse",
	},
	["Gold Fish"] = {
		Biome = "Ocean",
		Rarity = "Rare",
		Weight = 6,
		HatchDuration = 60,
		EggColor = Color3.fromRGB(245, 155, 50),
		Animal = "Gold Fish",
	},
	["Puffer Fish"] = {
		Biome = "Ocean",
		Rarity = "Rare",
		Weight = 6,
		HatchDuration = 60,
		EggColor = Color3.fromRGB(225, 200, 150),
		Animal = "Puffer Fish",
	},
	["Butter Fly Fish"] = {
		Biome = "Ocean",
		Rarity = "Epic",
		Weight = 2.5,
		HatchDuration = 300,
		EggColor = Color3.fromRGB(250, 230, 140),
		Animal = "Butter Fly Fish",
	},
	["Coral Goby"] = {
		Biome = "Ocean",
		Rarity = "Legendary",
		Weight = 1,
		HatchDuration = 900,
		EggColor = Color3.fromRGB(245, 130, 130),
		Animal = "Coral Goby",
	},

	-- Desert
	Goat = {
		Biome = "Desert",
		Rarity = "Common",
		Weight = 30,
		HatchDuration = 10,
		EggColor = Color3.fromRGB(205, 185, 150),
		Animal = "Goat",
	},
	Lion = {
		Biome = "Desert",
		Rarity = "Common",
		Weight = 30,
		HatchDuration = 10,
		EggColor = Color3.fromRGB(215, 165, 90),
		Animal = "Lion",
	},
	Bull = {
		Biome = "Desert",
		Rarity = "Uncommon",
		Weight = 15,
		HatchDuration = 30,
		EggColor = Color3.fromRGB(95, 65, 50),
		Animal = "Bull",
	},
	Giraffee = {
		Biome = "Desert",
		Rarity = "Uncommon",
		Weight = 15,
		HatchDuration = 30,
		EggColor = Color3.fromRGB(225, 170, 100),
		Animal = "Giraffee",
	},
	Ostrich = {
		Biome = "Desert",
		Rarity = "Rare",
		Weight = 6,
		HatchDuration = 60,
		EggColor = Color3.fromRGB(170, 150, 130),
		Animal = "Ostrich",
	},
	Pony = {
		Biome = "Desert",
		Rarity = "Rare",
		Weight = 6,
		HatchDuration = 60,
		EggColor = Color3.fromRGB(185, 140, 100),
		Animal = "Pony",
	},
	Lizard = {
		Biome = "Desert",
		Rarity = "Epic",
		Weight = 2.5,
		HatchDuration = 300,
		EggColor = Color3.fromRGB(150, 165, 95),
		Animal = "Lizard",
	},
	Kangaroo = {
		Biome = "Desert",
		Rarity = "Legendary",
		Weight = 1,
		HatchDuration = 900,
		EggColor = Color3.fromRGB(185, 115, 75),
		Animal = "Kangaroo",
	},

	-- Crystal Mines
	Bat = {
		Biome = "Crystal Mines",
		Rarity = "Common",
		Weight = 30,
		HatchDuration = 10,
		EggColor = Color3.fromRGB(85, 75, 95),
		Animal = "Bat",
	},
	Bear = {
		Biome = "Crystal Mines",
		Rarity = "Common",
		Weight = 30,
		HatchDuration = 10,
		EggColor = Color3.fromRGB(110, 80, 60),
		Animal = "Bear",
	},
	Snail = {
		Biome = "Crystal Mines",
		Rarity = "Uncommon",
		Weight = 15,
		HatchDuration = 30,
		EggColor = Color3.fromRGB(140, 130, 90),
		Animal = "Snail",
	},
	WobbeGong = {
		Biome = "Crystal Mines",
		Rarity = "Uncommon",
		Weight = 15,
		HatchDuration = 30,
		EggColor = Color3.fromRGB(150, 130, 100),
		Animal = "WobbeGong",
	},
	Cat = {
		Biome = "Crystal Mines",
		Rarity = "Rare",
		Weight = 6,
		HatchDuration = 60,
		EggColor = Color3.fromRGB(130, 120, 135),
		Animal = "Cat",
	},
	Moth = {
		Biome = "Crystal Mines",
		Rarity = "Rare",
		Weight = 6,
		HatchDuration = 60,
		EggColor = Color3.fromRGB(175, 160, 180),
		Animal = "Moth",
	},
	Hamster = {
		Biome = "Crystal Mines",
		Rarity = "Epic",
		Weight = 2.5,
		HatchDuration = 300,
		EggColor = Color3.fromRGB(230, 190, 140),
		Animal = "Hamster",
	},
	Jellyfish = {
		Biome = "Crystal Mines",
		Rarity = "Legendary",
		Weight = 1,
		HatchDuration = 900,
		EggColor = Color3.fromRGB(170, 0, 255),
		Animal = "Jellyfish",
	},

	-- Jungle
	Parrot = {
		Biome = "Jungle",
		Rarity = "Common",
		Weight = 30,
		HatchDuration = 10,
		EggColor = Color3.fromRGB(60, 180, 90),
		Animal = "Parrot",
	},
	Turtle = {
		Biome = "Jungle",
		Rarity = "Common",
		Weight = 30,
		HatchDuration = 10,
		EggColor = Color3.fromRGB(80, 130, 85),
		Animal = "Turtle",
	},
	Capybara = {
		Biome = "Jungle",
		Rarity = "Uncommon",
		Weight = 15,
		HatchDuration = 30,
		EggColor = Color3.fromRGB(160, 120, 85),
		Animal = "Capybara",
	},
	Gorilla = {
		Biome = "Jungle",
		Rarity = "Uncommon",
		Weight = 15,
		HatchDuration = 30,
		EggColor = Color3.fromRGB(70, 70, 75),
		Animal = "Gorilla",
	},
	Crocodile = {
		Biome = "Jungle",
		Rarity = "Rare",
		Weight = 6,
		HatchDuration = 60,
		EggColor = Color3.fromRGB(95, 120, 75),
		Animal = "Crocodile",
	},
	Frog = {
		Biome = "Jungle",
		Rarity = "Rare",
		Weight = 6,
		HatchDuration = 60,
		EggColor = Color3.fromRGB(110, 200, 90),
		Animal = "Frog",
	},
	Surgeonfish = {
		Biome = "Jungle",
		Rarity = "Epic",
		Weight = 2.5,
		HatchDuration = 300,
		EggColor = Color3.fromRGB(60, 110, 200),
		Animal = "Surgeonfish",
	},
	Elephant = {
		Biome = "Jungle",
		Rarity = "Legendary",
		Weight = 1,
		HatchDuration = 900,
		EggColor = Color3.fromRGB(140, 140, 145),
		Animal = "Elephant",
	},

	-- Mystic Isles
	["Angel Fish"] = {
		Biome = "Mystic Isles",
		Rarity = "Common",
		Weight = 30,
		HatchDuration = 10,
		EggColor = Color3.fromRGB(200, 220, 235),
		Animal = "Angel Fish",
	},
	["Rosy Moth"] = {
		Biome = "Mystic Isles",
		Rarity = "Common",
		Weight = 30,
		HatchDuration = 10,
		EggColor = Color3.fromRGB(230, 160, 180),
		Animal = "Rosy Moth",
	},
	["Moorish Idol"] = {
		Biome = "Mystic Isles",
		Rarity = "Uncommon",
		Weight = 15,
		HatchDuration = 30,
		EggColor = Color3.fromRGB(245, 215, 100),
		Animal = "Moorish Idol",
	},
	Whale = {
		Biome = "Mystic Isles",
		Rarity = "Uncommon",
		Weight = 15,
		HatchDuration = 30,
		EggColor = Color3.fromRGB(85, 110, 140),
		Animal = "Whale",
	},
	["Sword Fish"] = {
		Biome = "Mystic Isles",
		Rarity = "Rare",
		Weight = 6,
		HatchDuration = 60,
		EggColor = Color3.fromRGB(120, 145, 170),
		Animal = "Sword Fish",
	},
	Trumpet = {
		Biome = "Mystic Isles",
		Rarity = "Rare",
		Weight = 6,
		HatchDuration = 60,
		EggColor = Color3.fromRGB(215, 175, 95),
		Animal = "Trumpet",
	},
	Snake = {
		Biome = "Mystic Isles",
		Rarity = "Epic",
		Weight = 2.5,
		HatchDuration = 300,
		EggColor = Color3.fromRGB(170, 85, 255),
		Animal = "Snake",
	},
	Koala = {
		Biome = "Mystic Isles",
		Rarity = "Legendary",
		Weight = 1,
		HatchDuration = 900,
		EggColor = Color3.fromRGB(180, 185, 190),
		Animal = "Koala",
	},

	-- PreHistoric
	Triceratops = {
		Biome = "PreHistoric",
		Rarity = "Common",
		Weight = 30,
		HatchDuration = 10,
		EggColor = Color3.fromRGB(140, 130, 95),
		Animal = "Triceratops",
	},
	Velicoraptor = {
		Biome = "PreHistoric",
		Rarity = "Common",
		Weight = 30,
		HatchDuration = 10,
		EggColor = Color3.fromRGB(0, 170, 255),
		Animal = "Velicoraptor",
	},
	Ankylosaurus = {
		Biome = "PreHistoric",
		Rarity = "Uncommon",
		Weight = 15,
		HatchDuration = 30,
		EggColor = Color3.fromRGB(255, 170, 127),
		Animal = "Ankylosaurus",
	},
	PLESIOSAUR = {
		Biome = "PreHistoric",
		Rarity = "Uncommon",
		Weight = 15,
		HatchDuration = 30,
		EggColor = Color3.fromRGB(255, 170, 255),
		Animal = "PLESIOSAUR",
	},
	Brachiosaurus = {
		Biome = "PreHistoric",
		Rarity = "Rare",
		Weight = 6,
		HatchDuration = 60,
		EggColor = Color3.fromRGB(255, 0, 0),
		Animal = "Brachiosaurus",
	},
	["T-Rex"] = {
		Biome = "PreHistoric",
		Rarity = "Rare",
		Weight = 6,
		HatchDuration = 60,
		EggColor = Color3.fromRGB(110, 100, 70),
		Animal = "T-Rex",
	},
	Spinosaurus = {
		Biome = "PreHistoric",
		Rarity = "Epic",
		Weight = 2.5,
		HatchDuration = 300,
		EggColor = Color3.fromRGB(0, 170, 255),
		Animal = "Spinosaurus",
	},
	Azhdarchid = {
		Biome = "PreHistoric",
		Rarity = "Legendary",
		Weight = 1,
		HatchDuration = 900,
		EggColor = Color3.fromRGB(72, 72, 72),
		Animal = "Azhdarchid",
	},

	-- Divine Heights
	Chriema = {
		Biome = "Divine Heights",
		Rarity = "Common",
		Weight = 30,
		HatchDuration = 10,
		EggColor = Color3.fromRGB(255, 85, 0),
		Animal = "Chriema",
	},
	["Fire Phoenix"] = {
		Biome = "Divine Heights",
		Rarity = "Common",
		Weight = 30,
		HatchDuration = 10,
		EggColor = Color3.fromRGB(255, 85, 0),
		Animal = "Fire Phoenix",
	},
	Garuda = {
		Biome = "Divine Heights",
		Rarity = "Uncommon",
		Weight = 15,
		HatchDuration = 30,
		EggColor = Color3.fromRGB(255, 0, 0),
		Animal = "Garuda",
	},
	Unicorn = {
		Biome = "Divine Heights",
		Rarity = "Uncommon",
		Weight = 15,
		HatchDuration = 30,
		EggColor = Color3.fromRGB(240, 230, 250),
		Animal = "Unicorn",
	},
	Microraptor = {
		Biome = "Divine Heights",
		Rarity = "Rare",
		Weight = 6,
		HatchDuration = 60,
		EggColor = Color3.fromRGB(175, 130, 85),
		Animal = "Microraptor",
	},
	Sphinx = {
		Biome = "Divine Heights",
		Rarity = "Rare",
		Weight = 6,
		HatchDuration = 60,
		EggColor = Color3.fromRGB(225, 195, 130),
		Animal = "Sphinx",
	},
	Simurgh = {
		Biome = "Divine Heights",
		Rarity = "Epic",
		Weight = 2.5,
		HatchDuration = 300,
		EggColor = Color3.fromRGB(90, 175, 165),
		Animal = "Simurgh",
	},
	Dragon = {
		Biome = "Divine Heights",
		Rarity = "Legendary",
		Weight = 1,
		HatchDuration = 900,
		EggColor = Color3.fromRGB(190, 50, 50),
		Animal = "Dragon",
	},

	-- Celestial
	Kitsune = {
		Biome = "Celestial",
		Rarity = "Epic",
		Weight = 2.5,
		HatchDuration = 300,
		EggColor = Color3.fromRGB(215, 130, 220),
		Animal = "Kitsune",
	},
	["Red Dragon"] = {
		Biome = "Celestial",
		Rarity = "Legendary",
		Weight = 1,
		HatchDuration = 900,
		EggColor = Color3.fromRGB(170, 35, 45),
		Animal = "Red Dragon",
	},
	Hydra = {
		Biome = "Celestial",
		Rarity = "Mythic",
		Weight = 0.3,
		HatchDuration = 1800,
		EggColor = Color3.fromRGB(120, 70, 190),
		Animal = "Hydra",
	},
}

return EggConfig
