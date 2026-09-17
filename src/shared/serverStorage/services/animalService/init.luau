-- Roblox Services
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

-- Packages
local knit = require(ReplicatedStorage.src.Packages.knit)

-- Utility Modules
local getDictLength = require(ReplicatedStorage.src.utility.getDictLength)

-- Modules
local Geometry = require(script.geometry)

-- Config Modules
local animalConfig = require(ReplicatedStorage.src.GameConfiguration.Gameplay.animalConfig)

-- Constants
local AssetsFolder = ReplicatedStorage.Assets
local AnimalAssets = AssetsFolder.Animals
local random = Random.new()

-- Types
type AnimalData = {
	ReferenceName: string,
	Name: string,
	Player: Player,
	Base: Model,
	Radius: number,
	Height: number,
	From: CFrame,
	To: CFrame,
	StartedAt: number,
	Duration: number,
	NextMove: number,
	Revision: number?,
}

-->
local AnimalService = knit.CreateService({
	Name = "AnimalService",
	Client = {
		AnimalChanged = knit.CreateSignal(),
		AnimalRemoved = knit.CreateSignal(),
	},
	AnimalsToHandle = {},
	Profiles = {},
	Revision = 0,
})

-- Client Exposed Methods
function AnimalService.Client:EquipAnimal(player: Player, referenceName: string, cFrame: CFrame)
	return self.Server:EquipAnimal(player, referenceName, cFrame)
end

function AnimalService.Client:UnEquipAnimal(player: Player, referenceName: string)
	return self.Server:UnEquipAnimal(player, referenceName)
end

function AnimalService.Client:GetAnimals()
	local animals = {}
	for _, animal in pairs(self.Server.AnimalsToHandle) do
		table.insert(animals, self.Server:getAnimalState(animal))
	end

	return animals
end

-- Private Methods
function AnimalService:getValueObject(player: Player)
	return self.DataService:GetValueObject(player, "EquippedAnimals")
end

function AnimalService:getAnimalState(animal: AnimalData)
	return {
		ReferenceName = animal.ReferenceName,
		Name = animal.Name,
		OwnerId = animal.Player.UserId,
		From = animal.From,
		To = animal.To,
		StartedAt = animal.StartedAt,
		Duration = animal.Duration,
		Revision = animal.Revision,
	}
end

function AnimalService:syncAnimal(animal: AnimalData)
	self.Revision += 1
	animal.Revision = self.Revision

	self.Client.AnimalChanged:FireAll(self:getAnimalState(animal))
end

function AnimalService:disconnectAnimal(referenceName: string)
	if not self.AnimalsToHandle[referenceName] then
		return
	end

	self.AnimalsToHandle[referenceName] = nil
	self.Revision += 1
	self.Client.AnimalRemoved:FireAll(referenceName, self.Revision)
end

function AnimalService:createAnimalData(player: Player, referenceName: string, requested: CFrame?, saved: any)
	local inventory = self.DataService:GetValue(player, "Inventory")
	local item = inventory and inventory[referenceName]
	if typeof(item) ~= "table" or item.Handler ~= "Animal" or not animalConfig[item.Name] then
		return nil, "You don't own this animal!"
	end

	local asset = AnimalAssets:FindFirstChild(item.Name)
	if not asset or not asset:IsA("Model") or not asset:FindFirstChildWhichIsA("BasePart", true) then
		return nil, "This animal's rig is unavailable."
	end

	local radius, height = Geometry.GetRigDimensions(asset)
	local base = self.BaseService:GetPlayerBase(player)
	local frame, halfX, halfZ = Geometry.GetBounds(base, radius)
	if not frame then
		return nil, "Your plot has no room for this animal."
	end

	local point = Geometry.GetPlacementPoint(frame, halfX, halfZ, requested, saved)
	if not point then
		return nil, "Click inside your plot, away from the fences!"
	end

	local start = Geometry.GetGroundCFrame(frame:PointToWorldSpace(point), height)
	if not start then
		return nil, "Couldn't find the ground under your animal."
	end

	local animalData: AnimalData = {
		ReferenceName = referenceName,
		Name = item.Name,
		Player = player,
		Base = base,
		Radius = radius,
		Height = height,
		From = start,
		To = start,
		StartedAt = workspace:GetServerTimeNow(),
		Duration = 0,
		NextMove = workspace:GetServerTimeNow() + random:NextNumber(1, 3),
	}

	local placement = {
		X = point.X,
		Z = point.Z,
	}

	return animalData, nil, placement
end

function AnimalService:moveAnimal(animal: AnimalData, now: number)
	local frame, halfX, halfZ = Geometry.GetBounds(animal.Base, animal.Radius)
	animal.NextMove = now + 2
	if not frame then
		return
	end

	local point = Geometry.GetRandomPoint(frame, halfX, halfZ, random)
	local target = Geometry.GetGroundCFrame(point, animal.Height)
	if not target then
		return
	end

	local start = animal.To
	local speed = animalConfig[animal.Name].WalkSpeed or 5
	local destination, duration = Geometry.GetMovement(start, target, speed)
	if not destination then
		return
	end

	animal.From = start
	animal.To = destination
	animal.StartedAt = now
	animal.Duration = duration
	animal.NextMove = now + animal.Duration + random:NextNumber(2, 5)

	self:syncAnimal(animal)
