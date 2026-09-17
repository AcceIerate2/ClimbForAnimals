local AnimalConfig = {}

-- One entry per animal (the egg hatches into it, see eggConfig.Eggs[egg].Animal).
-- CashPerSecond: cash the animal generates every second while placed on the base.
-- WalkSpeed: how fast it walks around the plot (cosmetic).
-- ModelWeight: base weight in KG at scale 1x, like the reference.
--   KG shown for an egg OR its animal = ModelWeight * AssetScale^3 (utility.eggHandler.GetWeightKg),
--   so a 2x egg weighs 8x and the hatched animal keeps the same rolled scale.
-- Grouped by biome (climbing order) and by rarity. Values are placeholders except where noted.

-- ========================= Forest (height 200) =========================
-- Common
AnimalConfig.Horse = {
	CashPerSecond = 10,
	WalkSpeed = 5,
	ModelWeight = 20,
}
AnimalConfig.Wolf = {
	CashPerSecond = 10,
	WalkSpeed = 5,
	ModelWeight = 20,
}
-- Uncommon
AnimalConfig.Chicken = {
	CashPerSecond = 40,
	WalkSpeed = 5,
	ModelWeight = 60,
}
AnimalConfig["Guienna Pig"] = {
	CashPerSecond = 40,
	WalkSpeed = 5,
	ModelWeight = 60,
}
-- Rare
AnimalConfig.Bunny = {
	CashPerSecond = 200,
	WalkSpeed = 5,
	ModelWeight = 150,
}
AnimalConfig.Llama = {
	CashPerSecond = 200,
	WalkSpeed = 5,
	ModelWeight = 150,
}
-- Epic
AnimalConfig["Golden Retriver"] = {
	CashPerSecond = 1200,
	WalkSpeed = 5,
	ModelWeight = 400,
}
-- Legendary
AnimalConfig.Owl = {
	CashPerSecond = 13433,
	WalkSpeed = 5,
	ModelWeight = 1200,
}

-- ========================= Winter (height 404) =========================
-- Common
AnimalConfig.Mamoth = {
	CashPerSecond = 10,
	WalkSpeed = 5,
	ModelWeight = 20,
}
AnimalConfig["Sail Fish"] = {
	CashPerSecond = 10,
	WalkSpeed = 5,
	ModelWeight = 20,
}
-- Uncommon
AnimalConfig["Polar Bear"] = {
	CashPerSecond = 40,
	WalkSpeed = 5,
	ModelWeight = 60,
}
AnimalConfig.stingray = {
	CashPerSecond = 40,
	WalkSpeed = 5,
	ModelWeight = 60,
}
-- Rare
AnimalConfig.Crab = {
	CashPerSecond = 200,
	WalkSpeed = 5,
	ModelWeight = 150,
}
AnimalConfig.Pigeon = {
	CashPerSecond = 200,
	WalkSpeed = 5,
	ModelWeight = 150,
}
-- Epic
AnimalConfig.Tuna = {
	CashPerSecond = 1200,
	WalkSpeed = 5,
	ModelWeight = 400,
}
-- Legendary
AnimalConfig.Seal = {
	CashPerSecond = 8000,
	WalkSpeed = 5,
	ModelWeight = 1200,
}

-- ========================= Ocean (height 812) =========================
-- Common
AnimalConfig["Cow Fish"] = {
	CashPerSecond = 10,
	WalkSpeed = 5,
	ModelWeight = 20,
}
AnimalConfig["Lion Fish"] = {
	CashPerSecond = 10,
	WalkSpeed = 5,
	ModelWeight = 20,
}
-- Uncommon
AnimalConfig["Box Fish"] = {
	CashPerSecond = 40,
	WalkSpeed = 5,
	ModelWeight = 60,
}
AnimalConfig["Sea Horse"] = {
	CashPerSecond = 40,
	WalkSpeed = 5,
	ModelWeight = 60,
}
-- Rare
AnimalConfig["Gold Fish"] = {
	CashPerSecond = 200,
	WalkSpeed = 5,
	ModelWeight = 150,
}
AnimalConfig["Puffer Fish"] = {
	CashPerSecond = 200,
	WalkSpeed = 5,
	ModelWeight = 150,
}
-- Epic
AnimalConfig["Butter Fly Fish"] = {
	CashPerSecond = 1200,
	WalkSpeed = 5,
	ModelWeight = 400,
}
-- Legendary
AnimalConfig["Coral Goby"] = {
	CashPerSecond = 8000,
	WalkSpeed = 5,
	ModelWeight = 1200,
}

