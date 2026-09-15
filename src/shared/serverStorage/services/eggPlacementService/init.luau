-- Roblox Services
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Packages
local knit = require(ReplicatedStorage.src.Packages.knit)

-- Utility Modules
local AnchorHandler = require(ReplicatedStorage.src.utility.AnchorHandler)
local CollisionHandler = require(ReplicatedStorage.src.utility.CollisionHandler)

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

function EggPlacementService:validateCFrame(player: Player, cFrame: CFrame)
	local fencesAsset = self:getBase(player):FindFirstChild("Fences") :: Model
	if not fencesAsset then
		return false, "Something went try wrong, try again."
	end

	local fenceCFrame, size = fencesAsset:GetBoundingBox()
	size -= Vector3.new(6, 0, 6)

	if not isInsideArea(cFrame.Position, fenceCFrame, size) then
		return false, "You can't place here!"
	end
	return true
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
			CanOpen = false,
			CreateDate = os.time(),
		}
	end)

	local name = referenceName:split("_")[1]
	local eggAsset = EggAssets:FindFirstChild(name):Clone()
	setupEggAsset(eggAsset)

	local yPosition = Ground:GetPivot().Y + (Ground.Size.Y / 2)
	cFrame = CFrame.new(cFrame.X, yPosition, cFrame.Z)
	eggAsset:PivotTo(cFrame * CFrame.new(0, eggAsset:GetExtentsSize().Y / 2, 0))

	eggAsset.Parent = self:getBase(player).PlacedEggs

	return {
		Status = true,
	}
end

-- LifeCycle
function EggPlacementService:KnitInit()
	self.DataService = knit.GetService("DataService")
	self.BaseService = knit.GetService("BaseService")
	self.InventoryService = knit.GetService("InventoryService")
end

return EggPlacementService
