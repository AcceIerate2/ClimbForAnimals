local AnimalConfig = {}

-- One entry per animal (the egg hatches into it, see eggConfig.Eggs[egg].Animal).
-- CashPerSecond: cash the animal generates every second while placed on the base. Transposed
--   card by card from the reference game's own EarningRate tables: our biome N takes the eight
--   values of their area N (by depth, not by theme), so the biome sets the scale and the card
--   sets the place inside it. The last biome extends their ladder (1.5B / 3B / 6B). Two values
--   were nudged off their originals to keep every animal unique: Frog 180 -> 185 and
--   Triceratops 22000 -> 22500.
-- WalkSpeed: how fast it walks around the plot (cosmetic).
-- ModelWeight: the species' plausible real weight in KG at scale 1x, hand-picked like the
--   reference does (a small rare animal weighs less than a big common one on purpose).
--   KG shown for an egg OR its animal = ModelWeight * AssetScale^3 (utility.eggHandler.GetWeightKg).
-- Grouped by biome (climbing order) and by rarity.

-- ========================= Forest (height 200) =========================
-- Common
AnimalConfig.Bunny = {
	CashPerSecond = 2, -- 2/s
	WalkSpeed = 5,
	ModelWeight = 2,
}
AnimalConfig.Chicken = {
	CashPerSecond = 1, -- 1/s
	WalkSpeed = 5,
	ModelWeight = 3,
}
AnimalConfig["Guienna Pig"] = {
	CashPerSecond = 8, -- 8/s
	WalkSpeed = 5,
	ModelWeight = 1,
}
-- Uncommon
AnimalConfig["Golden Retriver"] = {
	CashPerSecond = 35, -- 35/s
	WalkSpeed = 5,
	ModelWeight = 30,
}
-- Rare
AnimalConfig.Horse = {
	CashPerSecond = 45, -- 45/s
	WalkSpeed = 5,
	ModelWeight = 500,
}
-- Epic
AnimalConfig.Llama = {
	CashPerSecond = 180, -- 180/s
	WalkSpeed = 5,
	ModelWeight = 130,
}
-- Legendary
AnimalConfig.Owl = {
	CashPerSecond = 240, -- 240/s
	WalkSpeed = 5,
	ModelWeight = 1.5,
}
AnimalConfig.Wolf = {
	CashPerSecond = 1800, -- 1.8K/s
	WalkSpeed = 5,
	ModelWeight = 40,
}

-- ========================= Winter (height 404) =========================
-- Common
AnimalConfig.Crab = {
	CashPerSecond = 3, -- 3/s
	WalkSpeed = 5,
	ModelWeight = 1,
}
AnimalConfig.Pigeon = {
	CashPerSecond = 4, -- 4/s
	WalkSpeed = 5,
	ModelWeight = 0.4,
}
-- Uncommon
AnimalConfig.Tuna = {
	CashPerSecond = 12, -- 12/s
	WalkSpeed = 5,
	ModelWeight = 250,
}
-- Rare
AnimalConfig["Sail Fish"] = {
	CashPerSecond = 60, -- 60/s
	WalkSpeed = 5,
	ModelWeight = 90,
}
AnimalConfig.stingray = {
	CashPerSecond = 260, -- 260/s
	WalkSpeed = 5,
	ModelWeight = 30,
}
-- Epic
AnimalConfig.Seal = {
	CashPerSecond = 320, -- 320/s
	WalkSpeed = 5,
	ModelWeight = 150,
}
-- Legendary
AnimalConfig["Polar Bear"] = {
	CashPerSecond = 2800, -- 2.8K/s
	WalkSpeed = 5,
	ModelWeight = 450,
}
-- Mythic
AnimalConfig.Mamoth = {
	CashPerSecond = 220000, -- 220K/s
	WalkSpeed = 5,
	ModelWeight = 6000,
}

-- ========================= Ocean (height 812) =========================
-- Common
AnimalConfig["Coral Goby"] = {
	CashPerSecond = 220, -- 220/s
	WalkSpeed = 5,
	ModelWeight = 0.3,
}
AnimalConfig["Gold Fish"] = {
	CashPerSecond = 300, -- 300/s
	WalkSpeed = 5,
	ModelWeight = 0.2,
}
-- Uncommon
AnimalConfig["Butter Fly Fish"] = {
	CashPerSecond = 790, -- 790/s
	WalkSpeed = 5,
	ModelWeight = 0.3,
}
AnimalConfig["Sea Horse"] = {
	CashPerSecond = 3600, -- 3.6K/s
	WalkSpeed = 5,
	ModelWeight = 0.2,
}
-- Rare
AnimalConfig["Box Fish"] = {
	CashPerSecond = 1450, -- 1.45K/s
	WalkSpeed = 5,
	ModelWeight = 0.5,
}
AnimalConfig["Cow Fish"] = {
	CashPerSecond = 16000, -- 16K/s
	WalkSpeed = 5,
	ModelWeight = 1,
}
-- Legendary
AnimalConfig["Puffer Fish"] = {
	CashPerSecond = 18500, -- 18.5K/s
	WalkSpeed = 5,
	ModelWeight = 2,
}
-- Mythic
AnimalConfig["Lion Fish"] = {
	CashPerSecond = 280000, -- 280K/s
	WalkSpeed = 5,
	ModelWeight = 1.2,
}

