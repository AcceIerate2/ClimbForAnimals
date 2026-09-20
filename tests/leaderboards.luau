-- Run from the project root: lune run tests/leaderboards.luau
local fs = require("@lune/fs")
local luau = require("@lune/luau")
local Color3 = require("@lune/roblox").Color3

local function signal()
	return { Fire = function() end, FireAll = function() end }
end

local config =
	luau.load(fs.readFile("src/shared/replicatedStorage/GameConfiguration/Gameplay/leaderboardConfig.luau"))()
local budget = 10
local player = { UserId = 42, Name = "Tester" }
local deps = {
	knit = {
		CreateService = function(value)
			return value
		end,
		CreateController = function(value)
			return value
		end,
		CreateSignal = signal,
	},
	Config = config,
	RebirthConfig = {
		ForSource = function(value, source)
			assert(source == "AnimalIncome")
			return value
		end,
	},
	NumberShortner = tostring,
}
local mockWorkspace = {
	GetServerTimeNow = function()
		return 100
	end,
}
local function load(path)
	local source = fs.readFile(path)
	luau.compile(source)
	source = source:gsub("local ([%w_]+) = require%([^\n]+%)", "local %1 = Dependencies.%1")
	return luau.load(source, {
		environment = {
			Dependencies = deps,
			Color3 = Color3,
			workspace = mockWorkspace,
			game = {
				GetService = function(_, name)
					if name == "DataStoreService" then
						return {
							GetRequestBudgetForRequestType = function()
								return budget
							end,
						}
					elseif name == "Players" then
						return { LocalPlayer = player }
					end
					return {}
				end,
			},
			Enum = { DataStoreRequestType = { OrderedWrite = "OrderedWrite" } },
			warn = function() end,
		},
	})()
end

local values = { Speed = 1234, CashMultiplier = 3, AllTimeCashMultiplier = 2 }
local active = true
local data = {
	GetProfile = function()
		return active and values or nil
	end,
	GetValue = function(_, _, key)
		return values[key]
	end,
}
local cash = load("src/shared/serverStorage/services/cashFlowService/init.luau")
cash.DataService = data
cash.Profiles[player] = { A = { CashPerSecond = 10 }, B = { CashPerSecond = 2.5 } }
assert(cash:GetCashPerSecond(player) == 75, "Income includes all active animals and both multipliers")
cash.Profiles[player].B = nil
assert(cash:GetCashPerSecond(player) == 60)

local service = load("src/shared/serverStorage/services/leaderboardService/init.luau")
service.Rankings = {}
service.DataService = data
service.CashFlowService = cash
service.ProfileStoreService = {
	getProfile = function()
		return {
			IsActive = function()
				return active
			end,
		}
	end,
}
local writes = {}
local fail = false
for _, key in ipairs({ "Speed", "Cash" }) do
	service.Stores[key] = {
		SetAsync = function(_, id, value)
			if fail then
				error("transient write failure")
			end
			table.insert(writes, { Key = key, Id = id, Value = value })
		end,
	}
end

