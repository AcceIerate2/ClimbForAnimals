-- Roblox Services
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Constants
local Player = Players.LocalPlayer

-- Packages
local knit = require(ReplicatedStorage.src.Packages.knit)

-- Utility Modules
local WaitForUiDesc = require(ReplicatedStorage.src.utility.WaitForUiDesc)
local PlayTween = require(ReplicatedStorage.src.utility.PlayTween)

-- Config Modules
local staminaConfig = require(ReplicatedStorage.src.GameConfiguration.Gameplay.staminaConfig)

-- Tween Config
local ShowTweenInfo = TweenInfo.new(0.25, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
local HideTweenInfo = TweenInfo.new(0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
local HiddenScale = 0.6

-->
local Stamina = {}

function Stamina:updateStaminaLabel(newValue: number)
	self.StatsLabel.Text = `{math.round((newValue / staminaConfig.MaxStamina) * 100)}%`
end

function Stamina:updateBar(newValue: number)
	PlayTween(self.Bar, TweenInfo.new(0.25), {
		Size = UDim2.fromScale(math.clamp(newValue / staminaConfig.MaxStamina, 0, 1), 1),
	})
end

function Stamina:getHiddenSize(): UDim2
	return UDim2.fromScale(self.DefaultSize.X.Scale * HiddenScale, self.DefaultSize.Y.Scale * HiddenScale)
end

function Stamina:toggleVisibility(visible: boolean)
	if not visible and not self.Container.Visible then
		return
	end

	if self.ActiveTween then
		self.ActiveTween:Cancel()
		self.ActiveTween = nil
	end

	if visible and not self.Container.Visible then
		self.Container.Size = self:getHiddenSize()
		self.Container.Visible = true
	end

	local tween
	tween = PlayTween(self.Container, visible and ShowTweenInfo or HideTweenInfo, {
		Size = visible and self.DefaultSize or self:getHiddenSize(),
	}, function()
		if self.ActiveTween ~= tween then
			return
		end

		self.ActiveTween = nil
		self.Container.Visible = visible
	end)
	self.ActiveTween = tween
end

-- LifeCycle
function Stamina:Init()
	self.Container = WaitForUiDesc(Player.PlayerGui:WaitForChild("General"), "Frame", { Name = "StaminaBar" })
	self.Container.Visible = false
	self.DefaultSize = self.Container.Size

	self.StatsLabel = self.Container:WaitForChild("Stats")
	self.StatsLabel:SetAttribute("Size", self.StatsLabel.Size)
	self.Bar = self.Container:WaitForChild("Bar")

	self.StaminaController = knit.GetController("StaminaController")
	self.StaminaController.Signals.ToggleVisibility:Connect(function(visible: boolean)
		self:toggleVisibility(visible)
	end)

	self.StaminaController.Signals.UpdateStamina:Connect(function(newStamina: number)
		self:updateStaminaLabel(newStamina)
		self:updateBar(newStamina)
	end)
end

return Stamina
