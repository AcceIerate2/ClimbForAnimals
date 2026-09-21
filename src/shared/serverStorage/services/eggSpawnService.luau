-- Roblox Services
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

-- Packages
local knit = require(ReplicatedStorage.src.Packages.knit)

-- Utility Modules
local InstanceCreator = require(ReplicatedStorage.src.utility.InstanceCreator)
local EggHandler = require(ReplicatedStorage.src.utility.eggHandler)
local RarityStyle = require(ReplicatedStorage.src.utility.rarityStyle)
local Zones = require(ReplicatedStorage.src.utility.zones)

-- Config Modules
local eggConfig = require(ReplicatedStorage.src.GameConfiguration.Gameplay.eggConfig)
local zoneConfig = require(ReplicatedStorage.src.GameConfiguration.Gameplay.zoneConfig)
local eggAlertConfig = require(ReplicatedStorage.src.GameConfiguration.Gameplay.eggAlertConfig)

-- Constants
local EggTemplates = ReplicatedStorage:WaitForChild("Assets"):WaitForChild("Eggs")
local NestTemplate = EggTemplates:WaitForChild("Nest")
local EggStatsTemplate = EggTemplates:WaitForChild("EggStats")
local Islands = workspace:WaitForChild("Structures"):WaitForChild("Islands")
local SpawnedEggsFolder = InstanceCreator("Folder", "SpawnedEggs", workspace)
local DefaultVariant = "Normal"
local MaxPositionAttempts = 20
local ClaimSettleSeconds = 1 -- how long to let the server's replicated position catch up
local TitleGap = 1 -- studs between the top of a variant egg and its title billboard
local random = Random.new()

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

-- Only the island's floor counts as ground. A raycast ignores CanCollide, so filtering by
-- exclusion let an egg land on top of whatever decorative model happened to be under the sample
-- point (a phoenix, a fish) instead of on the island.
local function groundParams(spawnArea: BasePart, floor: BasePart?): RaycastParams
	local params = RaycastParams.new()
	if floor then
		params.FilterType = Enum.RaycastFilterType.Include
		params.FilterDescendantsInstances = { floor }
	else
		params.FilterType = Enum.RaycastFilterType.Exclude
		params.FilterDescendantsInstances = { spawnArea, SpawnedEggsFolder }
	end

	return params
end

-- Drops straight down onto the floor at this X/Z, with a random facing.
local function groundAt(position: Vector3, params: RaycastParams): CFrame?
	local result = workspace:Raycast(position + Vector3.new(0, 50, 0), Vector3.new(0, -100, 0), params)

	return result and CFrame.new(result.Position) * CFrame.Angles(0, random:NextNumber(0, math.pi * 2), 0)
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
	Client = {
		RestockAlert = knit.CreateSignal(), -- (alerts: { { Name, Biome, Rarity } })
	},
	BiomeEggs = {}, -- [biome]: { { Name: string, Data: table } }
	-- [eggId]: { Model, Nest, MainPart, PromptAnchor, Prompt, Biome, HomeCFrame (spawn spot), Carrier: Player? }
	Eggs = {},
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

-- The authored spots: the parts placed inside the SpawnEggs area, one egg each, so the layout is
-- yours instead of random. Their own height is ignored on purpose -- the nest is still snapped to
-- the island floor, so nudging a spot up or down can never leave an egg floating.
function EggSpawnService:getSpawnSpots(spawnArea: BasePart): { BasePart }
	local spots = {}
	for _, child in ipairs(spawnArea:GetChildren()) do
		if child:IsA("BasePart") then
			table.insert(spots, child)
		end
	end

	return spots
end

-- Fallback for an area with no authored spots: random points, kept apart from the eggs already
-- placed in this cycle.
function EggSpawnService:findGroundCFrame(
	spawnArea: BasePart,
	radius: number,
	occupied: { { Position: Vector3, Radius: number } },
	params: RaycastParams
): CFrame?
	local halfX = math.max(spawnArea.Size.X / 2 - radius, 0)
	local halfZ = math.max(spawnArea.Size.Z / 2 - radius, 0)

	for _ = 1, MaxPositionAttempts do
		local offset = Vector3.new(random:NextNumber(-halfX, halfX), 0, random:NextNumber(-halfZ, halfZ))
		local candidate = groundAt(spawnArea.CFrame:PointToWorldSpace(offset), params)

		if candidate then
			local isFree = true
			for _, other in ipairs(occupied) do
				local flatDistance = Vector3.new(
					candidate.Position.X - other.Position.X,
					0,
					candidate.Position.Z - other.Position.Z
				).Magnitude
				if flatDistance < radius + other.Radius + eggConfig.EggSpacing then
					isFree = false
					break
				end
			end

			if isFree then
				return candidate
			end
		end
	end

	return nil
end

