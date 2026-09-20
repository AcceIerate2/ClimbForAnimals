-- Roblox Services
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")

-- Packages
local knit = require(ReplicatedStorage.src.Packages.knit)

-- Utility Modules
local DayCycle = require(ReplicatedStorage.src.utility.dayCycle)
local PlayTween = require(ReplicatedStorage.src.utility.PlayTween)

-- Config Modules
local dayCycleConfig = require(ReplicatedStorage.src.GameConfiguration.Gameplay.dayCycleConfig)

-- Constants
local TimeCycle = ReplicatedStorage:WaitForChild("Assets"):WaitForChild("TimeCycle")
local PulseScale = 1.16
local PulseTweenInfo = TweenInfo.new(0.45, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

-->
local WallTimer = {}

-- Private Methods
function WallTimer:pulse()
	self.Scale.Scale = PulseScale
	PlayTween(self.Scale, PulseTweenInfo, { Scale = 1 })

	self.AudioController:PlaySfx("ClockTick", {
		PlayOver = true,
		Parent = SoundService,
		Volume = dayCycleConfig.TickVolume,
	})
end

-- The wall lives in TimeCycle by day and in the Workspace by night, so it is looked up in both
-- until found. Its SurfaceGui never changes parent, so one successful lookup lasts for good.
function WallTimer:resolve(): boolean
	if self.Gui then
		return true
	end

	local model = TimeCycle:FindFirstChild("NightWall") or workspace:FindFirstChild("NightWall")
	local wall = model and model:FindFirstChild("Wall")
	local gui = wall and wall:FindFirstChild("SurfaceGui")
	if not gui then
		return false
	end

	self.Gui = gui
	self.Label = gui:WaitForChild("Time")
	self.Scale = self.Label:FindFirstChildOfClass("UIScale") or Instance.new("UIScale")
	self.Scale.Parent = self.Label

	return true
end

function WallTimer:update()
	if not self:resolve() then
		return
	end

	local now = workspace:GetServerTimeNow()
	local isNight = DayCycle.IsNight(now)

	if self.Gui.Enabled ~= isNight then
		self.Gui.Enabled = isNight
	end

	if not isNight then
		self.LastTick = nil
		return
	end

	local remaining = math.max(math.ceil(DayCycle.GetPhaseTimeLeft(now)), 0)
	local text = `{remaining}S`
	if self.Label.Text ~= text then
		self.Label.Text = text
	end

	if remaining > 0 and remaining <= dayCycleConfig.TickSeconds and self.LastTick ~= remaining then
		self.LastTick = remaining
		self:pulse()
	end
end

-- Public Methods
function WallTimer:Start()
	self.AudioController = knit.GetController("AudioController")

	self:update()
	RunService.RenderStepped:Connect(function()
		self:update()
	end)
end

return WallTimer
