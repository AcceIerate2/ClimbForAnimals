-- Roblox Services
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

-- Packages
local knit = require(ReplicatedStorage.src.Packages.knit)

-- Utility Modules
local getDictLength = require(ReplicatedStorage.src.utility.getDictLength)

local EggHandler = require(ReplicatedStorage.src.utility.eggHandler)

-- Modules
local Geometry = require(script.geometry)

-- Config Modules
local animalConfig = require(ReplicatedStorage.src.GameConfiguration.Gameplay.animalConfig)
local baseUpgradeConfig = require(ReplicatedStorage.src.GameConfiguration.Economy.baseUpgradeConfig)

-- Constants
local random = Random.new()
local MinPlotFraction = 0.25 -- smallest usable strip of the plot, so oversized rigs stay placeable and still walk
local EdgeOverhang = 0.5 -- share of a rig's radius allowed past the fences, so big animals use the whole plot
local FreePointAttempts = 25 -- tries to find a spot clear of the animals already placed

-- Types
type AnimalData = {
	ReferenceName: string,
	Name: string,
	Player: Player,
	Base: Model,
	Radius: number,
	Height: number,
	Variant: string?,
	Scale: number,
	AssetScale: number,
	Gender: string,
	PlacementCFrame: CFrame,
	From: CFrame,
	To: CFrame,
	StartedAt: number,
	Duration: number,
	NextMove: number,
	Revision: number?,
}

-- Helper Functions
-- Animals saved before genders existed keep a stable one derived from their reference name,
-- so it never flickers between sessions without having to rewrite the saved item.
local function resolveGender(referenceName: string, saved: string?): string
	if saved == "Male" or saved == "Female" then
		return saved
	end

	local sum = 0
	for index = 1, #referenceName do
		sum += string.byte(referenceName, index)
	end

	return sum % 2 == 0 and "Male" or "Female"
end

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
		Variant = animal.Variant,
		Scale = animal.Scale,
		AssetScale = animal.AssetScale,
		Gender = animal.Gender,
		OwnerId = animal.Player.UserId,
		PlacementCFrame = animal.PlacementCFrame,
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
	local animal = self.AnimalsToHandle[referenceName]
	if not animal then
		return
	end

	self.CashFlowService:DisconnectAnimal(animal.Player, referenceName)

	self.AnimalsToHandle[referenceName] = nil
	self.Revision += 1
	self.Client.AnimalRemoved:FireAll(referenceName, self.Revision)
end

-- Where this player's animals already stand, so a new one is not dropped on top of them.
function AnimalService:getOccupiedSpots(player: Player, frame: CFrame)
	local occupied = {}
	for _, animal in pairs(self.AnimalsToHandle) do
		if animal.Player == player then
			-- In the plot's own axes, the same space the candidate points are picked in.
			table.insert(occupied, { Position = frame:PointToObjectSpace(animal.To.Position), Radius = animal.Radius })
		end
	end

	return occupied
end

