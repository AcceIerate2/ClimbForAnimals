-- Which rarities are worth announcing to the whole server when a restock spawns them. A tier only
-- belongs here while it is rare WHERE it spawns: Eternal is every egg of the Celestial biome and
-- Legendary lands on two of every three restocks, so neither reads as an event.
local EggAlertConfig = {}

EggAlertConfig.Rarities = {
	Mythic = true,
	Divine = true,
	Celestial = true,
}

EggAlertConfig.Duration = 5
EggAlertConfig.Sound = "Generic"

return EggAlertConfig
