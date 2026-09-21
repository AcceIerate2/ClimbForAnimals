-- Roblox Services
local AnalyticsService = game:GetService("AnalyticsService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

-- Packages
local knit = require(ReplicatedStorage.src.Packages.knit)

-- Config Modules
local Config = require(script.config)

-- Constants
local Steps = {}

for index, step in ipairs(Config.Steps) do
	Steps[step.Key] = { Index = index, Name = step.Name }
end

-->
local TutorialFunnelService = knit.CreateService({
	Name = "TutorialFunnelService",
	Client = {}, -- Analytics is only recorded by trusted server progression.
})

-- Private Methods
function TutorialFunnelService:logEvent(
	player: Player,
	funnel: string,
	session: string,
	index: number,
	name: string,
	fields
)
	if RunService:IsStudio() then
		if Config.DebugInStudio then
			print(`[TutorialFunnel] {player.Name}: {funnel} / {session} / {index} / {name}`)
		end

		return
	end

	-- Analytics failures must never interrupt purchases, hatching, or tutorial progress.
	local success, reason = pcall(function()
		AnalyticsService:LogFunnelStepEvent(player, funnel, session, index, name, fields)
	end)

	if not success then
		warn(`Tutorial analytics failed for {player.UserId}: {reason}`)
	end
end

-- Public Methods
-- Mutates only the analytics table; TutorialService saves it with the gameplay state.
function TutorialFunnelService:Track(player: Player, state, nextStep: string): boolean
	if not Config.Enabled then
		return false
	end

	local nextInfo = Steps[nextStep]
	if not nextInfo and nextStep ~= "Finish" then
		return false
	end

	local progress = state.Funnels
	if not progress then
		-- Completed/migrated profiles must not appear as fresh tutorial completions.
		if nextStep == "Finish" then
			return false
		end

		progress = { Version = Config.Version, Started = {}, Completed = {}, Highest = 0 }
		state.Funnels = progress
	end

	if progress.Current == nextStep then
		return false
	end

	local session = `{player.UserId}:tutorial:{progress.Version}`
	local fields = { [Enum.AnalyticsCustomFieldKeys.CustomField02.Name] = progress.Version }
	local nextIndex = nextInfo and nextInfo.Index or #Config.Steps + 1
	local previous = progress.Current and Steps[progress.Current]

	-- Moving backwards after losing an egg is not a completion. Only record each
	-- visited step once, even if the player retries it or rejoins another server.
	if previous and nextIndex > previous.Index and not progress.Completed[progress.Current] then
		progress.Completed[progress.Current] = true
		fields[Enum.AnalyticsCustomFieldKeys.CustomField01.Name] = previous.Name
		self:logEvent(player, Config.StepFunnel, `{session}:{progress.Current}`, 2, "Completed", fields)
	end

	if nextInfo and not progress.Started[nextStep] then
		progress.Started[nextStep] = true
		fields[Enum.AnalyticsCustomFieldKeys.CustomField01.Name] = nextInfo.Name
		self:logEvent(player, Config.StepFunnel, `{session}:{nextStep}`, 1, "Started", fields)
	end

	-- A monotonic overall funnel includes every stage, ending at Tutorial complete.
	if nextIndex > progress.Highest then
		progress.Highest = nextIndex
		self:logEvent(
			player,
			Config.OverallFunnel,
			session,
			nextIndex,
			nextInfo and nextInfo.Name or "Tutorial complete",
			{ [Enum.AnalyticsCustomFieldKeys.CustomField02.Name] = progress.Version }
		)
	end

	progress.Current = nextStep
	return true
end

return TutorialFunnelService
