-- Stamina stays at 100%; each level makes it drain over more climbed studs.
-- Reach is how high the player climbs from the lobby before hitting the tired threshold.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local staminaConfig = require(ReplicatedStorage.src.GameConfiguration.Gameplay.staminaConfig)

local Config = {
	Enabled = true,
	BaseLevel = 1,
	RequestCooldown = 0.4,
	-- Price buys that level. Biome gates: 1 Forest, 4 Winter, 7 Ocean, 10 Desert, 13 Crystal Mines,
	-- 16 Jungle, 19 Mystic Isles, 22 PreHistoric, 25 Divine Heights, 28 Celestial.
	Levels = {
		{ Reach = 230, Price = 450 }, -- 450
		{ Reach = 290, Price = 2500 }, -- 2.5K
		{ Reach = 370, Price = 4300 }, -- 4.3K
		{ Reach = 465, Price = 7500 }, -- 7.5K
		{ Reach = 585, Price = 19000 }, -- 19K
		{ Reach = 740, Price = 49000 }, -- 49K
		{ Reach = 935, Price = 130000 }, -- 130K
		{ Reach = 1110, Price = 340000 }, -- 340K
		{ Reach = 1315, Price = 920000 }, -- 920K
		{ Reach = 1560, Price = 2500000 }, -- 2.5M
		{ Reach = 1825, Price = 7200000 }, -- 7.2M
		{ Reach = 2135, Price = 21000000 }, -- 21M
		{ Reach = 2500, Price = 43000000 }, -- 43M
		{ Reach = 2820, Price = 88000000 }, -- 88M
		{ Reach = 3185, Price = 180000000 }, -- 180M
		{ Reach = 3595, Price = 370000000 }, -- 370M
		{ Reach = 4010, Price = 750000000 }, -- 750M
		{ Reach = 4480, Price = 1500000000 }, -- 1.5B
		{ Reach = 5000, Price = 3200000000 }, -- 3.2B
		{ Reach = 5455, Price = 6500000000 }, -- 6.5B
		{ Reach = 5945, Price = 13000000000 }, -- 13B
		{ Reach = 6485, Price = 27000000000 }, -- 27B
		{ Reach = 7015, Price = 56000000000 }, -- 56B
		{ Reach = 7585, Price = 110000000000 }, -- 110B
		{ Reach = 8205, Price = 230000000000 }, -- 230B
		{ Reach = 8745, Price = 480000000000 }, -- 480B
		{ Reach = 9315, Price = 2000000000000 }, -- 2T
		{ Reach = 9925, Price = 15000000000000 }, -- 15T
	},
}
Config.MaxLevel = #Config.Levels

function Config.NormalizeLevel(level: number?): number
	if type(level) ~= "number" or level ~= level or math.abs(level) == math.huge then
		return Config.BaseLevel
	end
	return math.clamp(math.floor(level), Config.BaseLevel, Config.MaxLevel)
end

-- Studs climbed per 1 stamina point, so the tired threshold lands exactly at Reach.
function Config.GetDrainInterval(level: number): number
	local reach = Config.Levels[Config.NormalizeLevel(level)].Reach
	local usable = staminaConfig.MaxStamina * (1 - staminaConfig.SlowdownThresholdPercent / 100)
	return reach / usable
end

function Config.GetPrice(level: number): number?
	level = Config.NormalizeLevel(level)
	if level >= Config.MaxLevel then
		return nil
	end
	return Config.Levels[level + 1].Price
end

function Config.LevelFromInterval(interval: number?): number
	if type(interval) ~= "number" or interval ~= interval or interval == math.huge then
		return Config.BaseLevel
	end
	for level = Config.BaseLevel, Config.MaxLevel do
		if Config.GetDrainInterval(level) >= interval then
			return level
		end
	end
	return Config.MaxLevel
end

return Config
