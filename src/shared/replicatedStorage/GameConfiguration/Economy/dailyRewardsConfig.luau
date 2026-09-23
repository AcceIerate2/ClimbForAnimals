-- Daily Rewards: one reward per day, claimed in order. Add Days[8], Days[9]... together with the
-- matching frames (Body/8, Body/9...) and the panel picks them up.
-- Reward types: Cash = { Amount }, Animal = { Animal, AssetScale?, Variant? }.
-- Special: the claim button stays hidden until that day is ready, so the prize is always in full view.
local DailyRewardsConfig = {
	Cooldown = 24 * 60 * 60, -- seconds between one claim and the next
	ResetIfMissed = false, -- true: skipping a whole day sends the player back to Day 1
	CashIcon = "rbxassetid://137176228612853",
	CashRarityText = "CASH",
	SpecialGradientSeconds = 3, -- a Special day's card gradient takes this long for one full turn (0 = still)
	ViewportPadding = .9, -- space around the animal in its frame: bigger = smaller animal
	Days = {
		{ Type = "Cash", Amount = 2500 },
		{ Type = "Animal", Animal = "Cat" },
		{ Type = "Animal", Animal = "Parrot" },
		{ Type = "Animal", Animal = "Capybara" },
		{ Type = "Animal", Animal = "Rosy Moth" },
		{ Type = "Animal", Animal = "Gorilla", AnimatedRarity = true },
		{ Type = "Animal", Animal = "Cerberus", Special = true },
	},
}

-- Single source of truth for server and client: which day is next and when it unlocks.
-- Day past the last one means the run is over: the rewards do not start again.
function DailyRewardsConfig.GetState(data, now: number)
	local day = type(data) == "table" and data.Day or 1
	local lastClaim = type(data) == "table" and data.LastClaim or 0
	if type(day) ~= "number" or day ~= day or day < 1 then
		day = 1
	end
	day = math.min(math.floor(day), #DailyRewardsConfig.Days + 1)

	local finished = day > #DailyRewardsConfig.Days
	if
		not finished
		and DailyRewardsConfig.ResetIfMissed
		and lastClaim > 0
		and now >= lastClaim + DailyRewardsConfig.Cooldown * 2
	then
		day = 1
	end

	local readyAt = lastClaim > 0 and lastClaim + DailyRewardsConfig.Cooldown or 0
	return { Day = day, ReadyAt = readyAt, Ready = not finished and now >= readyAt, Finished = finished }
end

return DailyRewardsConfig
