-- Scoreboard/Events/Sign: which event comes next and when, or how long the current one lasts.

-- Roblox Services
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Utility Modules
local EventCycle = require(ReplicatedStorage.src.utility.eventCycle)
local color3ToHex = require(ReplicatedStorage.src.utility.color3ToHex)

-- Constants
local UpdateInterval = 1

-- Helper Functions
local function formatCountdown(seconds: number): string
	local whole = math.max(math.ceil(seconds), 0)
	return string.format("%02dm %02ds", whole // 60, whole % 60)
end

local function coloredName(event): string
	return `<font color="{color3ToHex(event.Color)}">{event.Name}</font>`
end

-->
local EventSign = {}

-- Private Methods
function EventSign:update()
	local now = workspace:GetServerTimeNow()
	local state = EventCycle.GetState(now)

	local text
	if state.Active then
		text = `{coloredName(state.Event)} Event Ends in: {formatCountdown(state.EndsAt - now)}`
	else
		text = `Next Event {coloredName(state.NextEvent)} Will Start in: {formatCountdown(state.NextStartsAt - now)}`
	end

	if self.Label.Text ~= text then
		self.Label.Text = text
	end
end

-- Public Methods
function EventSign:Start()
	local sign = workspace:WaitForChild("Scoreboard"):WaitForChild("Events"):WaitForChild("Sign")
	self.Label = sign:WaitForChild("Info"):WaitForChild("SurfaceGui"):WaitForChild("First")
	self.Label.RichText = true

	task.spawn(function()
		while true do
			self:update()
			task.wait(UpdateInterval)
		end
	end)
end

return EventSign