-- ========================= Desert (height 1356) =========================
-- Common
AnimalConfig.Goat = {
	CashPerSecond = 1000, -- 10K/s
	WalkSpeed = 5,
	ModelWeight = 60,
}
AnimalConfig.Lizard = {
	CashPerSecond = 4500, -- 12K/s
	WalkSpeed = 5,
	ModelWeight = 5,
}
-- Uncommon
AnimalConfig.Ostrich = {
	CashPerSecond = 15500, -- 15K/s
	WalkSpeed = 5,
	ModelWeight = 110,
}
-- Rare
AnimalConfig.Kangaroo = {
	CashPerSecond = 20000, -- 20K/s
	WalkSpeed = 5,
	ModelWeight = 70,
}
AnimalConfig.Pony = {
	CashPerSecond = 25000, -- 25K/s
	WalkSpeed = 5,
	ModelWeight = 250,
}
-- Epic
AnimalConfig.Bull = {
	CashPerSecond = 35000, -- 35K/s
	WalkSpeed = 5,
	ModelWeight = 900,
}
-- Legendary
AnimalConfig.Giraffee = {
	CashPerSecond = 50000, -- 50K/s
	WalkSpeed = 5,
	ModelWeight = 1200,
}
-- Mythic
AnimalConfig.Lion = {
	CashPerSecond = 3500000, -- 3.5M/s
	WalkSpeed = 5,
	ModelWeight = 190,
}

-- ========================= Crystal Mines (height 2172) =========================
-- Common
AnimalConfig.Hamster = {
	CashPerSecond = 15000, -- 15K/s
	WalkSpeed = 5,
	ModelWeight = 0.2,
}
AnimalConfig.Snail = {
	CashPerSecond = 18000, -- 18K/s
	WalkSpeed = 5,
	ModelWeight = 0.3,
}
-- Uncommon
AnimalConfig.Bat = {
	CashPerSecond = 25000, -- 25K/s
	WalkSpeed = 5,
	ModelWeight = 0.3,
}
-- Rare
AnimalConfig.Cat = {
	CashPerSecond = 35000, -- 35K/s
	WalkSpeed = 5,
	ModelWeight = 4.5,
}
AnimalConfig.Jellyfish = {
	CashPerSecond = 42000, -- 42K/s
	WalkSpeed = 5,
	ModelWeight = 2,
}
-- Epic
AnimalConfig.Bear = {
	CashPerSecond = 400000, -- 400K/s
	WalkSpeed = 5,
	ModelWeight = 300,
}
-- Legendary
AnimalConfig.WobbeGong = {
	CashPerSecond = 5000000, -- 5M/s
	WalkSpeed = 5,
	ModelWeight = 70,
}
-- Mythic
AnimalConfig.Moth = {
	CashPerSecond = 65000000, -- 65M/s
	WalkSpeed = 5,
	ModelWeight = 0.3,
}

-- ========================= Jungle (height 3124) =========================
-- Common
AnimalConfig.Frog = {
	CashPerSecond = 30000, -- 30K/s
	WalkSpeed = 5,
	ModelWeight = 0.5,
}
-- Uncommon
AnimalConfig.Surgeonfish = {
	CashPerSecond = 45000, -- 45K/s
	WalkSpeed = 5,
	ModelWeight = 0.6,
}
-- Rare
AnimalConfig.Turtle = {
	CashPerSecond = 60000, -- 60K/s
	WalkSpeed = 5,
	ModelWeight = 5,
}
-- Epic
AnimalConfig.Parrot = {
	CashPerSecond = 80000, -- 80K/s
	WalkSpeed = 5,
	ModelWeight = 1,
}
-- Legendary
AnimalConfig.Capybara = {
	CashPerSecond = 110000, -- 110K/s
	WalkSpeed = 5,
	ModelWeight = 60,
}
-- Mythic
AnimalConfig.Crocodile = {
	CashPerSecond = 8000000, -- 8M/s
	WalkSpeed = 5,
	ModelWeight = 400,
}
-- Divine
AnimalConfig.Gorilla = {
	CashPerSecond = 85000000, -- 85M/s
	WalkSpeed = 5,
	ModelWeight = 190,
}
-- Celestial
AnimalConfig.Elephant = {
	CashPerSecond = 100000000, -- 100M/s
	WalkSpeed = 5,
	ModelWeight = 4000,
}

