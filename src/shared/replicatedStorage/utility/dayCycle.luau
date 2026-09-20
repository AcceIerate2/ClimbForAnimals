-- Roblox Services
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Config Modules
local dayCycleConfig = require(ReplicatedStorage.src.GameConfiguration.Gameplay.dayCycleConfig)

local DayCycle = {}

-- Public Methods
function DayCycle.GetPeriodIndex(now: number): number
	return math.floor(now / dayCycleConfig.PeriodDuration)
end

function DayCycle.GetDayStartsAt(now: number): number
	return (DayCycle.GetPeriodIndex(now) + 1) * dayCycleConfig.PeriodDuration
end

function DayCycle.GetNightStartsAt(now: number): number
	return DayCycle.GetDayStartsAt(now) - dayCycleConfig.NightDuration
end

function DayCycle.GetTimeLeft(now: number): number
	return math.max(DayCycle.GetDayStartsAt(now) - now, 0)
end

function DayCycle.IsNight(now: number): boolean
	return DayCycle.GetTimeLeft(now) <= dayCycleConfig.NightDuration
end

function DayCycle.GetPhaseTimeLeft(now: number): number
	local timeLeft = DayCycle.GetTimeLeft(now)
	if DayCycle.IsNight(now) then
		return timeLeft
	end

	return math.max(timeLeft - dayCycleConfig.NightDuration, 0)
end

function DayCycle.IsRestockWindow(now: number): boolean
	return DayCycle.GetTimeLeft(now) <= dayCycleConfig.RestockLeadSeconds
end

-- When the phase changes next, so a watcher can sleep exactly until then.
function DayCycle.GetNextBoundaryAt(now: number): number
	if DayCycle.IsNight(now) then
		return DayCycle.GetDayStartsAt(now)
	end

	return DayCycle.GetNightStartsAt(now)
end

return DayCycle
