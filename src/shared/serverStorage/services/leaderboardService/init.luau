-- Roblox Services
local DataStoreService = game:GetService("DataStoreService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserService = game:GetService("UserService")

-- Packages
local knit = require(ReplicatedStorage.src.Packages.knit)

-- Config Modules
local Config = require(ReplicatedStorage.src.GameConfiguration.Gameplay.leaderboardConfig)

-- Constants
local MaxScore = 2 ^ 53 - 1

-- Helper Functions
local function score(value): number
	if type(value) ~= "number" or value ~= value or value < 0 or value == math.huge then
		return 0
	end

	-- OrderedDataStore requires integers. Keep scores within exact double precision.
	return math.min(math.floor(value), MaxScore)
end

-->
local LeaderboardService = knit.CreateService({
	Name = "LeaderboardService",
	Client = {
		BoardsUpdated = knit.CreateSignal(),
		StatsUpdated = knit.CreateSignal(),
	},
	Profiles = {},
	Stores = {},
	Boards = {},
	Names = {},
	Version = 0,
})

-- Client Exposed Methods
function LeaderboardService.Client:GetSnapshot(player: Player)
	-- Only cached display data is exposed; clients cannot supply leaderboard scores.
	return {
		Version = self.Server.Version,
		NextRefreshAt = self.Server.NextRefreshAt,
		Boards = self.Server.Boards,
		Stats = self.Server:GetStats(player),
	}
end

-- Private Methods
function LeaderboardService:sample(player: Player, record)
	local profile = self.ProfileStoreService:getProfile(player)
	if not profile or not profile:IsActive() or not self.DataService:GetProfile(player) then
		return
	end

	record.Values = {
		Speed = score(self.DataService:GetValue(player, "Speed")),
		Cash = score(self.CashFlowService:GetCashPerSecond(player)),
	}
end

function LeaderboardService:write(player: Player, record)
	if record.Writing then
		return
	end

	record.Writing = true
	record.LastAttempt = os.clock()

	for key, store in pairs(self.Stores) do
		local value = record.Values[key]
		if value == nil or record.Saved[key] == value then
			continue
		end

		if DataStoreService:GetRequestBudgetForRequestType(Enum.DataStoreRequestType.OrderedWrite) < 1 then
			break
		end

		local success, message = pcall(function()
			store:SetAsync(tostring(player.UserId), value)
		end)
		if success then
			record.Saved[key] = value
		else
			warn(`[LeaderboardService] Couldn't save {key} for {player.UserId}: {message}`)
		end
	end

	record.Writing = false
end

function LeaderboardService:readBoard(key: string)
	local rows, ranks = {}, {}
	-- Freeze last published values for local players beyond the rank lookup range.
	local personalValues = {}
	for player, record in pairs(self.Profiles) do
		personalValues[player.UserId] = record.Saved[key]
	end
	local count = 0
	local lastValue
	local complete = false
	local success, message = pcall(function()
		local pages = self.Stores[key]:GetSortedAsync(false, 100)
		repeat
			local page = pages:GetCurrentPage()
			local truncated = false
			for index, item in ipairs(page) do
				count += 1
				local userId = tonumber(item.key)
				lastValue = item.value
				if userId then
					ranks[userId] = { Rank = count, Value = item.value }
					if count <= Config.DisplayCount then
						table.insert(rows, { UserId = userId, Rank = count, Value = item.value })
					end
				end
				if count >= Config.RankLookupCount then
					truncated = index < #page
					break
				end
			end

			complete = pages.IsFinished and not truncated
			if complete or count >= Config.RankLookupCount then
				break
			end
			pages:AdvanceToNextPageAsync()
		until false
	end)

	if not success then
		warn(`[LeaderboardService] Keeping cached {key} rankings: {message}`)
		return
	end

	return {
		Rows = rows,
		Ranks = ranks,
		PersonalValues = personalValues,
		Count = count,
		LastValue = lastValue,
		Complete = complete,
	}
end

function LeaderboardService:resolveNames(rows)
	local missing = {}
	local now = os.clock()
	for _, row in ipairs(rows) do
		local cached = self.Names[row.UserId]
		if not cached or now - cached.Time >= Config.NameCacheSeconds then
			table.insert(missing, row.UserId)
		end
	end

	if #missing > 0 then
		local success, users = pcall(function()
			return UserService:GetUserInfosByUserIdsAsync(missing)
		end)
		if success then
			for _, user in ipairs(users) do
				self.Names[user.Id] = { Name = user.Username, Time = now }
			end
		end
	end

	for _, row in ipairs(rows) do
		local cached = self.Names[row.UserId]
		row.PlayerName = cached and cached.Name or `User {row.UserId}`
	end
end

function LeaderboardService:refresh()
	for key in pairs(Config.Boards) do
		local result = self:readBoard(key)
		if result then
			self:resolveNames(result.Rows)
			self.Rankings[key] = result
			self.Boards[key] = { Rows = result.Rows, UpdatedAt = os.time() }
		end
	end

	-- Keep the name cache bounded to the current visible leaderboard users.
	local names = {}
	for _, board in pairs(self.Boards) do
		for _, row in ipairs(board.Rows) do
			names[row.UserId] = self.Names[row.UserId]
		end
	end
	self.Names = names
	self.Version += 1
	self.NextRefreshAt = workspace:GetServerTimeNow() + Config.RefreshSeconds
	self.Client.BoardsUpdated:FireAll(self.Version, self.Boards, self.NextRefreshAt)
	for player in pairs(self.Profiles) do
		self.Client.StatsUpdated:Fire(player, self:GetStats(player))
	end
end

-- Public Methods
function LeaderboardService:GetStats(player: Player)
	local stats = {}
	for key in pairs(Config.Boards) do
		local board = self.Rankings[key]
		local ranked = board and board.Ranks[player.UserId]
		local value = ranked and ranked.Value
			or (board and board.PersonalValues and board.PersonalValues[player.UserId])
		local rankText = "Updating..."
		-- Both fields come from the same refresh, never the live gameplay sample.
		if value ~= nil and ranked then
			rankText = `#{ranked.Rank}`
		elseif value ~= nil and board and not board.Complete and board.LastValue and value <= board.LastValue then
			rankText = `{board.Count}+`
		end

		stats[key] = { Value = value, RankText = rankText }
	end

	return stats
end

function LeaderboardService:Connect(player: Player)
	if self.Profiles[player] then
		return
	end

	local record = { Values = {}, Saved = {}, LastAttempt = -math.huge }
	self.Profiles[player] = record
	self:sample(player, record)
	self.Client.StatsUpdated:Fire(player, self:GetStats(player))
end

function LeaderboardService:Disconnect(player: Player)
	local record = self.Profiles[player]
	if not record then
		return
	end

	-- Capture before AnimalService clears the live income and before ProfileStore releases its lock.
	self.Profiles[player] = nil
	self:sample(player, record)
	local deadline = os.clock() + Config.LeaveWaitSeconds
	while record.Writing and os.clock() < deadline do
		task.wait(0.1)
	end
	if not record.Writing then
		self:write(player, record)
	end
end

-- LifeCycle
function LeaderboardService:KnitInit()
	assert(Config.DisplayCount >= 1 and Config.DisplayCount <= 100, "Leaderboard DisplayCount must be 1–100")
	assert(Config.RankLookupCount >= Config.DisplayCount, "RankLookupCount must cover all displayed rows")
	assert(
		Config.SampleSeconds > 0 and Config.SaveSeconds > 0 and Config.RefreshSeconds > 0,
		"Leaderboard intervals must be positive"
	)
	self.DataService = knit.GetService("DataService")
	self.ProfileStoreService = knit.GetService("ProfileStoreService")
	self.CashFlowService = knit.GetService("CashFlowService")
	self.Rankings = {}

	local environment = RunService:IsStudio() and "Development" or "Production"
	for key, board in pairs(Config.Boards) do
		self.Stores[key] =
			DataStoreService:GetOrderedDataStore(`Leaderboard_{environment}_{Config.StoreVersion}_{board.StoreName}`)
	end
end

function LeaderboardService:KnitStart()
	self.NextRefreshAt = workspace:GetServerTimeNow() + Config.SampleSeconds * 2
	task.spawn(function()
		while true do
			for player, record in pairs(self.Profiles) do
				self:sample(player, record)
				if not record.Writing and os.clock() - record.LastAttempt >= Config.SaveSeconds then
					task.spawn(function()
						self:write(player, record)
					end)
				end
			end
			task.wait(Config.SampleSeconds)
		end
	end)

	task.spawn(function()
		-- Give joining profiles time to publish their first scores.
		task.wait(math.max(0, self.NextRefreshAt - workspace:GetServerTimeNow()))
		while true do
			self:refresh()
			task.wait(math.max(0, self.NextRefreshAt - workspace:GetServerTimeNow()))
		end
	end)
end

return LeaderboardService
