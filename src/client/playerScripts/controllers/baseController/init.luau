-- Roblox Services
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Packages
local knit = require(ReplicatedStorage.src.Packages.knit)

-- Utility Modules
local WaitForUiDesc = require(ReplicatedStorage.src.utility.WaitForUiDesc)

-- Constants
local BaseAssets = ReplicatedStorage:WaitForChild("Assets"):WaitForChild("BaseAssets")
local StaminaShop = BaseAssets:WaitForChild("StaminaShop")
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

function BaseController:placeStaminaShop()
	local staminaShopCFramePart = self.Base:WaitForChild("StaminaShopCFrame")
	local staminaShopSize = StaminaShop:GetExtentsSize()

	local hitbox = StaminaShop:WaitForChild("Hitbox") :: BasePart
	self.PanelController:BindHitbox(hitbox, "Stamina")

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
	self.PanelController = knit.GetController("PanelController")

	self:syncBase()

	self:placeStaminaShop()
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
