-- Roblox Services
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Packages
local knit = require(ReplicatedStorage.src.Packages.knit)

-- Constants
local BaseAssets = workspace.Bases

-- Local Types
type BaseData = {
	Taken: boolean,
	Owner: Player?,
}

-->
local BaseService = knit.CreateService({
	Name = "BaseService",
	MaxBases = #BaseAssets:GetChildren(),
	Bases = {},
})

-- Private Methods
function BaseService:getTakenBases()
	local takenBases = {}
	for baseAsset, baseData: BaseData in pairs(self.Bases) do
		if baseData.Taken then
			table.insert(takenBases, baseAsset)
		end
	end
	return takenBases
end

function BaseService:getAvailableBase()
	for baseAsset, baseData: BaseData in pairs(self.Bases) do
		if not baseData.Taken then
			return baseAsset
		end
	end
	return
end

function BaseService:toggleOverheadGui() end

-- Public Methods
function BaseService:GetPlayerBase(player: Player)
	for baseAsset: any, baseData: BaseData in pairs(self.Bases) do
		if baseData.Owner and baseData.Taken then
			return baseAsset
		end
	end
	return
end

function BaseService:Connect(player: Player)
	if self.MaxBases <= #self:getTakenBases() then
		player:Kick("Couldn't find an available Base - Please rejoin, and try again.")
		return
	end

	local availableBase = self:getAvailableBase()
	self.Bases[availableBase].Owner = player
	self.Bases[availableBase].Taken = true

	return {
		Function = self.Disconnect,
		Args = {
			self,
			player,
		},
	}
end

function BaseService:Disconnect(player: Player) end

-- LifeCycle
function BaseService:KnitInit()
	self.DataService = knit.GetService("DataService")
end

function BaseService:KnitStart()
	for _, baseAsset in pairs(BaseAssets:GetChildren()) do
		self.Bases[baseAsset] = {
			Taken = false,
			Owner = nil,
		}
	end
end

return BaseService
