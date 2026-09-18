local AnimalConfig = {}

-- One entry per animal (the egg hatches into it, see eggConfig.Eggs[egg].Animal).
-- CashPerSecond: cash the animal generates every second while placed on the base; follows the
--   rarity tier, taken from the median EarningRate of each tier in the reference game
--   (3 / 12 / 100 / 400 / 7000 / 40000 / 800000 / 20000000 / 120000000).
-- WalkSpeed: how fast it walks around the plot (cosmetic).
-- ModelWeight: the species' plausible real weight in KG at scale 1x, hand-picked like the
--   reference does (a small rare animal weighs less than a big common one on purpose).
--   KG shown for an egg OR its animal = ModelWeight * AssetScale^3 (utility.eggHandler.GetWeightKg).
-- Grouped by biome (climbing order) and by rarity.

-- ========================= Forest (height 200) =========================
-- Common
AnimalConfig.Bunny = {
	CashPerSecond = 3,
	WalkSpeed = 5,
	ModelWeight = 2,
}
AnimalConfig.Chicken = {
	CashPerSecond = 3,
	WalkSpeed = 5,
	ModelWeight = 3,
}
AnimalConfig["Guienna Pig"] = {
	CashPerSecond = 3,
	WalkSpeed = 5,
	ModelWeight = 1,
}
-- Uncommon
AnimalConfig["Golden Retriver"] = {
	CashPerSecond = 12,
	WalkSpeed = 5,
	ModelWeight = 30,
}
-- Rare
AnimalConfig.Horse = {
	CashPerSecond = 100,
	WalkSpeed = 5,
	ModelWeight = 500,
}
-- Epic
AnimalConfig.Llama = {
	CashPerSecond = 400,
	WalkSpeed = 5,
	ModelWeight = 130,
}
-- Legendary
AnimalConfig.Owl = {
	CashPerSecond = 7000,
	WalkSpeed = 5,
	ModelWeight = 1.5,
}
AnimalConfig.Wolf = {
	CashPerSecond = 7000,
	WalkSpeed = 5,
	ModelWeight = 40,
}

-- ========================= Winter (height 404) =========================
-- Common
AnimalConfig.Crab = {
	CashPerSecond = 3,
	WalkSpeed = 5,
	ModelWeight = 1,
}
AnimalConfig.Pigeon = {
	CashPerSecond = 3,
	WalkSpeed = 5,
	ModelWeight = 0.4,
}
-- Uncommon
AnimalConfig.Tuna = {
	CashPerSecond = 12,
	WalkSpeed = 5,
	ModelWeight = 250,
}
-- Rare
AnimalConfig["Sail Fish"] = {
	CashPerSecond = 100,
	WalkSpeed = 5,
	ModelWeight = 90,
}
AnimalConfig.stingray = {
	CashPerSecond = 100,
	WalkSpeed = 5,
	ModelWeight = 30,
}
-- Epic
AnimalConfig.Seal = {
	CashPerSecond = 400,
	WalkSpeed = 5,
	ModelWeight = 150,
}
-- Legendary
AnimalConfig["Polar Bear"] = {
	CashPerSecond = 7000,
	WalkSpeed = 5,
	ModelWeight = 450,
}
-- Mythic
AnimalConfig.Mamoth = {
	CashPerSecond = 40000,
	WalkSpeed = 5,
	ModelWeight = 6000,
}

-- ========================= Ocean (height 812) =========================
-- Common
AnimalConfig["Coral Goby"] = {
	CashPerSecond = 3,
	WalkSpeed = 5,
	ModelWeight = 0.3,
}
AnimalConfig["Gold Fish"] = {
	CashPerSecond = 3,
	WalkSpeed = 5,
	ModelWeight = 0.2,
}
-- Uncommon
AnimalConfig["Butter Fly Fish"] = {
	CashPerSecond = 12,
	WalkSpeed = 5,
	ModelWeight = 0.3,
}
AnimalConfig["Sea Horse"] = {
	CashPerSecond = 100,
	WalkSpeed = 5,
	ModelWeight = 0.2,
}
-- Rare
AnimalConfig["Box Fish"] = {
	CashPerSecond = 100,
	WalkSpeed = 5,
	ModelWeight = 0.5,
}
AnimalConfig["Cow Fish"] = {
	CashPerSecond = 400,
	WalkSpeed = 5,
	ModelWeight = 1,
}
-- Legendary
AnimalConfig["Puffer Fish"] = {
	CashPerSecond = 7000,
	WalkSpeed = 5,
	ModelWeight = 2,
}
-- Mythic
AnimalConfig["Lion Fish"] = {
	CashPerSecond = 40000,
	WalkSpeed = 5,
	ModelWeight = 1.2,
}

