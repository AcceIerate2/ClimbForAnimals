-- Roblox Services
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Packages
local knit = require(ReplicatedStorage.src.Packages.knit)

-- Utility Modules
local InstanceCreator = require(ReplicatedStorage.src.utility.InstanceCreator)
local EggHandler = require(ReplicatedStorage.src.utility.eggHandler)

-- Config Modules
local eggConfig = require(ReplicatedStorage.src.GameConfiguration.Gameplay.eggConfig)
local zoneConfig = require(ReplicatedStorage.src.GameConfiguration.Gameplay.zoneConfig)

-- Constants
local EggTemplates = ReplicatedStorage:WaitForChild("Assets"):WaitForChild("Eggs")
local NestTemplate = EggTemplates:WaitForChild("Nest")
local Islands = workspace:WaitForChild("Structures"):WaitForChild("Islands")
local SpawnedEggsFolder = InstanceCreator("Folder", "SpawnedEggs", workspace)
local DefaultVariant = "Normal"
local MaxPositionAttempts = 20
local random = Random.new()
local LobbyMaxHeight = math.huge
for zoneName: string, zone in pairs(zoneConfig) do
	if zoneName ~= "Lobby" then
		LobbyMaxHeight = math.min(LobbyMaxHeight, zone.Height)
	end
end