end

-- Public Methods
function AnimalService:GetRevealCFrame(animalName: string, cFrame: CFrame): CFrame?
	local asset = AnimalAssets:FindFirstChild(animalName)
	if not asset or not asset:IsA("Model") then
		return
	end

	local _, height = Geometry.GetRigDimensions(asset)

	return Geometry.GetGroundCFrame(cFrame.Position, height)
end

function AnimalService:EquipAnimal(player: Player, referenceName: string, cFrame: CFrame)
	if self.EggHatchService:IsRevealing(player, referenceName) then
		return { Status = false, Reason = "This animal is still being revealed." }
	end

	if not self.Profiles[player] then
		return { Status = false, Reason = "Your animals are still loading." }
	end

	if typeof(referenceName) ~= "string" or not Geometry.IsValidCFrame(cFrame) then
		return { Status = false, Reason = "Invalid animal placement." }
	end

	local equipped = self:getValueObject(player):Get()
	if equipped[referenceName] then
		return { Status = false, Reason = "This animal is already placed!" }
	end

	local count = getDictLength(equipped)
	if count >= self.DataService:GetValue(player, "MaxAnimals") then
		return { Status = false, Reason = "Your plot has reached its animal limit!" }
	end

	local animal, reason, saved = self:createAnimalData(player, referenceName, cFrame)
	if not animal then
		return { Status = false, Reason = reason }
	end

	self:getValueObject(player):Update(function(mutator)
		mutator[referenceName] = saved
	end)

	self.InventoryService:RemoveTool(player, referenceName)
	self.AnimalsToHandle[referenceName] = animal
	self:syncAnimal(animal)

	return { Status = true }
end

function AnimalService:UnEquipAnimal(player: Player, referenceName: string)
	if not self.Profiles[player] or typeof(referenceName) ~= "string" then
		return { Status = false, Reason = "Invalid animal." }
	end

	local equipped = self:getValueObject(player)
	if not equipped:Get()[referenceName] then
		return { Status = false, Reason = "This animal isn't on your plot." }
	end

	-- Keep the inventory entry and its original ID/custom data throughout placement.
	self.InventoryService:StoreInBackpack(player, referenceName, "Animal")
	equipped:Update(function(mutator)
		mutator[referenceName] = nil
	end)

	self:disconnectAnimal(referenceName)

	return { Status = true }
end

function AnimalService:GiveAnimal(player: Player, animal: string)
	assert(animalConfig[animal], "Unknown animal")

	return self.InventoryService:GiveItem(player, {
		Name = animal,
		Handler = "Animal",
		CustomData = {},
	})
end

function AnimalService:RemoveAnimal(player: Player, referenceName: string)
	if not self.DataService:GetProfile(player) then
		return
	end

	self:getValueObject(player):Update(function(mutator)
		mutator[referenceName] = nil
	end)

	self:disconnectAnimal(referenceName)
	self.InventoryService:RemoveItem(player, referenceName)
end

function AnimalService:Connect(player: Player)
	self:Disconnect(player)
	self.Profiles[player] = true

	local normalized = {}
	local count = 0

	for referenceName, saved in pairs(self:getValueObject(player):Get()) do
		local animal, reason, placement = self:createAnimalData(player, referenceName, nil, saved)
		if animal and count < self.DataService:GetValue(player, "MaxAnimals") then
			count += 1
			normalized[referenceName] = placement
			self.InventoryService:RemoveTool(player, referenceName)
			self.AnimalsToHandle[referenceName] = animal
			self:syncAnimal(animal)
		else
			warn("Could not restore animal " .. referenceName .. ": " .. (reason or "plot limit reached"))
		end
	end

	-- Old boolean entries become plot-relative positions, so switching plots on
	-- rejoin works. Invalid placements remain owned and return to the backpack.
	self:getValueObject(player):Set(normalized)
	self.InventoryService:ConnectTools(player)

	return {
		Function = self.Disconnect,
		Args = {
			self,
			player,
		},
	}
end

function AnimalService:Disconnect(player: Player)
	self.Profiles[player] = nil
	for referenceName, animal in pairs(self.AnimalsToHandle) do
		if animal.Player == player then
			self:disconnectAnimal(referenceName)
		end
	end
end

-- LifeCycle
function AnimalService:KnitInit()
	self.EggHatchService = knit.GetService("EggHatchService")
	self.InventoryService = knit.GetService("InventoryService")
	self.DataService = knit.GetService("DataService")
	self.BaseService = knit.GetService("BaseService")
end

function AnimalService:KnitStart()
	local elapsed = 0

	RunService.Heartbeat:Connect(function(deltaTime: number)
		elapsed += deltaTime
		if elapsed < 0.25 then
			return
		end

		elapsed = 0

		local now = workspace:GetServerTimeNow()
		for _, animal in pairs(self.AnimalsToHandle) do
			if now >= animal.NextMove then
				self:moveAnimal(animal, now)
			end
		end
	end)
end

return AnimalService
