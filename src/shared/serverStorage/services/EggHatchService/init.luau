-- Roblox Services
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Packages
local knit = require(ReplicatedStorage.src.Packages.knit)

-- Utility Modules
local EggHandler = require(ReplicatedStorage.src.utility.eggHandler)

-- Config Modules
local eggConfig = require(ReplicatedStorage.src.GameConfiguration.Gameplay.eggConfig)

-->
local EggHatchService = knit.CreateService({
	Name = "EggHatchService",
	PendingHatches = {},
})

-- Client Exposed Methods
function EggHatchService.Client:Hatch(player: Player, referenceName: string)
	return self.Server:Hatch(player, referenceName)
end

function EggHatchService.Client:CompleteHatch(player: Player, referenceName: string)
	return self.Server:CompleteHatch(player, referenceName)
end

-- Private Methods
function EggHatchService:validateHatch(player: Player, referenceName: string)
	if typeof(referenceName) ~= "string" or not self.DataService:GetProfile(player) then
		return false, "Your eggs are still loading."
	end

	local placedEggsVO = self.DataService:GetValueObject(player, "PlacedEggs")
	local eggData = placedEggsVO:Get()[referenceName]
	if not eggData then
		return false, "Egg was not placed"
	end

	if not eggData.CanHatch then
		return false, "Can't hatch right now!"
	end

	return true
end

-- Public Methods
function EggHatchService:Hatch(player: Player, referenceName: string)
	local validated, reason = self:validateHatch(player, referenceName)
	if not validated then
		return { Status = false, Reason = reason }
	end

	local placedEggsVO = self.DataService:GetValueObject(player, "PlacedEggs")
	local placedEggData = placedEggsVO:Get()[referenceName]
	local cFrame = self.EggPlacementService:GetEggCFrame(player, referenceName)

	local eggName = referenceName:split("_")[1]
	local eggData = eggConfig.Eggs[eggName]
	local animal = eggData.Animal

	local variant = placedEggData and placedEggData.Variant
	local revealCFrame = self.AnimalService:GetRevealCFrame(animal, cFrame, variant)
	if not revealCFrame then
		return { Status = false, Reason = "Couldn't prepare this animal's reveal." }
	end

	placedEggsVO:Update(function(mutator)
		mutator[referenceName] = nil
	end)

	-- Save ownership now, but only create a tool if placement later fails.
	local itemData = self.AnimalService:GiveAnimal(player, animal, false, {
		AssetScale = placedEggData and placedEggData.AssetScale,
		Variant = variant,
	})
	local pending = {
		EggReferenceName = referenceName,
		CFrame = cFrame,
		ReadyAt = workspace:GetServerTimeNow() + 2,
	}

	self.PendingHatches[player] = self.PendingHatches[player] or {}
	self.PendingHatches[player][itemData.ReferenceName] = pending

	-- Finish safely if the client disconnects from the effect or fails to respond.
	pending.Timeout = task.delay(15, function()
		pending.Timeout = nil
		local playerHatches = self.PendingHatches[player]
		if playerHatches and playerHatches[itemData.ReferenceName] == pending then
			self:CompleteHatch(player, itemData.ReferenceName)
		end
	end)

	-- The reveal builds the animal on the client before any server state arrives, so it needs
	-- the same display data here, otherwise it renders at the default size and variant.
	local storedItem = self.DataService:GetValue(player, "Inventory")[itemData.ReferenceName]
	local assetScale = placedEggData and placedEggData.AssetScale

	return {
		Status = true,
		ReferenceName = itemData.ReferenceName,
		AnimalName = animal,
		CFrame = revealCFrame,
		Variant = variant,
		Scale = EggHandler.GetVisualScale(assetScale),
		AssetScale = assetScale,
		Gender = storedItem and storedItem.CustomData and storedItem.CustomData.Gender,
	}
end

function EggHatchService:IsRevealing(player: Player, referenceName: string): boolean
	local pending = self.PendingHatches[player]

	return pending ~= nil and pending[referenceName] ~= nil
end

function EggHatchService:CompleteHatch(player: Player, referenceName: string)
	local playerHatches = self.PendingHatches[player]
	local pending = playerHatches and playerHatches[referenceName]
	if not pending or not self.DataService:GetProfile(player) then
		return { Status = false, Reason = "No pending animal reveal." }
	end

	if workspace:GetServerTimeNow() < pending.ReadyAt then
		return { Status = false, Reason = "The animal is still being revealed." }
	end

	playerHatches[referenceName] = nil
	if pending.Timeout then
		task.cancel(pending.Timeout)
		pending.Timeout = nil
	end

	if not next(playerHatches) then
		self.PendingHatches[player] = nil
	end

	local base = self.BaseService:GetPlayerBase(player)
	local eggs = base and base:FindFirstChild("PlacedEggs")
	local egg = eggs and eggs:FindFirstChild(pending.EggReferenceName)
	if egg then
		egg:Destroy()
	end

	local response = self.AnimalService:EquipAnimal(player, referenceName, pending.CFrame)
	if not response.Status and self.InventoryService:OwnsItem(player, referenceName) then
		self.InventoryService:StoreInBackpack(player, referenceName, "Animal")
	end

	return response
end

function EggHatchService:DisconnectPlayer(player: Player)
	local playerHatches = self.PendingHatches[player]
	self.PendingHatches[player] = nil

	for _, pending in pairs(playerHatches or {}) do
		if pending.Timeout then
			task.cancel(pending.Timeout)
			pending.Timeout = nil
		end
	end
end

-- LifeCycle
function EggHatchService:KnitInit()
	self.InventoryService = knit.GetService("InventoryService")
	self.EggPlacementService = knit.GetService("EggPlacementService")
	self.DataService = knit.GetService("DataService")
	self.BaseService = knit.GetService("BaseService")
	self.AnimalService = knit.GetService("AnimalService")
end

function EggHatchService:KnitStart()
	Players.PlayerRemoving:Connect(function(player: Player)
		self:DisconnectPlayer(player)
	end)
end

return EggHatchService
