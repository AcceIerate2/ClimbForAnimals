-- Roblox Services
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Packages
local knit = require(ReplicatedStorage.src.Packages.knit)

-- Utility Modules
local EggHandler = require(ReplicatedStorage.src.utility.eggHandler)

-- Config Modules
local Config = require(ReplicatedStorage.src.GameConfiguration.Economy.dailyRewardsConfig)

-- Constants
local RequestCooldown = 0.5

-->
local DailyRewardsService = knit.CreateService({
	Name = "DailyRewardsService",
	Client = {},
	LastRequest = {},
})

-- One function per reward Type in the config.
local Grants = {
	Cash = function(self, player: Player, reward)
		-- The panel shows the exact amount, so no rebirth or gamepass multiplier (CashService skips DailyReward).
		self.CashService:ManipulatePlayerCash(player, reward.Amount, "Addition", nil, "DailyReward")
	end,
	Animal = function(self, player: Player, reward)
		self.AnimalService:GiveAnimal(player, reward.Animal, true, {
			AssetScale = reward.AssetScale,
			Variant = reward.Variant,
		})
		-- Exclusives have no egg, so they have no Index card to discover.
		if EggHandler.GetEggDataForAnimal(reward.Animal) then
			self.IndexService:Discover(player, reward.Animal)
		end
	end,
}

-- Client Exposed Methods
function DailyRewardsService.Client:Claim(player: Player)
	return self.Server:Claim(player)
end

-- Public Methods
function DailyRewardsService:Claim(player: Player)
	local now = os.clock()
	if now - (self.LastRequest[player] or -math.huge) < RequestCooldown then
		return { Status = false, Silent = true }
	end
	self.LastRequest[player] = now

	if not self.DataService:GetProfile(player) then
		return { Status = false, Reason = "Your data is still loading." }
	end

	local valueObject = self.DataService:GetValueObject(player, "DailyRewards")
	local state = Config.GetState(valueObject:Get(), os.time())
	if not state.Ready then
		return { Status = false, Reason = "Your next reward isn't ready yet!" }
	end

	local reward = Config.Days[state.Day]
	local grant = reward and Grants[reward.Type]
	if not grant then
		return { Status = false, Reason = "This reward isn't configured correctly." }
	end

	-- Progress is saved before the reward is given, with no yield in between, so a repeated
	-- request can never claim the same day twice.
	valueObject:Set({ Day = state.Day + 1, LastClaim = os.time() })
	grant(self, player, reward)

	return { Status = true, Day = state.Day }
end

-- LifeCycle
function DailyRewardsService:KnitInit()
	self.DataService = knit.GetService("DataService")
	self.CashService = knit.GetService("CashService")
	self.AnimalService = knit.GetService("AnimalService")
	self.IndexService = knit.GetService("IndexService")
end

function DailyRewardsService:KnitStart()
	Players.PlayerRemoving:Connect(function(player)
		self.LastRequest[player] = nil
	end)
end

return DailyRewardsService
