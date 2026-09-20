-- Roblox Services
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Packages
local knit = require(ReplicatedStorage.src.Packages.knit)

-- Utility Modules
local EarningCurve = require(ReplicatedStorage.src.utility.earningCurve)

-- Config Modules
local animalConfig = require(ReplicatedStorage.src.GameConfiguration.Gameplay.animalConfig)

-->
local AnimalLoadoutService = knit.CreateService({
	Name = "AnimalLoadoutService",
	Client = {},
	NextRequest = {},
})

-- Client Exposed Methods
function AnimalLoadoutService.Client:Request(player: Player, action: string, referenceName: string?)
	return self.Server:Request(player, action, referenceName)
end

-- Private Methods
function AnimalLoadoutService:equip(player: Player, referenceName: string)
	local animal, reason = self.AnimalService:createAnimalData(player, referenceName)
	if not animal then
		return { Status = false, Reason = reason }
	end

	return self.AnimalService:EquipAnimal(player, referenceName, animal.From)
end

function AnimalLoadoutService:equipBest(player: Player)
	local inventory = self.DataService:GetValue(player, "Inventory")
	local equipped = self.DataService:GetValue(player, "EquippedAnimals")
	local ranked = {}

	for referenceName, item in pairs(inventory) do
		if item.Handler == "Animal" and animalConfig[item.Name] then
			if self.EggHatchService:IsRevealing(player, referenceName) then
				return { Status = false, Reason = "Wait for your animal reveal to finish." }
			end

			local custom = item.CustomData or {}
			table.insert(ranked, {
				ReferenceName = referenceName,
				Income = EarningCurve.GetCashPerSecond(item.Name, custom.AssetScale, custom.Variant),
			})
		end
	end

	table.sort(ranked, function(a, b)
		if a.Income == b.Income then
			local aEquipped, bEquipped = equipped[a.ReferenceName] ~= nil, equipped[b.ReferenceName] ~= nil
			if aEquipped ~= bEquipped then
				return aEquipped
			end

			return a.ReferenceName < b.ReferenceName
		end

		return a.Income > b.Income
	end)

	if #ranked == 0 then
		return { Status = false, Reason = "You don't own any animals yet." }
	end

	local selected, placements = {}, {}
	local count = 0
	local limit = self.AnimalService:GetAnimalLimit(player)

	for _, entry in ipairs(ranked) do
		if count >= limit then
			break
		end

		local referenceName = entry.ReferenceName
		local animal = not equipped[referenceName] and self.AnimalService:createAnimalData(player, referenceName)
		if equipped[referenceName] or animal then
			selected[referenceName] = true
			if animal then
				placements[referenceName] = animal.From
			end

			count += 1
		end
	end

	if count == 0 then
		return { Status = false, Reason = "None of your animals can be placed on your plot right now." }
	end

	local changed = false

	for referenceName in pairs(equipped) do
		if not selected[referenceName] then
			local response = self.AnimalService:UnEquipAnimal(player, referenceName)
			if not response.Status then
				return response
			end

			changed = true
		end
	end

	for referenceName, placement in pairs(placements) do
		local response = self.AnimalService:EquipAnimal(player, referenceName, placement)
		if not response.Status then
			return response
		end

		changed = true
	end

	return {
		Status = true,
		Message = changed and "Your best animals are now equipped!" or "Your best animals are already equipped!",
	}
end

-- Public Methods
function AnimalLoadoutService:Request(player: Player, action: string, referenceName: string?)
	if not self.AnimalService.Profiles[player] or not self.DataService:GetProfile(player) then
		return { Status = false, Reason = "Your animals are still loading." }
	end

	if os.clock() < (self.NextRequest[player] or 0) then
		return { Status = false, Silent = true }
	end

	self.NextRequest[player] = os.clock() + 0.3

	if action == "EquipBest" then
		return self:equipBest(player)
	elseif action == "ToggleEquip" and typeof(referenceName) == "string" then
		if self.DataService:GetValue(player, "EquippedAnimals")[referenceName] then
			return self.AnimalService:UnEquipAnimal(player, referenceName)
		end

		return self:equip(player, referenceName)
	end

	return { Status = false, Reason = "Invalid animal action." }
end

-- LifeCycle
function AnimalLoadoutService:KnitInit()
	self.AnimalService = knit.GetService("AnimalService")
	self.DataService = knit.GetService("DataService")
	self.EggHatchService = knit.GetService("EggHatchService")
end

function AnimalLoadoutService:KnitStart()
	Players.PlayerRemoving:Connect(function(player)
		self.NextRequest[player] = nil
	end)
end

return AnimalLoadoutService
