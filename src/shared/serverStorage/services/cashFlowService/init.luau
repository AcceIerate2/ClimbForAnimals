-- Roblox Services
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

-- Packages
local knit = require(ReplicatedStorage.src.Packages.knit)

-- Utility Modules
local EarningCurve = require(ReplicatedStorage.src.utility.earningCurve)

-- Constants
local UpdateInterval = 0.25
local MaxOfflineSeconds = 10 * 60 * 60 -- longer absences pay nothing extra
local OfflineRateMultiplier = 0.1 -- offline pays this share of the online rate

-- Types
type AnimalIncome = {
	CashPerSecond: number,
	NextPayout: number,
}

-->
local CashFlowService = knit.CreateService({
	Name = "CashFlowService",
	Client = {
		AnimalCashUpdated = knit.CreateSignal(), -- Fire(player, referenceName, cashIncrease)
	},
	Profiles = {} :: { [Player]: { [string]: AnimalIncome } },
	OfflinePrepared = {} :: { [Player]: boolean },
})

-- Client Exposed Methods
function CashFlowService.Client:ClaimOfflineCash(player: Player)
	return self.Server:ClaimOfflineCash(player)
end

-- Private Methods
function CashFlowService:updateIncome(now: number)
	for player, animals in pairs(self.Profiles) do
		if not player.Parent or not self.DataService:GetProfile(player) then
			self:DisconnectPlayer(player)
			continue
		end

		local total = 0
		local increases = {}

		for referenceName: string, income: AnimalIncome in pairs(animals) do
			if now < income.NextPayout then
				continue
			end

			-- Catch up whole seconds after a slow frame without firing a burst
			-- of cash writes or popups for every missed second.
			local seconds = math.floor(now - income.NextPayout) + 1
			local increase = income.CashPerSecond * seconds

			income.NextPayout += seconds
			total += increase
			increases[referenceName] = increase
		end

		if total <= 0 then
			continue
		end

		self.CashService:ManipulatePlayerCash(player, total, "Addition")

		for referenceName: string, increase: number in pairs(increases) do
			self.Client.AnimalCashUpdated:Fire(player, referenceName, increase)
		end
	end
end

-- Public Methods
function CashFlowService:PrepareOfflineCash(player: Player): number
	if self.OfflinePrepared[player] or not self.DataService:GetProfile(player) then
		return 0
	end

	self.OfflinePrepared[player] = true

	local lastSeen = self.DataService:GetValue(player, "LastSeen")
	local now = os.time()
	local joinedBefore = self.DataService:GetValue(player, "JoinedBefore")

	-- Consume the previous offline period alongside the pending reward in this profile.
	-- ProfileStoreService records the next departure time when the session ends.
	self.DataService:GetValueObject(player, "LastSeen"):Set(now)
	local offlineSeconds = self.DataService:GetValueObject(player, "LastOfflineSeconds")
	offlineSeconds:Set(0)

	if not joinedBefore or typeof(lastSeen) ~= "number" or lastSeen ~= lastSeen or lastSeen <= 0 then
		return 0
	end

	local timeOffline = math.max(0, now - lastSeen)
	offlineSeconds:Set(timeOffline)

	local seconds = math.min(timeOffline, MaxOfflineSeconds)
	if seconds == 0 then
		return 0
	end

	local equippedAnimals = self.DataService:GetValue(player, "EquippedAnimals")
	local inventory = self.DataService:GetValue(player, "Inventory")
	local cashPerSecond = 0

	-- Only animals placed on the plot earn income, matching online earnings.
	for referenceName, equipped in pairs(equippedAnimals) do
		local item = inventory[referenceName]
		if not equipped or typeof(item) ~= "table" or item.Handler ~= "Animal" then
			continue
		end

		local customData = item.CustomData
		local rate = EarningCurve.GetCashPerSecond(
			item.Name,
			customData and customData.AssetScale,
			customData and customData.Variant
		)
		if rate > 0 and rate < math.huge then
			cashPerSecond += rate
		end
	end

	local reward = cashPerSecond * seconds * OfflineRateMultiplier
	if reward > 0 then
		local pending = self.DataService:GetValueObject(player, "PendingOfflineCash")
		pending:Set(pending:Get() + reward)
	end

	return reward
end

function CashFlowService:ClaimOfflineCash(player: Player)
	if not self.OfflinePrepared[player] or not self.DataService:GetProfile(player) then
		return { Status = false, Reason = "Your offline cash is still loading." }
	end

	local pending = self.DataService:GetValueObject(player, "PendingOfflineCash")
	local reward = pending:Get()
	if typeof(reward) ~= "number" or reward ~= reward or reward <= 0 or reward == math.huge then
		return { Status = false, Reason = "No offline cash to claim." }
	end

	-- Neither operation yields. Clear the saved reward before crediting it so
	-- repeated requests cannot claim the same amount twice.
	pending:Set(0)
	self.CashService:ManipulatePlayerCash(player, reward, "Addition")

	return { Status = true, Amount = reward }
end

function CashFlowService:ConnectAnimal(player: Player, referenceName: string, animalName: string)
	-- The rolled size multiplies the rate, so the item has to be resolved instead of just the name.
	local inventory = self.DataService:GetValue(player, "Inventory")
	local item = inventory and inventory[referenceName]
	local customData = item and item.CustomData
	local cashPerSecond = EarningCurve.GetCashPerSecond(
		animalName,
		customData and customData.AssetScale,
		customData and customData.Variant
	)
	if cashPerSecond ~= cashPerSecond or cashPerSecond <= 0 or cashPerSecond == math.huge then
		return
	end

	local animals = self.Profiles[player]
	if not animals then
		animals = {}
		self.Profiles[player] = animals
	end

	if animals[referenceName] then
		return
	end

	animals[referenceName] = {
		CashPerSecond = cashPerSecond,
		NextPayout = workspace:GetServerTimeNow() + 1,
	}
end

function CashFlowService:DisconnectAnimal(player: Player, referenceName: string)
	local animals = self.Profiles[player]
	if not animals then
		return
	end

	animals[referenceName] = nil

	if next(animals) == nil then
		self.Profiles[player] = nil
	end
end

function CashFlowService:DisconnectAnimals(player: Player)
	self.Profiles[player] = nil
end

function CashFlowService:DisconnectPlayer(player: Player)
	self:DisconnectAnimals(player)
	self.OfflinePrepared[player] = nil
end

-- LifeCycle
function CashFlowService:KnitInit()
	self.CashService = knit.GetService("CashService")
	self.DataService = knit.GetService("DataService")
end

function CashFlowService:KnitStart()
	local elapsed = 0

	RunService.Heartbeat:Connect(function(deltaTime: number)
		elapsed += deltaTime
		if elapsed < UpdateInterval then
			return
		end

		elapsed %= UpdateInterval
		self:updateIncome(workspace:GetServerTimeNow())
	end)

	Players.PlayerRemoving:Connect(function(player: Player)
		self:DisconnectPlayer(player)
	end)
end

return CashFlowService
