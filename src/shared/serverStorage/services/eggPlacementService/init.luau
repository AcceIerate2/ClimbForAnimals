-- Roblox Services
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Packages
local knit = require(ReplicatedStorage.src.Packages.knit)

-- Constants
local Ground = workspace.Ground

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
	return self.Server:GetBase(player)
end

function EggPlacementService:validateCFrame(player: Player, cFrame: CFrame)
	local fencesAsset = self:getBase(player):FindFirstChild("Fences") :: Model
	if not fencesAsset then
		return false, "Something went try wrong, try again."
	end

	local fenceCFrame, size = fencesAsset:GetBoundingBox()

	return true
end

-- Public Methods
function EggPlacementService:Place(player: Player, referenceName: string, cFrame: CFrame) end

-- LifeCycle
function EggPlacementService:KnitInit()
	self.DataService = knit.GetService("DataService")
	self.BaseService = knit.GetService("BaseService")
end

return EggPlacementService
