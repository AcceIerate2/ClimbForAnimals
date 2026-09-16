-- Roblox Services
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Packages
local knit = require(ReplicatedStorage.src.Packages.knit)

-- Utility Modules
local AnchorHandler = require(ReplicatedStorage.src.utility.AnchorHandler)
local CollisionHandler = require(ReplicatedStorage.src.utility.CollisionHandler)
local cFrameSerializer = require(ReplicatedStorage.src.utility.cFrameSerializer)

-- Constants
local Ground = workspace.Ground
local AssetsFolder = ReplicatedStorage.Assets
local EggAssets = AssetsFolder.Eggs

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

function EggPlacementService:placeOnBase(player: Player, referenceName: string, cFrame: CFrame)
	local name = referenceName:split("_")[1]
	local eggAsset = EggAssets:FindFirstChild(name):Clone()
	setupEggAsset(eggAsset)

	local yPosition = Ground:GetPivot().Y + (Ground.Size.Y / 2)
	cFrame = CFrame.new(cFrame.X, yPosition, cFrame.Z)
	eggAsset:PivotTo(cFrame * CFrame.new(0, eggAsset:GetExtentsSize().Y / 2, 0))

	eggAsset.Name = referenceName
	eggAsset.Parent = self:getBase(player).PlacedEggs
end

-- Public Methods
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

	self.InventoryService:RemoveItem(player, referenceName)
	placedEggsVO:Update(function(mutator)
		mutator[referenceName] = {
			CanHatch = false,
			PlaceDate = os.time(),
			CFrame = cFrameSerializer.Serialize(cFrame),
		}
	end)

	self:placeOnBase(player, referenceName, cFrame)
	self.EggGrowService:ConnectEgg(player, referenceName)

	return {
		Status = true,
	}
end

function EggPlacementService:LoadEggs(player: Player)
	for referenceName: string, data: { CanHatch: boolean, PlaceDate: number, CFrame: CFrame } in
		pairs(self.DataService:GetValue(player, "PlacedEggs"))
	do
		self:placeOnBase(player, referenceName, cFrameSerializer.Deserialize(data.CFrame))
	end
end

-- LifeCycle
function EggPlacementService:KnitInit()
	self.DataService = knit.GetService("DataService")
	self.BaseService = knit.GetService("BaseService")
	self.InventoryService = knit.GetService("InventoryService")
	self.EggGrowService = knit.GetService("EggGrowService")
end

return EggPlacementService
