-- Global rankings use the latest recorded stats, not personal all-time records.
local LeaderboardConfig = {
	StoreVersion = "v1",
	DisplayCount = 100,
	RankLookupCount = 100, -- MyStats shows 100+ beyond this range.
	SampleSeconds = 5,
	SaveSeconds = 60, -- Only changed whole-number scores are written.
	RefreshSeconds = 180, -- Shared global snapshot; never a datastore query per client.
	LeaveWaitSeconds = 8,
	NameCacheSeconds = 3600,
	Boards = {
		Speed = { StoreName = "Speed", ModelName = "Speed" },
		Cash = { StoreName = "CashPerSecond", ModelName = "Cash" },
	},
}

return LeaderboardConfig
