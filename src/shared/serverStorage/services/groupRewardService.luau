-- Roblox Services
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Packages
local knit = require(ReplicatedStorage.src.Packages.knit)

-- Config Modules
local groupConfig = require(ReplicatedStorage.src.GameConfiguration.General.groupConfig)

-->
local GroupRewardService = knit.CreateService({
	Name = "GroupRewardService",
	Client = {},
	Claiming = {} :: { [Player]: boolean },
})

-- Client Exposed Methods
function GroupRewardService.Client:ClaimReward(player: Player)
	return self.Server:ClaimReward(player)
end

-- Public Methods
-- IsInGroup is a web call, so it yields: a plain check-then-set let every request queued during
-- that yield pass the check and pay the reward again. The in-flight guard rejects the extra
-- calls, and the flag is re-read after the yield and written with nothing yielding in between.
function GroupRewardService:ClaimReward(player: Player)
	if self.Claiming[player] then
		return { Status = false, Reason = "Your reward is already on the way!" }
	end

	if not self.DataService:GetProfile(player) then
		return { Status = false, Reason = "Your data is still loading." }
	end

	if self.DataService:GetValue(player, "GroupRewardClaimed") then
		return { Status = false, Reason = "You have already received your reward!" }
	end

	self.Claiming[player] = true

	local success, isInGroup = pcall(function()
		return player:IsInGroup(groupConfig.GroupId)
	end)

	self.Claiming[player] = nil

	if not success or not isInGroup then
		return { Status = false, Reason = "Join the group to claim your reward!" }
	end

	-- The player can have left, or another call can have finished, while the web call was out.
	if not self.DataService:GetProfile(player) or self.DataService:GetValue(player, "GroupRewardClaimed") then
		return { Status = false, Reason = "You have already received your reward!" }
	end

	self.DataService:GetValueObject(player, "GroupRewardClaimed"):Set(true)

	local speedVO = self.DataService:GetValueObject(player, "Speed")
	speedVO:Set(speedVO:Get() + groupConfig.RewardSpeed)

	return { Status = true }
end

-- LifeCycle
function GroupRewardService:KnitInit()
	self.DataService = knit.GetService("DataService")
end

function GroupRewardService:KnitStart()
	Players.PlayerRemoving:Connect(function(player: Player)
		self.Claiming[player] = nil
	end)
end

return GroupRewardService
