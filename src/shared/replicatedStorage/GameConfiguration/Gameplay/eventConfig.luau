-- Global events. The schedule is computed from the synced server clock (utility.eventCycle), so every
-- server and every client agrees on it without any network traffic, like the day cycle.
-- Assets.Events.<Name> holds each event's Atmosphere, Sky, Music and Vfx parts.
local EventConfig = {}

EventConfig.Interval = 92 -- seconds from one event start to the next
EventConfig.Duration = 90 -- how long each event lasts (must be shorter than Interval)
EventConfig.PollInterval = 1

-- Played in this order, then it starts over.
EventConfig.Events = {
	{ Name = "Candy", Emoji = "🍬", Color = Color3.fromRGB(255, 105, 180) },
	{ Name = "Lava", Emoji = "🌋", Color = Color3.fromRGB(255, 120, 0) },
	{ Name = "Hacker", Emoji = "💻", Color = Color3.fromRGB(0, 85, 0) },
}

-- %s = emoji, %s = event name
EventConfig.StartMessage = "%s %s Event Started!"
EventConfig.EndMessage = "%s %s Event Ended!"

assert(EventConfig.Duration < EventConfig.Interval, "eventConfig: Duration must be shorter than Interval")

return EventConfig