-- Helper Functions
local function rollWeighted(entries: { any }, getWeight: (any) -> number): any
	local totalWeight = 0
	for _, entry in ipairs(entries) do
		totalWeight += getWeight(entry)
	end

	local roll = random:NextNumber() * totalWeight
	local accumulated = 0
	for _, entry in ipairs(entries) do
		accumulated += getWeight(entry)
		if roll <= accumulated then
			return entry
		end
	end

	return entries[#entries]
end

local function rollVariant(): string
	local entry = rollWeighted(eggConfig.Variants, function(variant)
		return variant.Weight
	end)

	return entry and entry.Name or DefaultVariant
end

-- Same logic as the reference: weighted tier -> uniform value inside the tier -> doubling chance
local function rollAssetScale(): number
	local tier = rollWeighted(eggConfig.ScaleTiers, function(scaleTier)
		return scaleTier.Weight
	end)

	local scale = tier.Min + random:NextNumber() * (tier.Max - tier.Min)
	while eggConfig.MaxScale >= scale * 2 and random:NextNumber() <= eggConfig.ScaleDoubleChance do
		scale *= 2
	end

	return scale
end

local function setPartsProperties(model: Model, properties: { [string]: any })
	for _, descendant in ipairs(model:GetDescendants()) do
		if descendant:IsA("BasePart") then
			for property, value in pairs(properties) do
				descendant[property] = value
			end
		end
	end
end

-->
local EggSpawnService = knit.CreateService({
	Name = "EggSpawnService",
	Client = {},
	BiomeEggs = {}, -- [biome]: { { Name: string, Data: table } }
	Eggs = {}, -- [eggId]: { Model, Nest, MainPart, Prompt, Biome, HomeCFrame (spawn spot), Carrier: Player? }
	Carriers = {}, -- [Player]: { EggId, Welds, Connections }
})

-- Client Exposed Methods
function EggSpawnService.Client:DropEgg(player: Player)
	return self.Server:DropEgg(player)
end

function EggSpawnService.Client:ClaimEgg(player: Player)
	return self.Server:ClaimEgg(player)
end

-- Private Methods
function EggSpawnService:getBiomeEggs(biome: string)
	if not self.BiomeEggs[biome] then
		local biomeEggs = {}
		for eggName: string, eggData in pairs(eggConfig.Eggs) do
			if eggData.Biome == biome then
				table.insert(biomeEggs, { Name = eggName, Data = eggData })
			end
		end
		self.BiomeEggs[biome] = biomeEggs
	end
	return self.BiomeEggs[biome]
end

function EggSpawnService:getSpawnArea(biome: string): BasePart?
	local island = Islands:FindFirstChild(biome)
	return island and island:FindFirstChild(eggConfig.SpawnAreaName)
end

-- The island's floor: eggs are spawned onto it and a carried egg may only be dropped over it.
function EggSpawnService:getIslandArea(biome: string): BasePart?
	local island = Islands:FindFirstChild(biome)
	return island and island:FindFirstChild(eggConfig.AreaName)
end

function EggSpawnService:getBiomeFolder(biome: string): Folder
	return SpawnedEggsFolder:FindFirstChild(biome) or InstanceCreator("Folder", biome, SpawnedEggsFolder)
end

function EggSpawnService:rollEgg(biome: string)
	local biomeEggs = self:getBiomeEggs(biome)
	if #biomeEggs == 0 then
		return nil
	end

	return rollWeighted(biomeEggs, function(egg)
		return egg.Data.Weight
	end)
end

function EggSpawnService:createEggModel(biome: string, eggName: string, assetScale: number, variant: string): Model?
	local eggModel = EggHandler.CreateModel(eggName, variant, assetScale)
	if not eggModel then
		return nil
	end

	setPartsProperties(eggModel, {
		Anchored = true,
		CanCollide = false,
		CanTouch = false,
		CanQuery = false,
	})

	return eggModel
end

-- Nest sized to the width the egg sits on, not to its widest point: the nest frames the egg's
-- body and whatever sticks out sideways overhangs the rim.
function EggSpawnService:createNest(eggModel: Model): Model
	local nest = NestTemplate:Clone() :: Model
	local scaleMultiplier = math.clamp(
		(EggHandler.GetSeatWidth(eggModel) * eggConfig.NestFootprintRatio) / EggHandler.GetSeatWidth(NestTemplate),
		eggConfig.MinNestScale,
		eggConfig.MaxNestScale
	)

	EggHandler.ScaleAndPivotToBottom(nest, scaleMultiplier)
	setPartsProperties(nest, {
		Anchored = true,
		CanCollide = false,
		CanTouch = false,
		CanQuery = false,
	})

	return nest
end

function EggSpawnService:findGroundCFrame(
	spawnArea: BasePart,
	radius: number,
	occupied: { { Position: Vector3, Radius: number } },
	floor: BasePart?
): CFrame?
	-- Only the island's floor counts as ground. A raycast ignores CanCollide, so filtering by
	-- exclusion let an egg land on top of whatever decorative model happened to be under the
	-- sample point (a phoenix, a fish) instead of on the island.
	local raycastParams = RaycastParams.new()
	if floor then
		raycastParams.FilterType = Enum.RaycastFilterType.Include
		raycastParams.FilterDescendantsInstances = { floor }
	else
		raycastParams.FilterType = Enum.RaycastFilterType.Exclude
		raycastParams.FilterDescendantsInstances = { spawnArea, SpawnedEggsFolder }
	end

	local halfX = math.max(spawnArea.Size.X / 2 - radius, 0)
	local halfZ = math.max(spawnArea.Size.Z / 2 - radius, 0)

	for _ = 1, MaxPositionAttempts do
		local offset = Vector3.new(random:NextNumber(-halfX, halfX), 0, random:NextNumber(-halfZ, halfZ))
		local origin = spawnArea.CFrame:PointToWorldSpace(offset) + Vector3.new(0, 50, 0)
		local result = workspace:Raycast(origin, Vector3.new(0, -100, 0), raycastParams)

		if result then
			local position = result.Position
			local isFree = true
			for _, other in ipairs(occupied) do
				local flatDistance =
					Vector3.new(position.X - other.Position.X, 0, position.Z - other.Position.Z).Magnitude
				if flatDistance < radius + other.Radius + eggConfig.EggSpacing then
					isFree = false
					break
				end
			end

			if isFree then
				return CFrame.new(position) * CFrame.Angles(0, random:NextNumber(0, math.pi * 2), 0)
			end
		end
	end

	return nil
end

function EggSpawnService:createPrompt(eggId: string, mainPart: BasePart): ProximityPrompt
	local prompt = InstanceCreator("ProximityPrompt", "StealPrompt", mainPart, {
		ActionText = eggConfig.StealPrompt.ActionText,
		HoldDuration = eggConfig.StealPrompt.HoldDuration,
		MaxActivationDistance = eggConfig.StealPrompt.MaxActivationDistance,
		RequiresLineOfSight = false,
	}) :: ProximityPrompt

	prompt.Triggered:Connect(function(player: Player)
		self:StealEgg(player, eggId)
	end)

	return prompt
end

function EggSpawnService:registerEgg(
	eggModel: Model,
	nest: Model,
	biome: string,
	egg,
	assetScale: number,
	variant: string
)
	local eggId = HttpService:GenerateGUID(false)
	local mainPart = eggModel.PrimaryPart

	eggModel:SetAttribute("EggId", eggId)
	eggModel:SetAttribute("EggName", egg.Name)
	eggModel:SetAttribute("Biome", biome)
	eggModel:SetAttribute("Variant", variant)
	eggModel:SetAttribute("Rarity", egg.Data.Rarity)
	eggModel:SetAttribute("AssetScale", assetScale)
	eggModel:SetAttribute("WeightKg", EggHandler.GetWeightKg(egg.Name, assetScale))

	self.Eggs[eggId] = {
		Model = eggModel,
		Nest = nest,
		MainPart = mainPart,
		Prompt = self:createPrompt(eggId, mainPart),
		Biome = biome,
		HomeCFrame = eggModel:GetPivot(),
		Carrier = nil,
	}
end

-- Places the egg anchored at a CFrame (bottom of the egg) and makes it stealable again
function EggSpawnService:placeEgg(eggData, cFrame: CFrame)
	setPartsProperties(eggData.Model, {
		Anchored = true,
		Massless = false,
	})
	eggData.Model:PivotTo(cFrame)
	eggData.Prompt.Enabled = true
end

function EggSpawnService:releaseCarrier(player: Player)
	local carrierData = self.Carriers[player]
	if not carrierData then
		return nil
	end

	self.Carriers[player] = nil
	for _, connection in ipairs(carrierData.Connections) do
		connection:Disconnect()
	end
	for _, weld in ipairs(carrierData.Welds) do
		weld:Destroy()
	end
	player:SetAttribute("CarryingEgg", nil)

	local eggData = self.Eggs[carrierData.EggId]
	if eggData then
		eggData.Carrier = nil
	end
	return eggData
end

function EggSpawnService:returnEgg(player: Player)
	local eggData = self:releaseCarrier(player)
	if eggData then
		self:placeEgg(eggData, eggData.HomeCFrame)
	end
end

function EggSpawnService:isInsideDropArea(biome: string, position: Vector3): boolean
	local dropArea = self:getIslandArea(biome)
	if not dropArea then
		return false
	end

	local localPosition = dropArea.CFrame:PointToObjectSpace(position)
	local halfSize = dropArea.Size / 2
	return math.abs(localPosition.X) <= halfSize.X
		and math.abs(localPosition.Z) <= halfSize.Z
		and localPosition.Y >= -halfSize.Y
		and localPosition.Y <= halfSize.Y + eggConfig.DropAreaHeight
end

-- Public Methods
function EggSpawnService:SpawnCycle(biome: string): number
	local spawnArea = self:getSpawnArea(biome)
	if not spawnArea then
		return 0
	end

	local floor = self:getIslandArea(biome)
	local biomeFolder = self:getBiomeFolder(biome)
	local occupied = {}
	for _, child in ipairs(biomeFolder:GetChildren()) do
		table.insert(occupied, { Position = child:GetPivot().Position, Radius = EggHandler.GetFootprint(child) / 2 })
	end

	local spawned = 0
	for _ = 1, eggConfig.EggsPerCycle do
		local egg = self:rollEgg(biome)
		local assetScale = rollAssetScale()
		local variant = rollVariant()
		local eggModel = egg and self:createEggModel(biome, egg.Name, assetScale, variant)
		if not eggModel then
			continue
		end

		local nest = self:createNest(eggModel)
		local radius = math.max(EggHandler.GetFootprint(eggModel), EggHandler.GetFootprint(nest)) / 2
		local groundCFrame = self:findGroundCFrame(spawnArea, radius, occupied, floor)
		if not groundCFrame then
			eggModel:Destroy()
			nest:Destroy()
			continue
		end

		nest:PivotTo(groundCFrame)
		local spot = nest:FindFirstChild("EggSpotBottom", true)
		local eggCFrame = spot and (CFrame.new(spot.Position) * groundCFrame.Rotation) or groundCFrame
		eggModel:PivotTo(eggCFrame)

		nest.Parent = biomeFolder
		eggModel.Parent = biomeFolder
		self:registerEgg(eggModel, nest, biome, egg, assetScale, variant)

		table.insert(occupied, { Position = groundCFrame.Position, Radius = radius })
		spawned += 1
	end

	return spawned
end

function EggSpawnService:StealEgg(player: Player, eggId: string)
	if player.Character and player.Character:GetAttribute("GuardStunned") then
		return false
	end
	local eggData = self.Eggs[eggId]
	if not eggData or eggData.Carrier or self.Carriers[player] then
		return false
	end

	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local torso = character and character:FindFirstChild("UpperTorso")
	if not humanoid or humanoid.Health <= 0 or not torso then
		return false
	end

	local distance = (torso.Position - eggData.MainPart.Position).Magnitude
	if distance > eggConfig.StealPrompt.MaxActivationDistance + 10 then
		return false
	end

	humanoid:UnequipTools()
	eggData.Carrier = player
	eggData.Prompt.Enabled = false

	-- Same bottom-anchored placement as the reference (EggToolDisplay.positionModel)
	local eggModel = eggData.Model
	local pivot = eggModel:GetPivot()
	local minBound, maxBound = EggHandler.GetVisibleBounds(eggModel, pivot)
	local center = (minBound + maxBound) / 2
	local holdPoint = Vector3.new(center.X, minBound.Y, center.Z + (maxBound.Z - minBound.Z) * 0.1)
	eggModel:PivotTo(torso.CFrame * eggConfig.CarryOffset * CFrame.new(-holdPoint))

	local welds = {}
	for _, descendant in ipairs(eggModel:GetDescendants()) do
		if descendant:IsA("BasePart") then
			descendant.Massless = true
			descendant.Anchored = false
			table.insert(
				welds,
				InstanceCreator("WeldConstraint", "CarryWeld", descendant, {
					Part0 = torso,
					Part1 = descendant,
				})
			)
		end
	end

	self.Carriers[player] = {
		EggId = eggId,
		Welds = welds,
		Connections = {
			humanoid.Died:Connect(function()
				self:returnEgg(player)
			end),
			player.CharacterRemoving:Connect(function()
				self:returnEgg(player)
			end),
		},
	}
	player:SetAttribute("CarryingEgg", eggId)

	return true
end

-- Server-only capture path: retain the capture X/Z rather than returning an egg home
-- when the protected area differs from its normal manual-drop area.
function EggSpawnService:DropCapturedEgg(player: Player, position: Vector3, ignored: { Instance })
	local carrier = self.Carriers[player]
	if not carrier then
		return { Status = true, Dropped = false }
	end
	local eggData = self.Eggs[carrier.EggId]
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not eggData or not root then
		return { Status = false }
	end
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	local excluded = { character, SpawnedEggsFolder }
	-- Solid Area parts may be the actual floor. Only exclude noncollidable zone markers.
	for _, part in ipairs(ignored) do
		if part:IsA("BasePart") and not part.CanCollide then
			table.insert(excluded, part)
		end
	end
	params.FilterDescendantsInstances = excluded
	params.RespectCanCollide = true
	local result = workspace:Raycast(position + Vector3.yAxis * 2, Vector3.new(0, -60, 0), params)
	if not result then
		return { Status = false, Reason = "No ground at the capture position." }
	end
	self:releaseCarrier(player)
	local _, yaw = root.CFrame:ToOrientation()
	self:placeEgg(eggData, CFrame.new(position.X, result.Position.Y, position.Z) * CFrame.Angles(0, yaw, 0))
	return { Status = true, Dropped = true }
end

function EggSpawnService:DropEgg(player: Player)
	local carrierData = self.Carriers[player]
	if not carrierData then
		return { Status = false }
	end

	local eggData = self.Eggs[carrierData.EggId]
	local character = player.Character
	local rootPart = character and character:FindFirstChild("HumanoidRootPart")
	if not eggData or not rootPart or not self:isInsideDropArea(eggData.Biome, rootPart.Position) then
		self:returnEgg(player)
		return { Status = true, Returned = true }
	end

	local raycastParams = RaycastParams.new()
	raycastParams.FilterType = Enum.RaycastFilterType.Exclude
	raycastParams.FilterDescendantsInstances = { character, SpawnedEggsFolder }

	local result = workspace:Raycast(rootPart.Position, Vector3.new(0, -50, 0), raycastParams)
	if not result then
		self:returnEgg(player)
		return { Status = true, Returned = true }
	end

	self:releaseCarrier(player)

	local _, yaw, _ = rootPart.CFrame:ToOrientation()
	self:placeEgg(eggData, CFrame.new(result.Position) * CFrame.Angles(0, yaw, 0))

	return { Status = true, Returned = false }
end

-- Carrying the egg down to the lobby completes the steal: the egg goes to the inventory
function EggSpawnService:ClaimEgg(player: Player)
	if player.Character and player.Character:GetAttribute("GuardStunned") then
		return { Status = false }
	end
	local carrierData = self.Carriers[player]
	local eggData = carrierData and self.Eggs[carrierData.EggId]
	local character = player.Character
	local rootPart = character and character:FindFirstChild("HumanoidRootPart")
	if not eggData or not rootPart or rootPart.Position.Y >= LobbyMaxHeight then
		return { Status = false }
	end

	local eggName = eggData.Model:GetAttribute("EggName")
	local variant = eggData.Model:GetAttribute("Variant")
	local assetScale = eggData.Model:GetAttribute("AssetScale")

	self:releaseCarrier(player)
	self.Eggs[carrierData.EggId] = nil
	eggData.Model:Destroy()
	if eggData.Nest then
		eggData.Nest:Destroy()
	end

	self.InventoryService:GiveItem(player, {
		Name = eggName,
		Handler = "Egg",
		Variant = variant,
		CustomData = {
			AssetScale = assetScale,
		},
	})

	return { Status = true, EggName = eggName }
end

-- LifeCycle
function EggSpawnService:KnitInit()
	self.InventoryService = knit.GetService("InventoryService")
end

function EggSpawnService:KnitStart()
	Players.PlayerRemoving:Connect(function(player: Player)
		self:returnEgg(player)
	end)

	-- Temporary: one spawn cycle on server start (the cycle logic comes next)
	for biome: string in pairs(zoneConfig) do
		self:SpawnCycle(biome)
	end
end

return EggSpawnService
