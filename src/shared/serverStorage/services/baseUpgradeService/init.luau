-- Roblox Services
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Packages
local knit = require(ReplicatedStorage.src.Packages.knit)

-- Utility Modules
local NumberShortner = require(ReplicatedStorage.src.utility.NumberShortner)

-- Config Modules
local baseUpgradeConfig = require(ReplicatedStorage.src.GameConfiguration.Economy.baseUpgradeConfig)

-->
local BaseUpgradeService = knit.CreateService({
	Name = "BaseUpgradeService",
})

-- Client Exposed Methods
function BaseUpgradeService.Client:RequestToUpgrade(player: Player)
	return self.Server:Upgrade(player)
end

-- Private Methods
function BaseUpgradeService:getLevel(player: Player): number
	return self.DataService:GetValue(player, "BaseLevel")
end

-- Public Methods
function BaseUpgradeService:Upgrade(player: Player)
	local currentLevel = self:getLevel(player)
	if currentLevel == #baseUpgradeConfig.Levels then
		return {
			Status = false,
			Reason = `Max Level`,
		}
	end

	local nextLevel = currentLevel + 1

	local levelConfig = baseUpgradeConfig.Levels[nextLevel]
	local upgradeCost = levelConfig.UpgradeCost
	local maxAnimals = levelConfig.MaxAnimals

	if not self.CashService:CanAfford(player, upgradeCost) then
		return {
			Status = false,
			Reason = `You need ${NumberShortner(upgradeCost - self.DataService:GetValue(player, "Cash"))} more!`,
		}
	end

	self.CashService:ManipulatePlayerCash(player, -upgradeCost, "Addition")
	self.DataService:GetValueObject(player, "BaseLevel"):Set(nextLevel)
	self.DataService:GetValueObject(player, "MaxAnimals"):Set(maxAnimals)
	local fencesAsset = self.BaseService:ToggleBaseModel(player, nextLevel)

	return {
		Status = true,
		FencesAsset = fencesAsset,
	}
end

-- LifeCycle
function BaseUpgradeService:KnitInit()
	self.DataService = knit.GetService("DataService")
	self.CashService = knit.GetService("CashService")
	self.BaseService = knit.GetService("BaseService")
end

return BaseUpgradeService