-- The prompt hangs from an attachment at a fixed height above the egg's BASE, not from the
-- egg's centre: a giant egg's centre ends up 20 studs in the air, where the player can neither
-- see the prompt nor be close enough to trigger it. Small eggs keep it at half their height so
-- it does not float above them.
function EggSpawnService:createPromptAnchor(eggModel: Model): Attachment
	local part = eggModel.PrimaryPart or eggModel:FindFirstChildWhichIsA("BasePart", true)
	local minBound, maxBound = EggHandler.GetVisibleBounds(eggModel, CFrame.new())
	local height = math.min(eggConfig.StealPrompt.Height, (maxBound.Y - minBound.Y) / 2)

	-- Straight above the egg's own pivot, which ScaleAndPivotToBottom already put at the Hitbox's
	-- X/Z on the egg's visible bottom. That is the point the nest seats the egg by and the point
	-- the variant aura emits from; using the visible bounding box centre instead put the prompt
	-- up to 9 studs off to the side on eggs whose Hitbox is deliberately off-centre.
	local anchor = InstanceCreator("Attachment", "PromptAnchor", part, {}) :: Attachment
	anchor.WorldPosition = eggModel:GetPivot().Position + Vector3.new(0, height, 0)

	return anchor
end

-- A variant egg announces itself above the nest; a Normal one gets nothing. The anchor sits
-- over the egg's pivot, the same reference the prompt and the aura use.
-- Every egg gets the billboard: the rarity line is always there, and the variant line only
-- shows on a variant egg. Both colours come from rarityStyle, so the gradient tiers and the
-- variant tints stay the same as everywhere else in the interface.
function EggSpawnService:createStatsBillboard(eggModel: Model, rarity: string?, variant: string): BillboardGui?
	local part = eggModel.PrimaryPart or eggModel:FindFirstChildWhichIsA("BasePart", true)
	if not part then
		return nil
	end

	local minBound, maxBound = EggHandler.GetVisibleBounds(eggModel, CFrame.new())
	local anchor = InstanceCreator("Attachment", "TitleAnchor", part, {}) :: Attachment
	anchor.WorldPosition = eggModel:GetPivot().Position + Vector3.new(0, (maxBound.Y - minBound.Y) + TitleGap, 0)

	local stats = EggStatsTemplate:Clone() :: BillboardGui

	local rarityLabel = stats:FindFirstChild("Rarity") :: TextLabel?
	if rarityLabel then
		rarityLabel.Text = rarity or ""
		rarityLabel.Visible = rarity ~= nil
		RarityStyle.ApplyRarity(rarityLabel, rarity)
	end

	local variantLabel = stats:FindFirstChild("Variant") :: TextLabel?
	if variantLabel then
		local hasVariant = variant ~= DefaultVariant
		variantLabel.Visible = hasVariant
		if hasVariant then
			variantLabel.Text = variant
			RarityStyle.ApplyVariantGradient(variantLabel, variant)
		end
	end

	stats.Parent = anchor

	return stats
end

function EggSpawnService:createPrompt(eggId: string, anchor: Attachment, eggName: string): ProximityPrompt
	local prompt = InstanceCreator("ProximityPrompt", "StealPrompt", anchor, {
		ActionText = eggConfig.StealPrompt.ActionText,
		ObjectText = `{eggName} Egg`,
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
	variant: string,
	spotIndex: number?
)
	local eggId = HttpService:GenerateGUID(false)
	local mainPart = eggModel.PrimaryPart
	local promptAnchor = self:createPromptAnchor(eggModel)
	self:createStatsBillboard(eggModel, egg.Data.Rarity, variant)

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
		SpotIndex = spotIndex,
		PromptAnchor = promptAnchor,
		Prompt = self:createPrompt(eggId, promptAnchor, egg.Name),
		Biome = biome,
		HomeCFrame = eggModel:GetPivot(),
		Carrier = nil,
	}
end

-- Reaching the lobby means standing in it, not merely being below its ceiling. The Forest floor
-- sits 6 studs above the lobby ceiling, so stepping off its edge already satisfies the height
-- alone and the steal used to complete in mid air.
local function isInLobby(rootPart: BasePart, humanoid: Humanoid?): boolean
	return not Zones.IsAboveLobby(rootPart.Position) and humanoid ~= nil and humanoid.FloorMaterial ~= Enum.Material.Air
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

-- Sends whatever the player is carrying back to its nest. Returns whether there was an egg.
function EggSpawnService:ReturnCarriedEgg(player: Player): boolean
	if not self.Carriers[player] then
		return false
	end

	self:returnEgg(player)
	return true
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

-- Empties a biome so its spots can be refilled. An egg somebody is carrying is left alone, and
-- its spot comes back in the result so the refill does not drop a second egg on top of it.
function EggSpawnService:clearBiome(biome: string): { [number]: boolean }
	local carriedSpots = {}
	for eggId, eggData in pairs(self.Eggs) do
		if eggData.Biome ~= biome then
			continue
		end

		if eggData.Carrier then
			if eggData.SpotIndex then
				carriedSpots[eggData.SpotIndex] = true
			end

			continue
		end

		self.Eggs[eggId] = nil
		eggData.Model:Destroy()
		if eggData.Nest then
			eggData.Nest:Destroy()
		end
	end

	return carriedSpots
