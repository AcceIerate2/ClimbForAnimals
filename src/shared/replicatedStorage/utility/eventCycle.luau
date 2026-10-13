-- Which event is running, and when the next one starts, from the synced server clock alone.
-- Same idea as utility.dayCycle: every server and client computes the same answer, no remotes.

-- Roblox Services
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Config Modules
local eventConfig = require(ReplicatedStorage.src.GameConfiguration.Gameplay.eventConfig)

local EventCycle = {}

function EventCycle.GetIndex(now: number): number
	return math.floor(now / eventConfig.Interval)
end

-- Event of a given cycle index, rotating through eventConfig.Events.
function EventCycle.GetEvent(index: number)
	return eventConfig.Events[index % #eventConfig.Events + 1]
end

-- Active: { Active = true, Index, Event, EndsAt }
-- Idle:   { Active = false, Index, NextEvent, NextStartsAt }
-- NextBoundaryAt is when this answer changes, so a watcher can sleep exactly until then.
function EventCycle.GetState(now: number)
	local index = EventCycle.GetIndex(now)
	local startsAt = index * eventConfig.Interval
	local endsAt = startsAt + eventConfig.Duration

	if now < endsAt then
		return {
			Active = true,
			Index = index,
			Event = EventCycle.GetEvent(index),
			EndsAt = endsAt,
			NextBoundaryAt = endsAt,
		}
	end

	local nextStartsAt = (index + 1) * eventConfig.Interval
	return {
		Active = false,
		Index = index,
		NextEvent = EventCycle.GetEvent(index + 1),
		NextStartsAt = nextStartsAt,
		NextBoundaryAt = nextStartsAt,
	}
end

return EventCycle
