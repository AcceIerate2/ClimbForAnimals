-- Roblox Services
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

-- Packages
local knit = require(ReplicatedStorage.src.Packages.knit)

-- Utility Modules
local WaitForUiDesc = require(ReplicatedStorage.src.utility.WaitForUiDesc)
local partOfCharacter = require(ReplicatedStorage.src.utility.partOfCharacter)

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

	local hitbox = StaminaShop:WaitForChild("Hitbox") :: BasePart
	RunService.Heartbeat:Connect(function()
		local partsInHitbox = workspace:GetPartsInPart(hitbox)
		local playerInHitbox = false

		for _, basePart: BasePart in pairs(partsInHitbox) do
			local player = Players:GetPlayerFromCharacter(partOfCharacter(basePart))
			if player == Players.LocalPlayer then
				playerInHitbox = true
				break
			end
		end

		if not playerInHitbox then
			if self.PanelController.ActivePanel == "Stamina" then
				self.PanelController:TogglePanel("Stamina")
			end
		else
			if self.PanelController.ActivePanel ~= "Stamina" then
				self.PanelController:TogglePanel("Stamina")
			end
		end
	end)

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