-- ========================= Desert (height 1356) =========================
-- Common
AnimalConfig.Goat = {
	CashPerSecond = 10,
	WalkSpeed = 5,
	ModelWeight = 20,
}
AnimalConfig.Lion = {
	CashPerSecond = 10,
	WalkSpeed = 5,
	ModelWeight = 20,
}
-- Uncommon
AnimalConfig.Bull = {
	CashPerSecond = 40,
	WalkSpeed = 5,
	ModelWeight = 60,
}
AnimalConfig.Giraffee = {
	CashPerSecond = 40,
	WalkSpeed = 5,
	ModelWeight = 60,
}
-- Rare
AnimalConfig.Ostrich = {
	CashPerSecond = 200,
	WalkSpeed = 5,
	ModelWeight = 150,
}
AnimalConfig.Pony = {
	CashPerSecond = 200,
	WalkSpeed = 5,
	ModelWeight = 150,
}
-- Epic
AnimalConfig.Lizard = {
	CashPerSecond = 1200,
	WalkSpeed = 5,
	ModelWeight = 400,
}
-- Legendary
AnimalConfig.Kangaroo = {
	CashPerSecond = 8000,
	WalkSpeed = 5,
	ModelWeight = 1200,
}

-- ========================= Crystal Mines (height 2172) =========================
-- Common
AnimalConfig.Bat = {
	CashPerSecond = 10,
	WalkSpeed = 5,
	ModelWeight = 20,
}
AnimalConfig.Bear = {
	CashPerSecond = 10,
	WalkSpeed = 5,
	ModelWeight = 20,
}
-- Uncommon
AnimalConfig.Snail = {
	CashPerSecond = 40,
	WalkSpeed = 5,
	ModelWeight = 60,
}
AnimalConfig.WobbeGong = {
	CashPerSecond = 40,
	WalkSpeed = 5,
	ModelWeight = 60,
}
-- Rare
AnimalConfig.Cat = {
	CashPerSecond = 200,
	WalkSpeed = 5,
	ModelWeight = 150,
}
AnimalConfig.Moth = {
	CashPerSecond = 200,
	WalkSpeed = 5,
	ModelWeight = 150,
}
-- Epic
AnimalConfig.Hamster = {
	CashPerSecond = 1200,
	WalkSpeed = 5,
	ModelWeight = 400,
}
-- Legendary
AnimalConfig.Jellyfish = {
	CashPerSecond = 8000,
	WalkSpeed = 5,
	ModelWeight = 1200,
}

-- ========================= Jungle (height 3124) =========================
-- Common
AnimalConfig.Parrot = {
	CashPerSecond = 10,
	WalkSpeed = 5,
	ModelWeight = 20,
}
AnimalConfig.Turtle = {
	CashPerSecond = 10,
	WalkSpeed = 5,
	ModelWeight = 20,
}
-- Uncommon
AnimalConfig.Capybara = {
	CashPerSecond = 40,
	WalkSpeed = 5,
	ModelWeight = 60,
}
AnimalConfig.Gorilla = {
	CashPerSecond = 40,
	WalkSpeed = 5,
	ModelWeight = 60,
}
-- Rare
AnimalConfig.Crocodile = {
	CashPerSecond = 200,
	WalkSpeed = 5,
	ModelWeight = 150,
}
AnimalConfig.Frog = {
	CashPerSecond = 200,
	WalkSpeed = 5,
	ModelWeight = 150,
}
-- Epic
AnimalConfig.Surgeonfish = {
	CashPerSecond = 1200,
	WalkSpeed = 5,
	ModelWeight = 400,
}
-- Legendary
AnimalConfig.Elephant = {
	CashPerSecond = 8000,
	WalkSpeed = 5,
	ModelWeight = 1200,
}

