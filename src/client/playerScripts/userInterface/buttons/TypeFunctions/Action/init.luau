-- Roblox Services
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Utility
local TypeCheck = require(ReplicatedStorage.src.utility.TypeCheck)

-->
local functions = {
	Fuse = require(script.fuseAction),
	UpgradeStamina = require(script.upgradeStaminaAction),
	SellAnimal = require(script.sellAnimalAction),
	SellAllAnimals = require(script.sellAllAnimalsAction),
	Rebirth = require(script.rebirthAction),
	SkipRebirth = require(script.skipRebirthAction),
	SelectIndexAnimal = require(script.selectIndexAnimalAction),
	ClaimIndexReward = require(script.claimIndexRewardAction),
	ClaimAllIndexReward = require(script.claimAllIndexRewardAction),
	ClaimDailyReward = require(script.claimDailyRewardAction),
	ToggleAnimalVisibility = require(script.toggleAnimalVisibilityAction),
	CloseAnimals = require(script.closeAnimalsAction),
	AnimalPanelAction = require(script.animalPanelAction),
	EquipBestAnimals = require(script.equipBestAnimalsAction),
	CloseEggs = require(script.closeEggsAction),
	EggPanelAction = require(script.eggPanelAction),
	GrowAllEggs = require(script.growAllEggsAction),
	ClaimOfflineCash = require(script.claimOfflineCashAction),
	ClaimTmMultiplier = require(script.claimTmMultiplierAction),
	UpgradeTreadmill = require(script.upgradeTreadmillAction),
	DeactivateTreadmill = require(script.deactivateTreadmillAction),
	UpgradeBase = require(script.upgradeBaseAction),
	SelectTrail = require(script.selectTrailAction),
	DropEgg = require(script.dropEggAction),
	ToggleEggVisibility = require(script.toggleEggVisibilityAction),
}

return function(button)
	if not button then
		return
	end

	local actionType = TypeCheck.Instance(button) and button:GetAttribute("Action") or button
	if not TypeCheck.string(actionType) then
		return
	end

	local functionToCall = functions[actionType]
	if typeof(functionToCall) ~= "function" then
		return
	end

	functionToCall(button)
end
