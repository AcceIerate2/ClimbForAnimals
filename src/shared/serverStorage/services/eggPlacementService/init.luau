-- Roblox Services
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Packages
local knit = require(ReplicatedStorage.src.Packages.knit)

-- Utility Modules
local AnchorHandler = require(ReplicatedStorage.src.utility.AnchorHandler)
local CollisionHandler = require(ReplicatedStorage.src.utility.CollisionHandler)
local cFrameSerializer = require(ReplicatedStorage.src.utility.cFrameSerializer)
local EggHandler = require(ReplicatedStorage.src.utility.eggHandler)

-- Constants
local Ground = workspace.Ground

-- Helper Functions
local function isInsideArea(point: Vector3, areaCFrame: CFrame, areaSize: Vector3): boolean
	local localPoint = areaCFrame:PointToObjectSpace(point)
	local halfSize = areaSize / 2
	return math.abs(localPoint.X) <= halfSize.X and math.abs(localPoint.Z) <= halfSize.Z
end

local function setupEggAsset(asset)
	AnchorHandler(asset, true)
	CollisionHandler.ToggleCollisionProperties(asset, {
		CanCollide = false,
	}, {})
end

-->
local EggPlacementService = knit.CreateService({
	Name = "EggPlacementService",
	Client = {},
})

-- Client Exposed Methods
function EggPlacementService.Client:RequestToPlace(player: Player, referenceName: string, cFrame: CFrame)
	return self.Server:Place(player, referenceName, cFrame)
end

-- Private Methods
function EggPlacementService:getBase(player: Player)
	return self.BaseService:GetPlayerBase(player)
end

function EggPlacementService:getPlotBounds(player: Player): (CFrame, Vector3)
	return self:getBase(player).Fences:GetBoundingBox()
end

function EggPlacementService:getLegacyRelativeCFrame(player: Player, worldCFrame: CFrame): CFrame
	local currentFrame, size = self:getPlotBounds(player)
	local sourceFrame = currentFrame
	local nearestDistance = math.huge

	-- Old saves have no plot ID. The closest fence enclosure gives us the
	-- best available estimate of the original plot's coordinate frame.
	for _, base in self:getBase(player).Parent:GetChildren() do
		local fences = base:FindFirstChild("Fences")
		if not fences or not fences:IsA("Model") then
			continue
		end

		local frame = fences:GetBoundingBox()
		local offset = worldCFrame.Position - frame.Position
		local distance = Vector2.new(offset.X, offset.Z).Magnitude
		if distance < nearestDistance then
			nearestDistance = distance
			sourceFrame = frame
		end
	end

	local relative = sourceFrame:ToObjectSpace(worldCFrame)
	local halfX = math.max(0, size.X / 2 - 3)
	local halfZ = math.max(0, size.Z / 2 - 3)
	local position =
		Vector3.new(math.clamp(relative.X, -halfX, halfX), relative.Y, math.clamp(relative.Z, -halfZ, halfZ))

	return CFrame.new(position) * relative.Rotation
end

function EggPlacementService:cFrameCloseToOtherEggs(player: Player, cFrame: CFrame): boolean
	local base = self:getBase(player)
	local placedEggsFolder = base.PlacedEggs

	for _, eggAsset: Model in placedEggsFolder:GetChildren() do
		local eggPosition = eggAsset:GetPivot().Position
		local offset = Vector3.new(cFrame.Position.X - eggPosition.X, 0, cFrame.Position.Z - eggPosition.Z)
		if offset.Magnitude < 5 then
			return true
		end
	end

	return false
end

function EggPlacementService:validateCFrame(player: Player, cFrame: CFrame)
	local fencesAsset = self:getBase(player):FindFirstChild("Fences") :: Model
	if not fencesAsset then
		return false, "Something went try wrong, try again."
	end

	local fenceCFrame, size = fencesAsset:GetBoundingBox()
	size -= Vector3.new(6, 0, 6)

	if not isInsideArea(cFrame.Position, fenceCFrame, size) then
		return false, "Click inside your Plot to place the Egg!"
	end

	if self:cFrameCloseToOtherEggs(player, cFrame) then
		return false, "Too close to other Eggs!"
	end

	return true
end

