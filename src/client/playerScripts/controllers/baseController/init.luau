-- Roblox Services
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Packages
local knit = require(ReplicatedStorage.src.Packages.knit)

-- Constants
local PlotAssets = ReplicatedStorage:WaitForChild("Assets"):WaitForChild("PlotAssets")
local StaminaShop = PlotAssets:WaitForChild("StaminaShop")
local PlotUpgradeSign = PlotAssets:WaitForChild("PlotUpgradeSign")
local TmUpgradeSign = PlotAssets:WaitForChild("TreadmillUpgradeSign")

-->
local BaseController = knit.CreateController({
	Name = "BaseController",
})

-- Private Methods
function BaseController:placeTMUpgradeSign()
	local TMUpgradeSignCFramePart = self.Base:WaitForChild("TMUpgradeSignCFrame")
	TmUpgradeSign:PivotTo(TMUpgradeSignCFramePart:GetPivot())
	TmUpgradeSign.Parent = self.Base
end

function BaseController:placeUpgradeSign()
	local plotUpgradeSignCFramePart = self.Base:WaitForChild("PlotUpgradeSignCFrame")
	PlotUpgradeSign:PivotTo(plotUpgradeSignCFramePart:GetPivot())
	PlotUpgradeSign.Parent = self.Base
end

function BaseController:placeStaminaShop()
	local staminaShopCFramePart = self.Base:WaitForChild("StaminaShopCFrame")
	local staminaShopSize = StaminaShop:GetExtentsSize()
	StaminaShop:PivotTo(staminaShopCFramePart:GetPivot() * CFrame.new(0, staminaShopSize.Y / 2, 0))
	StaminaShop.Parent = self.Base
end

function BaseController:syncBase()
	local status, base = self.BaseService:GetPlayerBase():await()
	if not status then
		warn(base)
		return
	end

	self.Base = base
end

-- Public Methods
function BaseController:GetBase()
	return self.Base
end

-- LifeCycle
function BaseController:KnitInit()
	self.BaseService = knit.GetService("BaseService")
	self.TreadmillController = knit.GetController("TreadmillController")

	self:syncBase()

	self.TreadmillController:Place()
	self:placeStaminaShop()
	self:placeUpgradeSign()
	self:placeTMUpgradeSign()
end

return BaseController
