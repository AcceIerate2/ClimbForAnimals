-- Roblox Services
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Packages
local knit = require(ReplicatedStorage.src.Packages.knit)

-- Config Modules
local animalConfig = require(ReplicatedStorage.src.GameConfiguration.Gameplay.animalConfig)
local eggConfig = require(ReplicatedStorage.src.GameConfiguration.Gameplay.eggConfig)
local zoneConfig = require(ReplicatedStorage.src.GameConfiguration.Gameplay.zoneConfig)
local indexRewardConfig = require(ReplicatedStorage.src.GameConfiguration.Economy.indexRewardConfig)

-- Constants
-- The climbing zones in order: a biome's depth is what sets the size of its speed reward.
local BiomeOrder = {}

for zoneName: string in pairs(zoneConfig) do
	if zoneName ~= "Lobby" then
		table.insert(BiomeOrder, zoneName)
	end
end

table.sort(BiomeOrder, function(a: string, b: string)
	return zoneConfig[a].Height < zoneConfig[b].Height
end)

-- Where each animal sits: its biome's depth plus its card slot inside that biome. The slot has
-- to agree with the card order the panel builds (indexPanel:build), so the ordering rule lives
-- here in the same shape: first egg per animal by egg name, then sorted by income and name.
local AnimalSlot = {}
do
	local depthOf = {}

	for index: number, zoneName: string in ipairs(BiomeOrder) do
		depthOf[zoneName] = index
	end

	local eggNames = {}

	for eggName: string in pairs(eggConfig.Eggs) do
		table.insert(eggNames, eggName)
	end

	table.sort(eggNames)

	local byBiome, seen = {}, {}

	for _, eggName: string in ipairs(eggNames) do
		local egg = eggConfig.Eggs[eggName]
		local animalName = egg.Animal
		if animalConfig[animalName] and depthOf[egg.Biome] and not seen[animalName] then
			seen[animalName] = true
			byBiome[egg.Biome] = byBiome[egg.Biome] or {}
			table.insert(byBiome[egg.Biome], animalName)
		end
	end

	for biome: string, animals in pairs(byBiome) do
		table.sort(animals, function(a: string, b: string)
			local incomeA, incomeB = animalConfig[a].CashPerSecond, animalConfig[b].CashPerSecond
			if incomeA == incomeB then
				return a < b
			end

			return incomeA < incomeB
		end)

		for slot: number, animalName: string in ipairs(animals) do
			AnimalSlot[animalName] = { Depth = depthOf[biome], Slot = slot, Count = #animals }
		end
	end
end

-- Helper Functions
local function validAmount(value): boolean
	return typeof(value) == "number" and value == value and value >= 0 and value < math.huge
end

-- Rounds to three significant digits so the numbers read like authored values.
local function roundNice(value: number): number
	if value < 1000 then
		return math.round(value / 10) * 10
	end

	local scale = 10 ^ (math.floor(math.log10(value)) - 2)

	return math.round(value / scale) * scale
end

-->
local IndexService = knit.CreateService({
	Name = "IndexService",
	Client = {},
})

-- Client Exposed Methods
function IndexService.Client:GetRewards()
	return self.Server:GetRewards()
end

function IndexService.Client:Claim(player: Player, animalName: string)
	return self.Server:Claim(player, animalName)
end

-- Public Methods

-- Cash is a fixed number of seconds of the animal's own income. Speed climbs card by card: the
-- biome sets the band and the card slot places the animal inside it, so two animals never pay
-- the same and every card of a deeper biome pays more than every card of the one before it.
-- Nothing is authored per animal. nil keeps the claim unavailable without consuming the reward.
function IndexService:GetReward(animalName: string): (number?, number?)
	local animal = animalConfig[animalName]
	local placement = AnimalSlot[animalName]
	if not animal or not placement then
		return nil, nil
	end

	local cash = animal.CashPerSecond * indexRewardConfig.CashSeconds
	local band = indexRewardConfig.SpeedBase * indexRewardConfig.SpeedBiomeGrowth ^ (placement.Depth - 1)
	local progress = placement.Count > 1 and (placement.Slot - 1) / (placement.Count - 1) or 0
	local factor = 1 + progress * (indexRewardConfig.SpeedSlotSpread - 1)

	return math.round(cash), roundNice(band * factor)
end

function IndexService:GetRewards()
	local rewards = {}

	for name in pairs(animalConfig) do
		local cash, speed = self:GetReward(name)
		local ready = validAmount(cash) and validAmount(speed) and (cash > 0 or speed > 0)
		rewards[name] = { Cash = ready and cash or 0, Speed = ready and speed or 0, Ready = ready }
	end

	return rewards
end

function IndexService:Discover(player: Player, animalName: string)
	if not animalConfig[animalName] or not self.DataService:GetProfile(player) then
		return
	end

	local index = self.DataService:GetValueObject(player, "AnimalIndex")
	if index:Get().Discovered[animalName] then
		return
	end

	index:Update(function(data)
		data.Discovered[animalName] = true
	end)
end

function IndexService:Claim(player: Player, animalName: string)
	if typeof(animalName) ~= "string" or not animalConfig[animalName] or not self.DataService:GetProfile(player) then
		return { Status = false, Reason = "Your index is not ready." }
	end

	local index = self.DataService:GetValueObject(player, "AnimalIndex")
	local data = index:Get()
	if not data.Discovered[animalName] then
		return { Status = false, Reason = "Discover this animal first." }
	end

	if data.Claimed[animalName] then
		return { Status = false, Reason = "You already claimed this reward." }
	end

	local cash, speed = self:GetReward(animalName)
	if not validAmount(cash) or not validAmount(speed) or (cash == 0 and speed == 0) then
		return { Status = false, Reason = "This reward is not available yet." }
	end

	-- No yields between validation, marking the claim, and granting the rewards.
	index:Update(function(saved)
		saved.Claimed[animalName] = true
	end)

	self.CashService:ManipulatePlayerCash(player, cash, "Addition", nil, "IndexRewards")
	local speedValue = self.DataService:GetValueObject(player, "Speed")
	speedValue:Set(speedValue:Get() + speed)
	return { Status = true }
end

-- LifeCycle
function IndexService:KnitInit()
	self.DataService = knit.GetService("DataService")
	self.CashService = knit.GetService("CashService")
end

return IndexService
