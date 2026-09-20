-- Roblox Services
local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Packages
local knit = require(ReplicatedStorage.src.Packages.knit)

-- Utility Modules
local DayCycle = require(ReplicatedStorage.src.utility.dayCycle)
local Zones = require(ReplicatedStorage.src.utility.zones)

-- Modules
local WallTimer = require(script.wallTimer)

-- Config Modules
local dayCycleConfig = require(ReplicatedStorage.src.GameConfiguration.Gameplay.dayCycleConfig)
local eggAlertConfig = require(ReplicatedStorage.src.GameConfiguration.Gameplay.eggAlertConfig)

-- Constants
local NightFolder = Lighting:WaitForChild("NightTime")
local NightSky = NightFolder:WaitForChild("NightSky")
local ColorCorrection = Lighting:WaitForChild("ColorCorrection")
local Player = Players.LocalPlayer
local WarningDuration = 1.5

-->
local DayCycleController = knit.CreateController({
	Name = "DayCycleController",
	IsNight = false,
})

-- Private Methods
function DayCycleController:notify(notification: { Message: string, Color: Color3, Sound: string? })
	self.NotificationController:Push({
		Message = notification.Message,
		Color = notification.Color,
		Sound = notification.Sound or "Generic",
	})
end

function DayCycleController:setNight(isNight: boolean)
	if self.IsNight == isNight then
		return
	end

	self.IsNight = isNight

	local day = self.DayLighting
	Lighting.Ambient = isNight and dayCycleConfig.NightAmbient or day.Ambient
	Lighting.Brightness = isNight and dayCycleConfig.NightBrightness or day.Brightness
	ColorCorrection.Brightness = isNight and dayCycleConfig.NightColorCorrection or day.ColorCorrection

	if isNight then
		self.DaySky.Parent = NightFolder
		NightSky.Parent = Lighting
		self:notify(dayCycleConfig.NightNotification)
	else
		NightSky.Parent = NightFolder
		self.DaySky.Parent = Lighting
	end

	self.MusicController:SetNight(isNight)
end

function DayCycleController:clearWarning()
	if not self.WarningId then
		return
	end

	self.NotificationController:Hide(self.WarningId)
	self.WarningId = nil
	self.WarnedSecond = nil
end

-- Only the players still outside the lobby are warned, and it is one card that counts down: the
-- previous one is hidden before the next is pushed.
function DayCycleController:warnNightStart(now: number)
	local remaining = math.ceil(DayCycle.GetPhaseTimeLeft(now))
	local character = Player.Character
	local rootPart = character and character:FindFirstChild("HumanoidRootPart")
	local shouldWarn = not self.IsNight
		and remaining >= 1
		and remaining <= dayCycleConfig.NightWarningSeconds
		and rootPart ~= nil
		and Zones.IsInClimbZone(rootPart.Position)

	if not shouldWarn then
		self:clearWarning()
		return
	end
	if self.WarnedSecond == remaining then
		return
	end

	local notification = dayCycleConfig.NightWarningNotification
	local isFirst = self.WarningId == nil
	self.WarnedSecond = remaining
	self.NotificationController:Hide(self.WarningId)
	self.WarningId = self.NotificationController:Push({
		Message = string.format(notification.Message, remaining),
		Color = notification.Color,
		Duration = WarningDuration,
		Sound = isFirst and "Generic" or nil,
	})
end

function DayCycleController:announceSpawns(alerts: { { Name: string, Biome: string, Rarity: string } })
	for _, alert in ipairs(alerts) do
		self.NotificationController:Push({
			Message = `{alert.Rarity:upper()} {alert.Name} Egg Spawned In {alert.Biome}!`,
			Rarity = alert.Rarity,
			Duration = eggAlertConfig.Duration,
			Sound = eggAlertConfig.Sound,
		})
	end
end

-- The server restocks in this same window, off the same clock, so no remote is needed.
function DayCycleController:announceRestock(now: number)
	local period = DayCycle.GetPeriodIndex(now)
	if not DayCycle.IsRestockWindow(now) or self.AnnouncedPeriod == period then
		return
	end

	self.AnnouncedPeriod = period
	self:notify(dayCycleConfig.ResetNotification)
end

-- LifeCycle
function DayCycleController:KnitInit()
	self.EggSpawnService = knit.GetService("EggSpawnService")
	self.DayCycleService = knit.GetService("DayCycleService")
	self.MusicController = knit.GetController("MusicController")
	self.NotificationController = knit.GetController("NotificationController")
	self.DaySky = Lighting:FindFirstChildOfClass("Sky")

	self.DayLighting = {
		Ambient = Lighting.Ambient,
		Brightness = Lighting.Brightness,
		ColorCorrection = ColorCorrection.Brightness,
	}
end

function DayCycleController:KnitStart()
	WallTimer:Start()

	self.EggSpawnService.RestockAlert:Connect(function(alerts)
		self:announceSpawns(alerts)
	end)

	self.DayCycleService.CaughtAtNight:Connect(function(droppedEgg)
		self:clearWarning()
		if droppedEgg then
			self:notify(dayCycleConfig.CaughtNotification)
		end
	end)

	task.spawn(function()
		while true do
			local now = workspace:GetServerTimeNow()
			self:setNight(DayCycle.IsNight(now))
			self:announceRestock(now)
			self:warnNightStart(now)

			local wait = DayCycle.GetNextBoundaryAt(now) - workspace:GetServerTimeNow()
			task.wait(math.clamp(wait, 0.05, dayCycleConfig.PollInterval))
		end
	end)
end

return DayCycleController
