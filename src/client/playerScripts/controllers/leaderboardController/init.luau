-- Roblox Services
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Packages
local knit = require(ReplicatedStorage.src.Packages.knit)

-- Utility Modules
local NumberShortner = require(ReplicatedStorage.src.utility.NumberShortner)

-- Config Modules
local Config = require(ReplicatedStorage.src.GameConfiguration.Gameplay.leaderboardConfig)

-- Constants
local Player = Players.LocalPlayer
local RankColors = {
	[1] = Color3.fromRGB(255, 215, 0), -- Gold
	[2] = Color3.fromRGB(192, 192, 192), -- Silver
	[3] = Color3.fromRGB(205, 127, 50), -- Bronze
}
local DefaultRankColor = Color3.fromRGB(255, 255, 255)

-- Helper Functions
local function setText(parent: Instance, name: string, value: string)
	local label = parent:FindFirstChild(name, true)
	if label and (label:IsA("TextLabel") or label:IsA("TextButton")) then
		label.Text = value
		if name == "Rank" then
			local rank = tonumber(string.match(value, "^#(%d+)$"))
			label.TextColor3 = RankColors[rank] or DefaultRankColor
		end
	end
end

local function setIcon(parent: Instance, name: string, userId: number)
	local icon = parent:FindFirstChild(name, true)
	if icon and (icon:IsA("ImageLabel") or icon:IsA("ImageButton")) then
		icon.Image = `rbxthumb://type=AvatarHeadShot&id={userId}&w=150&h=150`
	end
end

local function formatValue(key: string, value: number?): string
	if value == nil then
		return "Loading..."
	end

	local text = NumberShortner(value)
	return key == "Cash" and `${text}/s` or text
end

-->
local LeaderboardController = knit.CreateController({
	Name = "LeaderboardController",
	Boards = {},
	Stats = {},
	Views = {},
	CountdownLabels = {},
	Version = -1,
})

-- Private Methods
function LeaderboardController:getCountdownLabels(model: Instance)
	local cached = self.CountdownLabels[model]
	if cached then
		for _, label in ipairs(cached) do
			if not label:IsDescendantOf(model) then
				cached = nil
				break
			end
		end
	end
	if cached then
		return cached
	end

	local labels = {}
	for _, descendant in ipairs(model:GetDescendants()) do
		if not descendant:IsA("TextLabel") then
			continue
		end

		local text = string.lower(descendant.Text)
		if
			descendant:GetAttribute("LeaderboardCountdown") == true
			or string.find(text, "updates in", 1, true)
			or string.find(text, "updating in", 1, true)
		then
			descendant:SetAttribute("LeaderboardCountdown", true)
			table.insert(labels, descendant)
		end
	end

	-- Retry missing labels when streamed descendants arrive; cache successful bindings.
	self.CountdownLabels[model] = #labels > 0 and labels or nil
	return labels
end

function LeaderboardController:updateCountdown()
	local scoreboard = workspace:FindFirstChild("Scoreboard")
	if not scoreboard then
		return
	end

	local remaining = self.NextRefreshAt and math.max(0, math.ceil(self.NextRefreshAt - workspace:GetServerTimeNow()))
		or 0
	local text = remaining > 0 and string.format("Updates in %d:%02d", math.floor(remaining / 60), remaining % 60)
		or "Updating..."

	for _, config in pairs(Config.Boards) do
		local model = scoreboard:FindFirstChild(config.ModelName)
		if model then
			for _, label in ipairs(self:getCountdownLabels(model)) do
				label.Text = text
			end
		end
	end
end

function LeaderboardController:updateStats(key: string)
	local view = self.Views[key]
	if not view then
		return
	end

	local stats = self.Stats[key]
	setText(view.MyStats, "PlayerName", Player.Name)
	setText(view.MyStats, "Rank", stats and stats.RankText or "Updating...")
	setText(view.MyStats, "Value", formatValue(key, stats and stats.Value))
	setIcon(view.MyStats, "Icon", Player.UserId)
end

