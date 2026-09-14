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

-- LifeCycle
function Stamina:Init()
	self.Container = WaitForUiDesc(Player.PlayerGui:WaitForChild("General"), "Frame", { Name = "StaminaBar" })
	self.Container.Visible = false

	self.StatsLabel = self.Container:WaitForChild("Stats")
	self.StatsLabel:SetAttribute("Size", self.StatsLabel.Size)
	self.Bar = self.Container:WaitForChild("Bar")

	self.StaminaController = knit.GetController("StaminaController")
	self.StaminaController.Signals.ToggleVisibility:Connect(function(visible: boolean)
		self.Container.Visible = visible
	end)

	self.StaminaController.Signals.UpdateStamina:Connect(function(newStamina: number)
		self:updateStaminaLabel(newStamina)
		self:updateBar(newStamina)
	end)
end

return Stamina