-- ========================= Desert (height 1356) =========================
-- Common
AnimalConfig.Goat = {
	CashPerSecond = 3,
	WalkSpeed = 5,
	ModelWeight = 60,
}
AnimalConfig.Lizard = {
	CashPerSecond = 3,
	WalkSpeed = 5,
	ModelWeight = 5,
}
-- Uncommon
AnimalConfig.Ostrich = {
	CashPerSecond = 12,
	WalkSpeed = 5,
	ModelWeight = 110,
}
-- Rare
AnimalConfig.Kangaroo = {
	CashPerSecond = 100,
	WalkSpeed = 5,
	ModelWeight = 70,
}
AnimalConfig.Pony = {
	CashPerSecond = 100,
	WalkSpeed = 5,
	ModelWeight = 250,
}
-- Epic
AnimalConfig.Bull = {
	CashPerSecond = 400,
	WalkSpeed = 5,
	ModelWeight = 900,
}
-- Legendary
AnimalConfig.Giraffee = {
	CashPerSecond = 7000,
	WalkSpeed = 5,
	ModelWeight = 1200,
}
-- Mythic
AnimalConfig.Lion = {
	CashPerSecond = 40000,
	WalkSpeed = 5,
	ModelWeight = 190,
}

-- ========================= Crystal Mines (height 2172) =========================
-- Common
AnimalConfig.Hamster = {
	CashPerSecond = 3,
	WalkSpeed = 5,
	ModelWeight = 0.2,
}
AnimalConfig.Snail = {
	CashPerSecond = 3,
	WalkSpeed = 5,
	ModelWeight = 0.3,
}
-- Uncommon
AnimalConfig.Bat = {
	CashPerSecond = 12,
	WalkSpeed = 5,
	ModelWeight = 0.3,
}
-- Rare
AnimalConfig.Cat = {
	CashPerSecond = 100,
	WalkSpeed = 5,
	ModelWeight = 4.5,
}
AnimalConfig.Jellyfish = {
	CashPerSecond = 100,
	WalkSpeed = 5,
	ModelWeight = 2,
}
-- Epic
AnimalConfig.Bear = {
	CashPerSecond = 400,
	WalkSpeed = 5,
	ModelWeight = 300,
}
-- Legendary
AnimalConfig.WobbeGong = {
	CashPerSecond = 7000,
	WalkSpeed = 5,
	ModelWeight = 70,
}
-- Mythic
AnimalConfig.Moth = {
	CashPerSecond = 40000,
	WalkSpeed = 5,
	ModelWeight = 0.3,
}

-- ========================= Jungle (height 3124) =========================
-- Common
AnimalConfig.Frog = {
	CashPerSecond = 3,
	WalkSpeed = 5,
	ModelWeight = 0.5,
}
-- Uncommon
AnimalConfig.Surgeonfish = {
	CashPerSecond = 12,
	WalkSpeed = 5,
	ModelWeight = 0.6,
}
-- Rare
AnimalConfig.Turtle = {
	CashPerSecond = 100,
	WalkSpeed = 5,
	ModelWeight = 5,
}
-- Epic
AnimalConfig.Parrot = {
	CashPerSecond = 400,
	WalkSpeed = 5,
	ModelWeight = 1,
}
-- Legendary
AnimalConfig.Capybara = {
	CashPerSecond = 7000,
	WalkSpeed = 5,
	ModelWeight = 60,
}
-- Mythic
AnimalConfig.Crocodile = {
	CashPerSecond = 40000,
	WalkSpeed = 5,
	ModelWeight = 400,
}
-- Divine
AnimalConfig.Gorilla = {
	CashPerSecond = 800000,
	WalkSpeed = 5,
	ModelWeight = 190,
}
-- Celestial
AnimalConfig.Elephant = {
	CashPerSecond = 20000000,
	WalkSpeed = 5,
	ModelWeight = 4000,
}

