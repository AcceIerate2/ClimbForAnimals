-- Roblox Services
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Packages
local knit = require(ReplicatedStorage.src.Packages.knit)

-- Utility Modules
local WaitForUiDesc = require(ReplicatedStorage.src.utility.WaitForUiDesc)

-- Constants
local BaseAssets = ReplicatedStorage:WaitForChild("Assets"):WaitForChild("BaseAssets")
local TrailsShop = BaseAssets:WaitForChild("TrailsShop")
local BaseUpgradeSign = BaseAssets:WaitForChild("BaseUpgradeSign")
local TmUpgradeSign = BaseAssets:WaitForChild("TreadmillUpgradeSign")

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
	local baseUpgradeSignCFramePart = self.Base:WaitForChild("BaseUpgradeSignCFrame")
	BaseUpgradeSign:PivotTo(baseUpgradeSignCFramePart:GetPivot())
	BaseUpgradeSign.Parent = self.Base
end

function BaseController:placeTrailsShop()
	local trailsShopCFramePart = self.Base:WaitForChild("StaminaShopCFrame")
	local trailsShopSize = TrailsShop:GetExtentsSize()

	local hitbox = TrailsShop:WaitForChild("Hitbox") :: BasePart
	self.PanelController:BindHitbox(hitbox, "Trails")

	TrailsShop:PivotTo(trailsShopCFramePart:GetPivot() * CFrame.new(0, trailsShopSize.Y / 2, 0))
	TrailsShop.Parent = self.Base
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
	self.PanelController = knit.GetController("PanelController")

	self:syncBase()

	self:placeTrailsShop()
	self:placeUpgradeSign()
	self:placeTMUpgradeSign()
end

function BaseController:KnitStart()
	local playerNameTextLabel: TextLabel = WaitForUiDesc(self.Base, "TextLabel", {
		Name = "PlayerName",
	}, 3)

	if playerNameTextLabel then
		playerNameTextLabel.Text = `YOUR BASE`
	end
end

return BaseController
