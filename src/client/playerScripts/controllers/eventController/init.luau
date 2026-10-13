-- Roblox Services
local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Packages
local knit = require(ReplicatedStorage.src.Packages.knit)

-- Utility Modules
local EventCycle = require(ReplicatedStorage.src.utility.eventCycle)

-- Modules
local EventSign = require(script.eventSign)

-- Config Modules
local eventConfig = require(ReplicatedStorage.src.GameConfiguration.Gameplay.eventConfig)

-- Constants
local EventAssets = ReplicatedStorage:WaitForChild("Assets"):WaitForChild("Events")

-->
local EventController = knit.CreateController({
	Name = "EventController",
})

-- Private Methods
function EventController:notify(event, message: string)
	self.NotificationController:Push({
		Message = string.format(message, event.Emoji, event.Name),
		Color = event.Color,
		Sound = "Generic",
	})
end

-- Atmosphere goes to Lighting, Sky to the DayCycleController, Music to the MusicController and
-- every Vfx part into one Workspace folder, so stop only has to undo those.
function EventController:start(event)
	local assets = EventAssets:FindFirstChild(event.Name)
	if not assets then
		warn(`[EventController] Missing Assets/Events/{event.Name}`)
		return
	end

	local atmosphere = assets:FindFirstChildOfClass("Atmosphere")
	if atmosphere then
		self.DefaultAtmosphere = Lighting:FindFirstChildOfClass("Atmosphere")
		if self.DefaultAtmosphere then
			self.DefaultAtmosphere.Parent = nil
		end
		self.Atmosphere = atmosphere:Clone()
		self.Atmosphere.Parent = Lighting
	end

	local sky = assets:FindFirstChildOfClass("Sky")
	self.DayCycleController:SetEventSky(sky and sky:Clone() or nil)

	local music = assets:FindFirstChildOfClass("Sound")
	self.MusicController:SetEventTrack(music and music:Clone() or nil)

	self.Vfx = Instance.new("Folder")
	self.Vfx.Name = "EventVfx"
	for _, child in ipairs(assets:GetChildren()) do
		if child:IsA("BasePart") or child:IsA("Model") then
			child:Clone().Parent = self.Vfx
		end
	end
	self.Vfx.Parent = workspace
end

function EventController:stop()
	if self.Atmosphere then
		self.Atmosphere:Destroy()
		self.Atmosphere = nil
	end
	if self.DefaultAtmosphere then
		self.DefaultAtmosphere.Parent = Lighting
		self.DefaultAtmosphere = nil
	end
	if self.Vfx then
		self.Vfx:Destroy()
		self.Vfx = nil
	end

	self.DayCycleController:SetEventSky(nil)
	self.MusicController:SetEventTrack(nil)
end

-- Joining mid-event applies it silently; only real transitions are announced.
function EventController:setEvent(event, announce: boolean)
	if self.Event == event then
		return
	end

	local previous = self.Event
	if previous then
		self:stop()
		if announce then
			self:notify(previous, eventConfig.EndMessage)
		end
	end

	self.Event = event
	if event then
		self:start(event)
		if announce then
			self:notify(event, eventConfig.StartMessage)
		end
	end
end

-- Public Methods
-- Testing only: pins an event by name on this client, nil goes back to the global cycle.
function EventController:ForceEvent(name: string?)
	local forced
	for _, event in ipairs(eventConfig.Events) do
		if event.Name == name then
			forced = event
		end
	end
	if name and not forced then
		warn(`[EventController] Unknown event {name}`)
		return
	end

	self.ForcedEvent = forced
	self.Forced = name ~= nil
	local state = EventCycle.GetState(workspace:GetServerTimeNow())
	self:setEvent(self.Forced and forced or (state.Active and state.Event or nil), true)
end

-- LifeCycle
function EventController:KnitInit()
	self.DayCycleController = knit.GetController("DayCycleController")
	self.MusicController = knit.GetController("MusicController")
	self.NotificationController = knit.GetController("NotificationController")
end

function EventController:KnitStart()
	EventSign:Start()

	task.spawn(function()
		local announce = false
		while true do
			local now = workspace:GetServerTimeNow()
			local state = EventCycle.GetState(now)
			if not self.Forced then
				self:setEvent(state.Active and state.Event or nil, announce)
			end
			announce = true

			local wait = state.NextBoundaryAt - workspace:GetServerTimeNow()
			task.wait(math.clamp(wait, 0.05, eventConfig.PollInterval))
		end
	end)
end

return EventController
