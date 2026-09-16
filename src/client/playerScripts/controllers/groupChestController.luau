-- Roblox Services
local GroupService = game:GetService("GroupService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Packages
local knit = require(ReplicatedStorage.src.Packages.knit)

-- Utility Modules
local InstanceCreator = require(ReplicatedStorage.src.utility.InstanceCreator)
local NumberShortner = require(ReplicatedStorage.src.utility.NumberShortner)

-- Config Modules
local groupConfig = require(ReplicatedStorage.src.GameConfiguration.General.groupConfig)

-- Constants
local Player = Players.LocalPlayer
local Chest = workspace:WaitForChild("Scoreboard"):WaitForChild("Chest")
local NotificationColors = {
	Default = Color3.fromRGB(255, 255, 255),
	Success = Color3.fromRGB(0, 255, 255),
	Failed = Color3.fromRGB(255, 60, 60),
}

-->
local GroupChestController = knit.CreateController({
	Name = "GroupChestController",
})

-- Private Methods
function GroupChestController:isInGroup(): boolean
	local success, isInGroup = pcall(function()
		return Player:IsInGroup(groupConfig.GroupId)
	end)
	return success and isInGroup
end

function GroupChestController:pushNotification(message: string, color: Color3?)
	self.NotificationController:Push({
		Message = message,
		Color = color or NotificationColors.Default,
		Sound = "Generic",
	})
end

function GroupChestController:promptJoinGroup()
	self:pushNotification("Like The Game?? + Join Group")

	pcall(function()
		GroupService:PromptJoinAsync(groupConfig.GroupId)
	end)
end

function GroupChestController:claimReward()
	local status, result = self.GroupRewardService:ClaimReward():await()
	if not status then
		warn(result)
		return
	end

	if result.Status then
		self:pushNotification(`You received Group Reward +{NumberShortner(groupConfig.RewardSpeed)} Speed!`, NotificationColors.Success)
	else
		self:pushNotification(result.Reason, NotificationColors.Failed)
	end
end

-- LifeCycle
function GroupChestController:KnitInit()
	self.GroupRewardService = knit.GetService("GroupRewardService")
	self.NotificationController = knit.GetController("NotificationController")
end

function GroupChestController:KnitStart()
	local hitbox = Chest:WaitForChild("Hitbox")
	local isInGroup = self:isInGroup()

	local prompt = InstanceCreator("ProximityPrompt", "GroupRewardPrompt", hitbox, {
		ActionText = isInGroup and "Claim Reward!" or "Join Group!",
		HoldDuration = 0,
		RequiresLineOfSight = false,
	})

	prompt.Triggered:Connect(function()
		if self:isInGroup() then
			self:claimReward()
		else
			self:promptJoinGroup()
		end
	end)
end

return GroupChestController
