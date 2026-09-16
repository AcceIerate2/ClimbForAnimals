-- Roblox Services
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Packages
local knit = require(ReplicatedStorage.src.Packages.knit)

-- Config Modules
local groupConfig = require(ReplicatedStorage.src.GameConfiguration.General.groupConfig)

-->
local GroupRewardService = knit.CreateService({
	Name = "GroupRewardService",
	Client = {},
})

-- Client Exposed Methods
function GroupRewardService.Client:ClaimReward(player: Player)
	return self.Server:ClaimReward(player)
end

-- Public Methods
function GroupRewardService:ClaimReward(player: Player)
	if self.DataService:GetValue(player, "GroupRewardClaimed") then
		return { Status = false, Reason = "You have already received your reward!" }
	end

	local success, isInGroup = pcall(function()
		return player:IsInGroup(groupConfig.GroupId)
	end)

	if not success or not isInGroup then
		return { Status = false, Reason = "Join the group to claim your reward!" }
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

return GroupRewardService
