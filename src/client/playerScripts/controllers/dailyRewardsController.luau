-- Roblox Services
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")

-- Packages
local knit = require(ReplicatedStorage.src.Packages.knit)

-- Utility Modules
local soundHandler = require(ReplicatedStorage.src.utility.soundHandler)

-- Config Modules
local Config = require(ReplicatedStorage.src.GameConfiguration.Economy.dailyRewardsConfig)

-- Constants
local NotAvailableNotification = {
	Message = "You Can't Claim This Reward Now!",
	Color = Color3.fromRGB(255, 0, 0),
	Sound = "Decline",
}
local AlreadyClaimedNotification = {
	Message = "You Already Claimed This Reward!",
	Color = Color3.fromRGB(255, 0, 0),
	Sound = "Decline",
}
-- Played by instance, not by name: another Sfx folder has a Success of its own.
local SuccessSfx = SoundService:WaitForChild("src"):WaitForChild("Sfx"):WaitForChild("DailyRewards"):WaitForChild("Success")

-->
local DailyRewardsController = knit.CreateController({
	Name = "DailyRewardsController",
	Pending = false,
})

-- Public Methods
-- Any day card can be clicked; only the day that is next and ready actually claims.
function DailyRewardsController:ClaimDay(day: number?)
	local state = Config.GetState(self.DataController:GetValue("DailyRewards"), workspace:GetServerTimeNow())
	if type(day) == "number" and day < state.Day then
		self.NotificationController:Push(table.clone(AlreadyClaimedNotification))
		return
	end
	if day ~= state.Day or not state.Ready then
		self.NotificationController:Push(table.clone(NotAvailableNotification))
		return
	end

	self:Claim()
end

function DailyRewardsController:Claim()
	if self.Pending then
		return
	end

	self.Pending = true
	self.DailyRewardsService
		:Claim()
		:andThen(function(response)
			if response.Silent then
				return
			end

			if response.Status then
				soundHandler:play(SuccessSfx, { PlayOver = true })
			end

			self.NotificationController:Push({
				Message = response.Status and `Day {response.Day} reward claimed!` or response.Reason,
				Color = response.Status and Color3.fromRGB(80, 255, 100) or Color3.fromRGB(255, 0, 0),
				Sound = response.Status and "Generic" or "Decline",
			})
		end)
		:catch(warn)
		:finally(function()
			self.Pending = false
		end)
end

-- LifeCycle
function DailyRewardsController:KnitInit()
	self.DailyRewardsService = knit.GetService("DailyRewardsService")
	self.NotificationController = knit.GetController("NotificationController")
	self.DataController = knit.GetController("DataController")
end

return DailyRewardsController
