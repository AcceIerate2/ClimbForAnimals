-- Stamina stays at 100; upgrades increase the seconds between drain ticks.
local Config = {
	Enabled = true,
	BaseLevel = 1,
	MaxLevel = 50,
	FirstPrice = 1000000,
	PriceGrowth = 2,
	BaseDrainInterval = 1,
	DrainIntervalPerLevel = 1,
	RequestCooldown = 0.4,
	-- Indexed by the target level. Price buys that level; DrainInterval is its effect.
	Overrides = {}, -- [2] = { Price = 1000000, DrainInterval = 2 },
}

function Config.NormalizeLevel(level: number?): number
	if type(level) ~= "number" or level ~= level or math.abs(level) == math.huge then
		return Config.BaseLevel
	end
	return math.clamp(math.floor(level), Config.BaseLevel, Config.MaxLevel)
end

function Config.GetDrainInterval(level: number): number
	level = Config.NormalizeLevel(level)
	local override = Config.Overrides[level]
	return override and override.DrainInterval
		or Config.BaseDrainInterval + (level - Config.BaseLevel) * Config.DrainIntervalPerLevel
end

function Config.GetPrice(level: number): number?
	level = Config.NormalizeLevel(level)
	if level >= Config.MaxLevel then
		return nil
	end
	local override = Config.Overrides[level + 1]
	return math.round(
		override and override.Price or Config.FirstPrice * Config.PriceGrowth ^ (level - Config.BaseLevel)
	)
end

function Config.LevelFromInterval(interval: number?): number
	if type(interval) ~= "number" or interval ~= interval or interval == math.huge then
		return Config.BaseLevel
	end
	-- Migrate existing drain upgrades to the first level at least as strong.
	for level = Config.BaseLevel, Config.MaxLevel do
		if Config.GetDrainInterval(level) >= interval then
			return level
		end
	end
	return Config.MaxLevel
end

return Config