end

-- Public Methods
-- Fills every spot of a biome with a freshly rolled egg, clearing whatever was there first.
function EggSpawnService:SpawnCycle(biome: string, alerts: { any }?): number
	local spawnArea = self:getSpawnArea(biome)
	if not spawnArea then
		return 0
	end

	local floor = self:getIslandArea(biome)
	local biomeFolder = self:getBiomeFolder(biome)
	local params = groundParams(spawnArea, floor)
	local spots = self:getSpawnSpots(spawnArea)
	local carriedSpots = self:clearBiome(biome)
	local occupied = {}
	for _, child in ipairs(biomeFolder:GetChildren()) do
		table.insert(occupied, { Position = child:GetPivot().Position, Radius = EggHandler.GetFootprint(child) / 2 })
	end

	-- One egg per authored spot. Without spots the area falls back to EggsPerCycle random points.
	local spawned = 0
	for index = 1, (#spots > 0 and #spots or eggConfig.EggsPerCycle) do
		if carriedSpots[index] then
			continue
		end

		local egg = self:rollEgg(biome)
		local assetScale = rollAssetScale()
		local variant = rollVariant()
		local eggModel = egg and self:createEggModel(biome, egg.Name, assetScale, variant)
		if not eggModel then
			continue
		end

		local nest = self:createNest(eggModel)
		local radius = math.max(EggHandler.GetFootprint(eggModel), EggHandler.GetFootprint(nest)) / 2
		local spot = spots[index]
		-- An authored spot is respected as it is: no spacing check, because the layout is yours.
		local groundCFrame
		if spot then
			groundCFrame = groundAt(spot.Position, params)
		else
			groundCFrame = self:findGroundCFrame(spawnArea, radius, occupied, params)
		end
		if not groundCFrame then
			eggModel:Destroy()
			nest:Destroy()
			continue
		end

		nest:PivotTo(groundCFrame)
		local eggSpotBottom = nest:FindFirstChild("EggSpotBottom", true)
		local eggCFrame = eggSpotBottom and (CFrame.new(eggSpotBottom.Position) * groundCFrame.Rotation) or groundCFrame
		eggModel:PivotTo(eggCFrame)

		nest.Parent = biomeFolder
		eggModel.Parent = biomeFolder
		self:registerEgg(eggModel, nest, biome, egg, assetScale, variant, index)

		if alerts and eggAlertConfig.Rarities[egg.Data.Rarity] then
			table.insert(alerts, { Name = egg.Name, Biome = biome, Rarity = egg.Data.Rarity })
		end

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

	-- Measured from the prompt, not from the egg's centre, so a giant egg is stealable from
	-- wherever its prompt is actually reachable.
	local distance = (torso.Position - eggData.PromptAnchor.WorldPosition).Magnitude
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
		return { Status = false, Reason = "Stunned by a guard." }
	end
	local carrierData = self.Carriers[player]
	local eggData = carrierData and self.Eggs[carrierData.EggId]
	local character = player.Character
	local rootPart = character and character:FindFirstChild("HumanoidRootPart")
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not eggData or not rootPart then
		return { Status = false, Reason = "No carried egg is registered for this player." }
	end

	-- The client asks for the claim the instant IT lands, but rootPart.Position here is the
	-- REPLICATED position, which trails a fast fall: coming down from Crystal Mines the impact is
	-- 908 studs/s, so ~140ms of lag is enough for the server to still read the player above the
	-- lobby limit and reject a legitimate steal. So the server waits for its own view to catch up
	-- instead of sampling it once -- which also covers the landing itself, since the fall from a
	-- low island reaches the lobby height long before the player touches the floor.
	local deadline = os.clock() + ClaimSettleSeconds
	while not isInLobby(rootPart, humanoid) and os.clock() < deadline do
		RunService.Heartbeat:Wait()
		if self.Carriers[player] ~= carrierData or not rootPart.Parent then
			return { Status = false, Reason = "The carry ended before the claim settled." }
		end
	end

	if not isInLobby(rootPart, humanoid) then
		return {
			Status = false,
			Reason = `The server sees the player at Y={math.round(rootPart.Position.Y)} on {humanoid and humanoid.FloorMaterial.Name or "no"} floor, not standing in the lobby.`,
		}
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

-- Every biome at once: one cycle of the whole world.
function EggSpawnService:Restock(): number
	local spawned = 0
	local alerts = {}
	for biome: string in pairs(zoneConfig) do
		spawned += self:SpawnCycle(biome, alerts)
	end

	if #alerts > 0 then
		self.Client.RestockAlert:FireAll(alerts)
	end

	return spawned
end

function EggSpawnService:KnitStart()
	Players.PlayerRemoving:Connect(function(player: Player)
		self:returnEgg(player)
	end)
end

return EggSpawnService