service:Connect(player)
local record = service.Profiles[player]
assert(record.Values.Speed == 1234 and record.Values.Cash == 60)
values.Speed = 0 / 0
service:sample(player, record)
assert(record.Values.Speed == 0)
values.Speed = 2 ^ 54
service:sample(player, record)
assert(record.Values.Speed == 2 ^ 53 - 1)
values.Speed = 1234.9
service:sample(player, record)
assert(record.Values.Speed == 1234)
service:write(player, record)
assert(#writes == 2)
service:write(player, record)
assert(#writes == 2, "Unchanged scores do not use more writes")
values.Speed = 250 -- A rebirth lowers current Speed rather than preserving a personal best.
values.CashMultiplier = 1
service:sample(player, record)
budget = 0
service:write(player, record)
assert(#writes == 2 and record.Saved.Speed == 1234)
budget = 10
fail = true
service:write(player, record)
assert(record.Saved.Speed == 1234 and not record.Writing)
fail = false
service:write(player, record)
assert(record.Saved.Speed == 250 and record.Saved.Cash == 20)

local reads = 0
service.Stores.Speed.GetSortedAsync = function(_, ascending, pageSize)
	reads += 1
	assert(ascending == false and pageSize == 100)
	local pages = { IsFinished = false }
	function pages:GetCurrentPage()
		return self.IsFinished and { { key = "42", value = 250 } } or { { key = "99", value = 900 } }
	end
	function pages:AdvanceToNextPageAsync()
		self.IsFinished = true
	end
	return pages
end
local result = service:readBoard("Speed")
assert(result.Count == 2 and result.Complete and result.Ranks[42].Rank == 2)
config.RankLookupCount = 1
local limited = service:readBoard("Speed")
assert(limited.Count == 1 and not limited.Complete and limited.Ranks[42] == nil)
config.RankLookupCount = 1000
service.Rankings.Speed = result
assert(service:GetStats(player).Speed.RankText == "#2")
assert(reads == 2, "Personal stats use cached rankings")
service.Rankings.Cash = { Ranks = {}, PersonalValues = { [42] = 20 }, Complete = false, Count = 1000, LastValue = 100 }
assert(service:GetStats(player).Cash.RankText == "1000+")
record.Values.Cash = 200
assert(
	service:GetStats(player).Cash.RankText == "1000+" and service:GetStats(player).Cash.Value == 20,
	"Personal stats stay on the published snapshot between refreshes"
)
record.Values.Speed = 9999
assert(service:GetStats(player).Speed.Value == result.Ranks[42].Value)
assert(service:GetStats(player).Speed.RankText == "#2")
service.Rankings.Cash = { Ranks = { [42] = { Rank = 1, Value = 200 } }, Complete = true }
assert(service:GetStats(player).Cash.Value == 200 and service:GetStats(player).Cash.RankText == "#1")

service.Stores.Speed.GetSortedAsync = function()
	error("read unavailable")
end
assert(service:readBoard("Speed") == nil)
assert(service.Rankings.Speed == result, "Failed refresh keeps previous ranks")

values.Speed = 500
service:Disconnect(player)
assert(service.Profiles[player] == nil and record.Saved.Speed == 500 and record.Saved.Cash == 20)
cash:DisconnectAnimals(player)
assert(cash:GetCashPerSecond(player) == 0, "Final leaderboard snapshot survives later animal cleanup")
active = false
assert(cash:GetCashPerSecond(player) == 0)

-- Exercise actual row rendering and reuse against the authored field names.
local controller = load("src/client/playerScripts/controllers/leaderboardController/init.luau")
local clones = 0
local function row(names)
	local object = {}
	for _, name in ipairs(names) do
		object[name] = {
			IsA = function(_, class)
				return class == "TextLabel" or class == "ImageLabel"
			end,
		}
	end
	function object:FindFirstChild(name, recursive)
		if self[name] then
			return self[name]
		end
		if recursive then
			for _, child in pairs(self) do
				if type(child) == "table" and child.FindFirstChild then
					local found = child:FindFirstChild(name, true)
					if found then
						return found
					end
				end
			end
		end
	end
	return object
end
local personal = row({ "PlayerName", "Rank", "Value", "Icon" })
local template = {
	Clone = function()
		clones += 1
		return row({ "Rank", "PlayerName", "PlayerValue", "PlayerIcon" })
	end,
}
controller.Views.Cash = { Rows = {}, Template = template, ScrollingFrame = {}, MyStats = personal }
controller.Boards.Cash = { Rows = { { UserId = 42, Rank = 1, Value = 60, PlayerName = "Tester" } } }
controller.Stats.Cash = { Value = 75, RankText = "#1" }
controller:updateBoard("Cash")
local rendered = controller.Views.Cash.Rows[1]
assert(rendered.PlayerValue.Text == "$60/s" and personal.Value.Text == "$75/s")
assert(personal.Rank.Text == "#1" and personal.Icon.Image:find("id=42", 1, true))
controller:updateBoard("Cash")
assert(clones == 1, "Rows are reused between refreshes")
controller.Boards.Cash.Rows = {}
controller:updateBoard("Cash")
assert(not rendered.Visible)

-- Different GUI paths and duplicate Surface names must not hide either countdown.
local function textLabel(text)
	local label = { Text = text, Attributes = {} }
	function label:IsA(class)
		return class == "TextLabel"
	end
	function label:IsDescendantOf()
		return true
	end
	function label:GetAttribute(key)
		return self.Attributes[key]
	end
	function label:SetAttribute(key, value)
		self.Attributes[key] = value
	end
	return label
end
local speedLabel = textLabel("Updates in:")
local cashLabel = textLabel("Updating in:")
local cashTitle = textLabel("Top Earners")
local personalRank = textLabel("Updating...")
local speedModel = {
	GetDescendants = function()
		return { speedLabel }
	end,
}
local cashModel = {
	GetDescendants = function()
		return { cashTitle, personalRank, cashLabel }
	end,
}
local scoreboard = row({})
scoreboard.Speed = speedModel
scoreboard.Cash = cashModel
mockWorkspace.FindFirstChild = function(_, name)
	return name == "Scoreboard" and scoreboard or nil
end
controller.NextRefreshAt = 161
controller:updateCountdown()
assert(speedLabel.Text == "Updates in 1:01" and cashLabel.Text == "Updates in 1:01")
assert(cashTitle.Text == "Top Earners" and personalRank.Text == "Updating...")
controller.NextRefreshAt = 99
controller:updateCountdown()
assert(speedLabel.Text == "Updating..." and cashLabel.Text == "Updating...")
controller.CountdownLabels = {} -- Streaming can invalidate the cache during a refresh.
controller.NextRefreshAt = 400
controller:updateCountdown()
assert(speedLabel.Text == "Updates in 5:00" and cashLabel.Text == "Updates in 5:00")
assert(personalRank.Text == "Updating...", "Personal rank is not a countdown")

print("Leaderboard income, persistence, retries, cached ranks, departure snapshot and UI rendering checks passed.")