function AnimalService:createAnimalData(player: Player, referenceName: string, requested: CFrame?, saved: any)
	local inventory = self.DataService:GetValue(player, "Inventory")
	local item = inventory and inventory[referenceName]
	if typeof(item) ~= "table" or item.Handler ~= "Animal" or not animalConfig[item.Name] then
		return nil, "You don't own this animal!"
	end

	local variant = item.CustomData and item.CustomData.Variant
	-- The visual size is clamped, the weight is not: KG uses the raw rolled scale.
	local assetScale = (item.CustomData and item.CustomData.AssetScale) or 1
	local gender = resolveGender(referenceName, item.CustomData and item.CustomData.Gender)
	local asset = EggHandler.GetAnimalTemplate(item.Name, variant)
	if not asset or not asset:IsA("Model") or not asset:FindFirstChildWhichIsA("BasePart", true) then
		return nil, "This animal's rig is unavailable."
	end

	-- The animal keeps the size rolled for its egg (same clamp), so its footprint and
	-- height must scale too: radius keeps it inside the fences, height sits it on the ground.
	local scale = EggHandler.GetVisualScale(item.CustomData and item.CustomData.AssetScale)
	local radius, height = Geometry.GetRigDimensions(asset)
	radius, height = radius * scale, height * scale

	local base = self.BaseService:GetPlayerBase(player)
	local frame, halfX, halfZ = Geometry.GetBounds(base, radius * (1 - EdgeOverhang), MinPlotFraction)
	if not frame then
		return nil, "Your plot has no room for this animal."
	end

	-- A saved 0,0 means "no position": that is what placements without a click used to store, and
	-- it stacked every animal on the plot centre (other players see them standing right there).
	local hasSaved = typeof(saved) == "table"
		and Geometry.IsFiniteNumber(saved.X)
		and Geometry.IsFiniteNumber(saved.Z)
		and (saved.X ~= 0 or saved.Z ~= 0)
	local point
	if requested or hasSaved then
		point = Geometry.GetPlacementPoint(frame, halfX, halfZ, requested, saved)
	else
		point = Geometry.GetFreePoint(
			frame,
			halfX,
			halfZ,
			radius,
			self:getOccupiedSpots(player, frame),
			random,
			FreePointAttempts
		)
	end
	if not point then
		return nil, "Couldn't read where you clicked."
	end

	local start = Geometry.GetGroundCFrame(frame:PointToWorldSpace(point), height)
	if not start then
		return nil, "Couldn't find the ground under your animal."
	end

	local animalData: AnimalData = {
		ReferenceName = referenceName,
		Name = item.Name,
		Variant = variant,
		Player = player,
		Base = base,
		Radius = radius,
		Height = height,
		Scale = scale,
		AssetScale = assetScale,
		Gender = gender,
		PlacementCFrame = start,
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
	local frame, halfX, halfZ = Geometry.GetBounds(animal.Base, animal.Radius * (1 - EdgeOverhang), MinPlotFraction)
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
function AnimalService:GetAnimalLimit(player: Player): number
	local level = self.DataService:GetValue(player, "BaseLevel")
	local levelConfig = baseUpgradeConfig.Levels[level]
	return levelConfig and levelConfig.MaxAnimals or 0
end

function AnimalService:GetRevealCFrame(animalName: string, cFrame: CFrame, variant: string?): CFrame?
	local asset = EggHandler.GetAnimalTemplate(animalName, variant)
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
	if count >= self:GetAnimalLimit(player) then
		return { Status = false, Reason = "Your plot has reached its animal limit!" }
	end

	local animal, reason, saved = self:createAnimalData(player, referenceName, cFrame)
	if not animal then
		return { Status = false, Reason = reason }
	end

	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if root and root:IsA("BasePart") then
		animal.From = Geometry.GetFacingCFrame(animal.From, root.Position)
		animal.To = animal.From
	end
	animal.PlacementCFrame = animal.From

	self:getValueObject(player):Update(function(mutator)
		mutator[referenceName] = saved
	end)

	self.InventoryService:RemoveTool(player, referenceName)
	self.AnimalsToHandle[referenceName] = animal
	self:syncAnimal(animal)
	self.CashFlowService:ConnectAnimal(player, referenceName, animal.Name)

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

function AnimalService:GiveAnimal(
	player: Player,
	animal: string,
	storeInBackpack: boolean?,
	customData: { [any]: any }?
)
	assert(animalConfig[animal], "Unknown animal")

	local data = customData or {}
	if data.Gender == nil then
		data.Gender = random:NextNumber() < 0.5 and "Male" or "Female"
	end

	return self.InventoryService:GiveItem(player, {
		Name = animal,
		Handler = "Animal",
		CustomData = data,
	}, storeInBackpack)
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
	local limit = self:GetAnimalLimit(player)
	-- MaxAnimals is a replicated display value; the plot level determines capacity.
	self.DataService:GetValueObject(player, "MaxAnimals"):Set(limit)
	self.Profiles[player] = true

	local normalized = {}
	local count = 0

	for referenceName, saved in pairs(self:getValueObject(player):Get()) do
		local animal, reason, placement = self:createAnimalData(player, referenceName, nil, saved)
		if animal and count < limit then
			count += 1
			normalized[referenceName] = placement
			self.InventoryService:RemoveTool(player, referenceName)
			self.AnimalsToHandle[referenceName] = animal
			self:syncAnimal(animal)
			self.CashFlowService:ConnectAnimal(player, referenceName, animal.Name)
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
	self.CashFlowService:DisconnectAnimals(player)
	self.Profiles[player] = nil
	for referenceName, animal in pairs(self.AnimalsToHandle) do
		if animal.Player == player then
			self:disconnectAnimal(referenceName)
		end
	end
end

-- LifeCycle
function AnimalService:KnitInit()
	self.CashFlowService = knit.GetService("CashFlowService")
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
