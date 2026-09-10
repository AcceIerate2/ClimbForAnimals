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
	self.Base = self.BaseService:GetPlayerBase()
end

-- Public Methods
function BaseController:GetBase()
	return self.Base
end

-- LifeCycle
function BaseController:KnitInit()
	self.BaseService = knit.GetService("BaseService")
	self:syncBase()
end

function BaseController:KnitStart()
	-- Gate Animations
	local Gate = self.Base:WaitForChild("Gate")
end

return BaseController