-- ========================= Mystic Isles (height 4348) =========================
-- Common
AnimalConfig.Trumpet = {
	CashPerSecond = 150000, -- 150K/s
	WalkSpeed = 5,
	ModelWeight = 1,
}
-- Uncommon
AnimalConfig["Angel Fish"] = {
	CashPerSecond = 225000, -- 225K/s
	WalkSpeed = 5,
	ModelWeight = 0.5,
}
-- Rare
AnimalConfig["Moorish Idol"] = {
	CashPerSecond = 300000, -- 300K/s
	WalkSpeed = 5,
	ModelWeight = 0.5,
}
-- Epic
AnimalConfig.Koala = {
	CashPerSecond = 450000, -- 450K/s
	WalkSpeed = 5,
	ModelWeight = 12,
}
-- Legendary
AnimalConfig["Sword Fish"] = {
	CashPerSecond = 700000, -- 700K/s
	WalkSpeed = 5,
	ModelWeight = 300,
}
-- Mythic
AnimalConfig["Rosy Moth"] = {
	CashPerSecond = 9000000, -- 9M/s
	WalkSpeed = 5,
	ModelWeight = 0.3,
}
-- Divine
AnimalConfig.Snake = {
	CashPerSecond = 95000000, -- 95M/s
	WalkSpeed = 5,
	ModelWeight = 20,
}
-- Celestial
AnimalConfig.Whale = {
	CashPerSecond = 130000000, -- 130M/s
	WalkSpeed = 5,
	ModelWeight = 30000,
}

-- ========================= PreHistoric (height 5640) =========================
-- Common
AnimalConfig.Ankylosaurus = {
	CashPerSecond = 200000, -- 200K/s
	WalkSpeed = 5,
	ModelWeight = 6000,
}
-- Uncommon
AnimalConfig.Triceratops = {
	CashPerSecond = 300000, -- 300K/s
	WalkSpeed = 5,
	ModelWeight = 9000,
}
-- Rare
AnimalConfig.PLESIOSAUR = {
	CashPerSecond = 500000, -- 500K/s
	WalkSpeed = 5,
	ModelWeight = 5000,
}
-- Epic
AnimalConfig.Spinosaurus = {
	CashPerSecond = 1200000, -- 1.2M/s
	WalkSpeed = 5,
	ModelWeight = 7000,
}
-- Legendary
AnimalConfig["T-Rex"] = {
	CashPerSecond = 1500000, -- 1.5M/s
	WalkSpeed = 5,
	ModelWeight = 8000,
}
-- Mythic
AnimalConfig.Velicoraptor = {
	CashPerSecond = 25000000, -- 25M/s
	WalkSpeed = 5,
	ModelWeight = 1500,
}
-- Divine
AnimalConfig.Azhdarchid = {
	CashPerSecond = 32000000, -- 32M/s
	WalkSpeed = 5,
	ModelWeight = 250,
}
-- Celestial
AnimalConfig.Brachiosaurus = {
	CashPerSecond = 180000000, -- 180M/s
	WalkSpeed = 5,
	ModelWeight = 50000,
}

-- ========================= Divine Heights (height 7136) =========================
-- Common
AnimalConfig.Microraptor = {
	CashPerSecond = 1000000, -- 1M/s
	WalkSpeed = 5,
	ModelWeight = 300,
}
-- Uncommon
AnimalConfig.Garuda = {
	CashPerSecond = 1500000, -- 1.5M/s
	WalkSpeed = 5,
	ModelWeight = 400,
}
-- Rare
AnimalConfig.Simurgh = {
	CashPerSecond = 2200000, -- 2.2M/s
	WalkSpeed = 5,
	ModelWeight = 900,
}
-- Epic
AnimalConfig.Unicorn = {
	CashPerSecond = 3500000, -- 3.5M/s
	WalkSpeed = 5,
	ModelWeight = 600,
}
-- Legendary
AnimalConfig.Sphinx = {
	CashPerSecond = 45000000, -- 45M/s
	WalkSpeed = 5,
	ModelWeight = 1500,
}
-- Mythic
AnimalConfig.Dragon = {
	CashPerSecond = 60000000, -- 60M/s
	WalkSpeed = 5,
	ModelWeight = 14000,
}
-- Divine
AnimalConfig.Chriema = {
	CashPerSecond = 250000000, -- 250M/s
	WalkSpeed = 5,
	ModelWeight = 500,
}
-- Celestial
AnimalConfig["Fire Phoenix"] = {
	CashPerSecond = 1000000000, -- 1B/s
	WalkSpeed = 5,
	ModelWeight = 200,
}

-- ========================= Celestial (height 8632) =========================
-- Eternal
AnimalConfig.Hydra = {
	CashPerSecond = 1500000000, -- 1.5B/s
	WalkSpeed = 5,
	ModelWeight = 20000,
}
AnimalConfig.Kitsune = {
	CashPerSecond = 3000000000, -- 3B/s
	WalkSpeed = 5,
	ModelWeight = 80,
}
AnimalConfig["Red Dragon"] = {
	CashPerSecond = 6000000000, -- 6B/s
	WalkSpeed = 5,
	ModelWeight = 30000,
}
-- ========================= Exclusives (no egg) =========================
-- Rarity lives on the egg entry for every other animal; an exclusive carries its own, and
-- utility.eggHandler.GetRarity falls back to it.
AnimalConfig.Cerberus = {
	CashPerSecond = 106000000, -- 150M/s: above every Daily Rewards animal, below the Celestial tier
	WalkSpeed = 7,
	ModelWeight = 350,
	Rarity = "Exclusive",
}

return AnimalConfig
