-- Roblox Services
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Packages
local knit = require(ReplicatedStorage.src.Packages.knit)

-- Utility Modules
local NumberShortner = require(ReplicatedStorage.src.utility.NumberShortner)
local PlayTween = require(ReplicatedStorage.src.utility.PlayTween)
local WaitForUiDesc = require(ReplicatedStorage.src.utility.WaitForUiDesc)

-->
local SpeedLabel = {}

-- LifeCycle
function SpeedLabel:Init(player: Player)
	self.Container = WaitForUiDesc(player.PlayerGui:WaitForChild("Hud"), "Frame", {
		Name = "Speed",
	})

	self.DefaultSize = self.Container.Size
	self.Label = self.Container:WaitForChild("SpeedAmount")

	local function update(newValue: number)
		self.Container.Size = self.DefaultSize
		self.Label.Text = `{NumberShortner(newValue)}`
		PlayTween(self.Container, TweenInfo.new(0.15, Enum.EasingStyle.Linear, Enum.EasingDirection.Out, 0, true, 0), {
			Size = UDim2.fromScale(self.DefaultSize.X.Scale / 1.25, self.DefaultSize.Y.Scale / 1.25),
		})
	end

	self.SpeedController = knit.GetController("SpeedController")
	update(self.SpeedController.Speed)

	self.SpeedController.Signals.UpdateSpeedText:Connect(update)
end

return SpeedLabel
