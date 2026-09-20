-- Hud/RightMain/TimerStatus: what phase is coming and how long until it.

-- Roblox Services
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

-- Utility Modules
local DayCycle = require(ReplicatedStorage.src.utility.dayCycle)
local WaitForUiDesc = require(ReplicatedStorage.src.utility.WaitForUiDesc)

-- Config Modules
local dayCycleConfig = require(ReplicatedStorage.src.GameConfiguration.Gameplay.dayCycleConfig)

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

	-- Both label and icon announce what comes NEXT, so during the night this reads "Day in 10s"
	-- next to the day icon.
	local text = `{isNight and "Day" or "Night"} in {formatCountdown(DayCycle.GetPhaseTimeLeft(now))}`
	if self.Time.Text ~= text then
		self.Time.Text = text
	end

	local icon = isNight and dayCycleConfig.DayIcon or dayCycleConfig.NightIcon
	if self.Icon.Image ~= icon then
		self.Icon.Image = icon
	end
end

-- LifeCycle
function TimerStatus:Init(player: Player)
	local rightMain = WaitForUiDesc(player.PlayerGui:WaitForChild("Hud"), "Frame", {
		Name = "RightMain",
	})

	local container = rightMain:WaitForChild("TimerStatus")
	self.Time = container:WaitForChild("Time")
	self.Icon = container:WaitForChild("Icon")

	self:update()
	RunService.RenderStepped:Connect(function()
		self:update()
	end)
end

return TimerStatus