-- ========================= Mystic Isles (height 4348) =========================
-- Common
AnimalConfig["Angel Fish"] = {
	CashPerSecond = 10,
	WalkSpeed = 5,
	ModelWeight = 20,
}
AnimalConfig["Rosy Moth"] = {
	CashPerSecond = 10,
	WalkSpeed = 5,
	ModelWeight = 20,
}
-- Uncommon
AnimalConfig["Moorish Idol"] = {
	CashPerSecond = 40,
	WalkSpeed = 5,
	ModelWeight = 60,
}
AnimalConfig.Whale = {
	CashPerSecond = 40,
	WalkSpeed = 5,
	ModelWeight = 60,
}
-- Rare
AnimalConfig["Sword Fish"] = {
	CashPerSecond = 200,
	WalkSpeed = 5,
	ModelWeight = 150,
}
AnimalConfig.Trumpet = {
	CashPerSecond = 200,
	WalkSpeed = 5,
	ModelWeight = 150,
}
-- Epic
AnimalConfig.Snake = {
	CashPerSecond = 1200,
	WalkSpeed = 5,
	ModelWeight = 400,
}
-- Legendary
AnimalConfig.Koala = {
	CashPerSecond = 8000,
	WalkSpeed = 5,
	ModelWeight = 1200,
}

-- ========================= PreHistoric (height 5640) =========================
-- Common
AnimalConfig.Triceratops = {
	CashPerSecond = 10,
	WalkSpeed = 5,
	ModelWeight = 20,
}
AnimalConfig.Velicoraptor = {
	CashPerSecond = 10,
	WalkSpeed = 5,
	ModelWeight = 20,
}
-- Uncommon
AnimalConfig.Ankylosaurus = {
	CashPerSecond = 40,
	WalkSpeed = 5,
	ModelWeight = 60,
}
AnimalConfig.PLESIOSAUR = {
	CashPerSecond = 40,
	WalkSpeed = 5,
	ModelWeight = 60,
}
-- Rare
AnimalConfig.Brachiosaurus = {
	CashPerSecond = 200,
	WalkSpeed = 5,
	ModelWeight = 150,
}
AnimalConfig["T-Rex"] = {
	CashPerSecond = 200,
	WalkSpeed = 5,
	ModelWeight = 150,
}
-- Epic
AnimalConfig.Spinosaurus = {
	CashPerSecond = 1200,
	WalkSpeed = 5,
	ModelWeight = 400,
}
-- Legendary
AnimalConfig.Azhdarchid = {
	CashPerSecond = 8000,
	WalkSpeed = 5,
	ModelWeight = 1200,
}

-- ========================= Divine Heights (height 7136) =========================
-- Common
AnimalConfig.Chriema = {
	CashPerSecond = 10,
	WalkSpeed = 5,
	ModelWeight = 20,
}
AnimalConfig["Fire Phoenix"] = {
	CashPerSecond = 10,
	WalkSpeed = 5,
	ModelWeight = 20,
}
-- Uncommon
AnimalConfig.Garuda = {
	CashPerSecond = 40,
	WalkSpeed = 5,
	ModelWeight = 60,
}
AnimalConfig.Unicorn = {
	CashPerSecond = 40,
	WalkSpeed = 5,
	ModelWeight = 60,
}
-- Rare
AnimalConfig.Microraptor = {
	CashPerSecond = 200,
	WalkSpeed = 5,
	ModelWeight = 150,
}
AnimalConfig.Sphinx = {
	CashPerSecond = 200,
	WalkSpeed = 5,
	ModelWeight = 150,
}
-- Epic
AnimalConfig.Simurgh = {
	CashPerSecond = 1200,
	WalkSpeed = 5,
	ModelWeight = 400,
}
-- Legendary
AnimalConfig.Dragon = {
	CashPerSecond = 8000,
	WalkSpeed = 5,
	ModelWeight = 1200,
}

-- ========================= Celestial (height 8632) =========================
-- Epic
AnimalConfig.Kitsune = {
	CashPerSecond = 1200,
	WalkSpeed = 5,
	ModelWeight = 400,
}
-- Legendary
AnimalConfig["Red Dragon"] = {
	CashPerSecond = 8000,
	WalkSpeed = 5,
	ModelWeight = 1200,
}
-- Mythic
AnimalConfig.Hydra = {
	CashPerSecond = 40000,
	WalkSpeed = 5,
	ModelWeight = 4000,
}

return AnimalConfig
