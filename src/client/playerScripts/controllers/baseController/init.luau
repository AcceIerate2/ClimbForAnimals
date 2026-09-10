-- Roblox Services
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Packages
local knit = require(ReplicatedStorage.src.Packages.knit)

-->
local BaseController = knit.CreateController({
	Name = "BaseController",
})

-- Private Methods
function BaseController:syncBase()
	self.BaseService:GetPlayerBase()
end

-- LifeCycle
function BaseController:KnitInit()
	self.BaseService = knit.GetService("BaseService")
	self:syncBase()
end

function BaseController:KnitStart() end

return BaseController
