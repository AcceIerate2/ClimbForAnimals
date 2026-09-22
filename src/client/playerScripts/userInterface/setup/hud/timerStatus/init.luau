-- Hud/RightMain/TimerStatus: what phase is coming and how long until it.

-- Roblox Services
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

-- Utility Modules
local DayCycle = require(ReplicatedStorage.src.utility.dayCycle)

-- Config Modules
local dayCycleConfig = require(ReplicatedStorage.src.GameConfiguration.Gameplay.dayCycleConfig)

-- Constants
local NightSoonSeconds = 25 -- the countdown turns red this close to night
local NightSoonColor = Color3.fromRGB(255, 57, 60)

-- Helper Functions
-- "04m 50s" while there are minutes left, "10s" once there are not.
local function formatCountdown(seconds: number): string
	local whole = math.max(math.ceil(seconds), 0)
	if whole < 60 then
		return `{whole}s`
	end

	return string.format("%02dm %02ds", whole // 60, whole % 60)
end

-->
local TimerStatus = {}

-- Private Methods
function TimerStatus:update()
	local now = workspace:GetServerTimeNow()
	local isNight = DayCycle.IsNight(now)

	-- The icon announces what comes NEXT; the label only carries the countdown.
	local timeLeft = DayCycle.GetPhaseTimeLeft(now)
	local text = formatCountdown(timeLeft)
	if self.Time.Text ~= text then
		self.Time.Text = text
	end

	local color = (not isNight and timeLeft <= NightSoonSeconds) and NightSoonColor or self.TimeColor
	if self.Time.TextColor3 ~= color then
		self.Time.TextColor3 = color
	end

	local icon = isNight and dayCycleConfig.DayIcon or dayCycleConfig.NightIcon
	if self.Icon.Image ~= icon then
		self.Icon.Image = icon
	end
end

-- LifeCycle
function TimerStatus:Init(player: Player)
	local main = player.PlayerGui:WaitForChild("Hud"):WaitForChild("TimerStatus"):WaitForChild("Main")
	self.Time = main:WaitForChild("Time")
	self.TimeColor = self.Time.TextColor3
	self.Icon = main:WaitForChild("Sub"):WaitForChild("Icon")

	self:update()
	RunService.RenderStepped:Connect(function()
		self:update()
	end)
end

return TimerStatus
