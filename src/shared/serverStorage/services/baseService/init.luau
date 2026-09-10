-- Roblox Services
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Packages
local knit = require(ReplicatedStorage.src.Packages.knit)

-- Constants
local BaseAssets = workspace.Bases

-->
local BaseService = knit.CreateService({
	Name = "BaseService",
	Bases = {},
})

-- Public Methods
function BaseService:Connect(player: Player) end

function BaseService:Disconnect(player: Player) end

-- LifeCycle
function BaseService:KnitInit()
	self.DataService = knit.GetService("DataService")
end

function BaseService:KnitStart()
	for _, baseAsset in pairs(BaseAssets:GetChildren()) do
	end
end

return BaseService