function EggPlacementService:placeOnBase(
	player: Player,
	referenceName: string,
	cFrame: CFrame,
	variant: string?,
	assetScale: number?
)
	local name = referenceName:split("_")[1]
	local eggAsset = EggHandler.CreateModel(name, variant, assetScale)
	if not eggAsset then
		return
	end
	setupEggAsset(eggAsset)

	-- the pivot is at the bottom of the egg
	local yPosition = Ground:GetPivot().Y + (Ground.Size.Y / 2)
	eggAsset:PivotTo(CFrame.new(cFrame.X, yPosition, cFrame.Z))

	eggAsset.Name = referenceName
	eggAsset.Parent = self:getBase(player).PlacedEggs
end

-- Public Methods
function EggPlacementService:GetEggCFrame(player: Player, referenceName: string): CFrame
	local base = self:getBase(player)
	local egg = base.PlacedEggs:FindFirstChild(referenceName)
	if egg then
		return egg:GetPivot()
	end

	local data = self.DataService:GetValue(player, "PlacedEggs")[referenceName]
	local savedCFrame = cFrameSerializer.Deserialize(data.CFrame)
	local plotFrame = self:getPlotBounds(player)
	local relative = data.RelativeToPlot and savedCFrame or self:getLegacyRelativeCFrame(player, savedCFrame)

	return plotFrame:ToWorldSpace(relative)
end

function EggPlacementService:Place(player: Player, referenceName: string, cFrame: CFrame)
	local status, reason = self:validateCFrame(player, cFrame)
	if not status then
		return { Status = status, Reason = reason }
	end

	if not self.InventoryService:OwnsItem(player, referenceName) then
		return { Status = false, Reason = "You don't own this item!" }
	end

	local placedEggsVO = self.DataService:GetValueObject(player, "PlacedEggs")
	if placedEggsVO:Get()[referenceName] then
		return {
			Status = false,
			Reason = "Already placed!",
		}
	end

	local plotFrame = self:getPlotBounds(player)
	local relativeCFrame = plotFrame:ToObjectSpace(cFrame)

	local itemData = self.DataService:GetValue(player, "Inventory")[referenceName]
	local variant = itemData and itemData.Variant
	local assetScale = itemData and itemData.CustomData and itemData.CustomData.AssetScale

	self.InventoryService:RemoveItem(player, referenceName)
	placedEggsVO:Update(function(mutator)
		mutator[referenceName] = {
			CanHatch = false,
			PlaceDate = os.time(),
			CFrame = cFrameSerializer.Serialize(relativeCFrame),
			RelativeToPlot = true,
			Variant = variant,
			AssetScale = assetScale,
		}
	end)

	self:placeOnBase(player, referenceName, cFrame, variant, assetScale)
	self.EggGrowService:ConnectEgg(player, referenceName)
	self.TutorialService:Record(player, "Deposit", referenceName)

	return {
		Status = true,
	}
end

function EggPlacementService:LoadEggs(player: Player)
	local placedEggsVO = self.DataService:GetValueObject(player, "PlacedEggs")
	local plotFrame = self:getPlotBounds(player)
	local migrated = {}

	for referenceName: string, data in pairs(placedEggsVO:Get()) do
		local relativeCFrame = cFrameSerializer.Deserialize(data.CFrame)
		if not data.RelativeToPlot then
			relativeCFrame = self:getLegacyRelativeCFrame(player, relativeCFrame)
			migrated[referenceName] = cFrameSerializer.Serialize(relativeCFrame)
		end

		self:placeOnBase(player, referenceName, plotFrame:ToWorldSpace(relativeCFrame), data.Variant, data.AssetScale)
		self.EggGrowService:ConnectEgg(player, referenceName)
	end

	if next(migrated) then
		placedEggsVO:Update(function(mutator)
			for referenceName, relativeCFrame in pairs(migrated) do
				local data = mutator[referenceName]
				if data then
					data.CFrame = relativeCFrame
					data.RelativeToPlot = true
				end
			end
		end)
	end
end

-- LifeCycle
function EggPlacementService:KnitInit()
	self.TutorialService = knit.GetService("TutorialService")
	self.DataService = knit.GetService("DataService")
	self.BaseService = knit.GetService("BaseService")
	self.InventoryService = knit.GetService("InventoryService")
	self.EggGrowService = knit.GetService("EggGrowService")
end

return EggPlacementService
