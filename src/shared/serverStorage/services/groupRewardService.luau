-- Roblox Services
local GroupService = game:GetService("GroupService")
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
	-- Membership as it was when the player joined the server: joining the group mid-session does
	-- not count, the player has to rejoin.
	InGroup = {} :: { [Player]: boolean },
})

-- Client Exposed Methods
function GroupRewardService.Client:ClaimReward(player: Player)
	return self.Server:ClaimReward(player)
end

-- Public Methods
-- Nothing yields here: the group check already happened on join, so this only reads the snapshot.
function GroupRewardService:ClaimReward(player: Player)
	if not self.DataService:GetProfile(player) then
		return { Status = false, Reason = "Your data is still loading." }
	end

	if self.DataService:GetValue(player, "GroupRewardClaimed") then
		return { Status = false, Reason = "You have already received your reward!" }
	end

	if not self.InGroup[player] then
		return { Status = false, Reason = "Like The Game to claim your reward!" }
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
	-- GetGroupsAsync, not IsInGroup: group membership is cached by the player's Roblox app session,
	-- so IsInGroup keeps saying false after rejoining until the app itself is restarted. This is a
	-- real web request per join, so rejoining is enough.
	local function playerAdded(player: Player)
		local success, groups = pcall(function()
			return GroupService:GetGroupsAsync(player.UserId)
		end)
		if not success then
			warn(`[GroupRewardService] Couldn't read {player.Name}'s groups: {tostring(groups)}`)
			return
		end

		for _, group in ipairs(groups) do
			if group.Id == groupConfig.GroupId then
				self.InGroup[player] = true
				break
			end
		end
	end

	for _, player in ipairs(Players:GetPlayers()) do
		task.spawn(playerAdded, player)
	end
	Players.PlayerAdded:Connect(function(player: Player)
		task.spawn(playerAdded, player)
	end)

	Players.PlayerRemoving:Connect(function(player: Player)
		self.InGroup[player] = nil
	end)
end

return GroupRewardService