function LeaderboardController:updateBoard(key: string)
	local view = self.Views[key]
	if not view then
		return
	end

	local board = self.Boards[key]
	local rows = board and board.Rows or {}
	for index, entry in ipairs(rows) do
		local row = view.Rows[index]
		if not row then
			row = view.Template:Clone()
			row.Name = `LeaderboardRow{index}`
			row.LayoutOrder = index
			row.Parent = view.ScrollingFrame
			view.Rows[index] = row
		end

		setText(row, "Rank", `#{entry.Rank}`)
		setText(row, "PlayerName", entry.PlayerName)
		setText(row, "PlayerValue", formatValue(key, entry.Value))
		setIcon(row, "PlayerIcon", entry.UserId)
		row.Visible = true
	end

	for index = #rows + 1, #view.Rows do
		view.Rows[index].Visible = false
	end
	self:updateStats(key)
end

function LeaderboardController:bindBoards()
	local scoreboard = workspace:FindFirstChild("Scoreboard")
	if not scoreboard then
		return
	end

	for key, config in pairs(Config.Boards) do
		local model = scoreboard:FindFirstChild(config.ModelName)
		local part = model and model:FindFirstChild("LeaderboardPart")
		local gui = part and part:FindFirstChild("SurfaceGui")
		if not gui or (self.Views[key] and self.Views[key].Gui == gui) then
			continue
		end

		local scrolling = gui:FindFirstChild("ScrollingFrame")
		local template = scrolling and scrolling:FindFirstChild("Template")
		local myStats = gui:FindFirstChild("MyStats")
		local personal = myStats and myStats:FindFirstChild("Default")
		if not template or not personal then
			continue
		end

		template.Visible = false
		scrolling.AutomaticCanvasSize = Enum.AutomaticSize.Y
		local view = { Gui = gui, ScrollingFrame = scrolling, Template = template, MyStats = personal, Rows = {} }
		self.Views[key] = view
		view.Connection = gui.AncestryChanged:Connect(function()
			if not gui:IsDescendantOf(workspace) and self.Views[key] == view then
				view.Connection:Disconnect()
				for _, row in ipairs(view.Rows) do
					row:Destroy()
				end
				self.Views[key] = nil
			end
		end)
		self:updateBoard(key)
	end
end

-- LifeCycle
function LeaderboardController:KnitInit()
	self.Service = knit.GetService("LeaderboardService")
end

function LeaderboardController:KnitStart()
	self.Service.BoardsUpdated:Connect(function(version, boards, nextRefreshAt)
		if version < self.Version then
			return
		end
		self.Version = version
		self.NextRefreshAt = nextRefreshAt
		self:updateCountdown()
		self.Boards = boards
		for key in pairs(Config.Boards) do
			self:updateBoard(key)
		end
	end)

	local statsReceived = false
	self.Service.StatsUpdated:Connect(function(stats)
		statsReceived = true
		self.Stats = stats
		for key in pairs(Config.Boards) do
			self:updateStats(key)
		end
	end)

	-- Retry binding when StreamingEnabled brings a board or its GUI into view.
	workspace.DescendantAdded:Connect(function(instance)
		if instance:IsA("TextLabel") then
			self.CountdownLabels = {}
		end
		if instance.Name ~= "SurfaceGui" and instance.Name ~= "Default" and instance.Name ~= "Template" then
			return
		end
		if self.BindingPending then
			return
		end
		self.BindingPending = true
		task.defer(function()
			self.BindingPending = false
			self:bindBoards()
		end)
	end)
	self:bindBoards()
	task.spawn(function()
		while true do
			self:updateCountdown()
			task.wait(1)
		end
	end)

	self.Service
		:GetSnapshot()
		:andThen(function(snapshot)
			if snapshot.Version >= self.Version then
				self.Version = snapshot.Version
				self.NextRefreshAt = snapshot.NextRefreshAt
				self:updateCountdown()
				self.Boards = snapshot.Boards
			end
			if not statsReceived then
				self.Stats = snapshot.Stats
			end
			for key in pairs(Config.Boards) do
				self:updateBoard(key)
			end
		end)
		:catch(warn)
end

return LeaderboardController
