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

-->
local Stamina = {}

function Stamina:updateStaminaLabel(newValue: number)
	self.StatsLabel.Text = `{newValue}%`
	local defaultSize = self.StatsLabel:GetAttribute("Size") :: UDim2
	PlayTween(self.StatsLabel, TweenInfo.new(0.25, Enum.EasingStyle.Linear, Enum.EasingDirection.Out, 0, true, 0), {
		Size = UDim2.fromScale(defaultSize.X.Scale * 1.1, defaultSize.Y.Scale * 1.1),
	}, function()
		self.StatsLabel.Size = defaultSize
	end)
end

function Stamina:updateBar(newValue: number)
	PlayTween(self.Bar, TweenInfo.new(0.25), {
		Size = UDim2.fromScale(math.clamp(newValue / self.DataController:GetValue("MaxStamina"), 0, 1), 1),
	})
end

-- LifeCycle
function Stamina:Init()
	self.DataController = knit.GetController("DataController")

	self.Container = WaitForUiDesc(Player.PlayerGui:WaitForChild("General"), "Frame", { Name = "StaminaBar" })
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