-- ========================= Mystic Isles (height 4348) =========================
-- Common
AnimalConfig.Trumpet = {
	CashPerSecond = 3,
	WalkSpeed = 5,
	ModelWeight = 1,
}
-- Uncommon
AnimalConfig["Angel Fish"] = {
	CashPerSecond = 12,
	WalkSpeed = 5,
	ModelWeight = 0.5,
}
-- Rare
AnimalConfig["Moorish Idol"] = {
	CashPerSecond = 100,
	WalkSpeed = 5,
	ModelWeight = 0.5,
}
-- Epic
AnimalConfig.Koala = {
	CashPerSecond = 400,
	WalkSpeed = 5,
	ModelWeight = 12,
}
-- Legendary
AnimalConfig["Sword Fish"] = {
	CashPerSecond = 7000,
	WalkSpeed = 5,
	ModelWeight = 300,
}
-- Mythic
AnimalConfig["Rosy Moth"] = {
	CashPerSecond = 40000,
	WalkSpeed = 5,
	ModelWeight = 0.3,
}
-- Divine
AnimalConfig.Snake = {
	CashPerSecond = 800000,
	WalkSpeed = 5,
	ModelWeight = 20,
}
-- Celestial
AnimalConfig.Whale = {
	CashPerSecond = 20000000,
	WalkSpeed = 5,
	ModelWeight = 30000,
}

-- ========================= PreHistoric (height 5640) =========================
-- Common
AnimalConfig.Ankylosaurus = {
	CashPerSecond = 3,
	WalkSpeed = 5,
	ModelWeight = 6000,
}
-- Uncommon
AnimalConfig.Triceratops = {
	CashPerSecond = 12,
	WalkSpeed = 5,
	ModelWeight = 9000,
}
-- Rare
AnimalConfig.PLESIOSAUR = {
	CashPerSecond = 100,
	WalkSpeed = 5,
	ModelWeight = 5000,
}
-- Epic
AnimalConfig.Spinosaurus = {
	CashPerSecond = 400,
	WalkSpeed = 5,
	ModelWeight = 7000,
}
-- Legendary
AnimalConfig["T-Rex"] = {
	CashPerSecond = 7000,
	WalkSpeed = 5,
	ModelWeight = 8000,
}
-- Mythic
AnimalConfig.Velicoraptor = {
	CashPerSecond = 40000,
	WalkSpeed = 5,
	ModelWeight = 1500,
}
-- Divine
AnimalConfig.Azhdarchid = {
	CashPerSecond = 800000,
	WalkSpeed = 5,
	ModelWeight = 250,
}
-- Celestial
AnimalConfig.Brachiosaurus = {
	CashPerSecond = 20000000,
	WalkSpeed = 5,
	ModelWeight = 50000,
}

-- ========================= Divine Heights (height 7136) =========================
-- Common
AnimalConfig.Microraptor = {
	CashPerSecond = 3,
	WalkSpeed = 5,
	ModelWeight = 300,
}
-- Uncommon
AnimalConfig.Garuda = {
	CashPerSecond = 12,
	WalkSpeed = 5,
	ModelWeight = 400,
}
-- Rare
AnimalConfig.Simurgh = {
	CashPerSecond = 100,
	WalkSpeed = 5,
	ModelWeight = 900,
}
-- Epic
AnimalConfig.Unicorn = {
	CashPerSecond = 400,
	WalkSpeed = 5,
	ModelWeight = 600,
}
-- Legendary
AnimalConfig.Sphinx = {
	CashPerSecond = 7000,
	WalkSpeed = 5,
	ModelWeight = 1500,
}
-- Mythic
AnimalConfig.Dragon = {
	CashPerSecond = 40000,
	WalkSpeed = 5,
	ModelWeight = 14000,
}
-- Divine
AnimalConfig.Chriema = {
	CashPerSecond = 800000,
	WalkSpeed = 5,
	ModelWeight = 500,
}
-- Celestial
AnimalConfig["Fire Phoenix"] = {
	CashPerSecond = 20000000,
	WalkSpeed = 5,
	ModelWeight = 200,
}

-- ========================= Celestial (height 8632) =========================
-- Eternal
AnimalConfig.Hydra = {
	CashPerSecond = 120000000,
	WalkSpeed = 5,
	ModelWeight = 20000,
}
AnimalConfig.Kitsune = {
	CashPerSecond = 120000000,
	WalkSpeed = 5,
	ModelWeight = 80,
}
AnimalConfig["Red Dragon"] = {
	CashPerSecond = 120000000,
	WalkSpeed = 5,
	ModelWeight = 30000,
}

return AnimalConfig
