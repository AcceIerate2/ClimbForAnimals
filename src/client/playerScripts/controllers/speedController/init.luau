-- Roblox Services
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Packages
local knit = require(ReplicatedStorage.src.Packages.knit)

-- Utility Modules
local PlayTween = require(ReplicatedStorage.src.utility.PlayTween)
local NumberShortner = require(ReplicatedStorage.src.utility.NumberShortner)
local WaitForUiDesc = require(ReplicatedStorage.src.utility.WaitForUiDesc)

-- Constants
local Player = Players.LocalPlayer
local Assets = ReplicatedStorage:WaitForChild("Assets")
local Gui = Assets:WaitForChild("Gui"):WaitForChild("PopSpeed")

-->
local SpeedController = knit.CreateController({
	Name = "SpeedController",
	Speed = 0,
	Popups = {},
})

-- Private Methods
function SpeedController:effect(change: number)
	local character = Player.Character
	if not character then
		return
	end

	local hrp = character:FindFirstChild("HumanoidRootPart")
	if not hrp then
		return
	end

	local newGui = Gui:Clone() :: BillboardGui
	WaitForUiDesc(newGui, "TextLabel", {
		Name = "SpeedAmount",
	}).Text = `+{NumberShortner(change)}`

	newGui.Adornee = hrp
	newGui.Parent = hrp
	newGui.Enabled = true

	table.insert(self.Popups, newGui)
	local index = #self.Popups

	local x = math.random(-50, 50) / 10
	local y = math.random(15, 50) / 10
	local z = math.random(-25, 25) / 10

	PlayTween(newGui, TweenInfo.new(0.5), {
		Size = UDim2.fromScale(4.5, 2.5),
	})

	PlayTween(newGui, TweenInfo.new(0.5), {
		StudsOffset = Vector3.new(x, y, z),
	}, function()
		PlayTween(newGui:WaitForChild("CanvasGroup"), TweenInfo.new(0.15), {
			GroupTransparency = 1,
		}, function()
			newGui:Destroy()
			table.remove(self.Popups, index)
		end)

		PlayTween(newGui, TweenInfo.new(0.15), {
			StudsOffset = Vector3.new(x, y - 1, z),
		})
	end)
end

function SpeedController:listenToValueChanges()
	self.Speed = self.DataController:GetValue("Speed")
	self.DataController:GetValueChangedSignal("Speed"):Connect(function(newValue)
		local change = newValue - self.Speed
		self.Speed = newValue
		if change > 0 then
			self:effect(change)
		end
	end)
end

-- LifeCycle
function SpeedController:KnitInit()
	self.DataController = knit.GetController("DataController")
end

function SpeedController:KnitStart()
	self:listenToValueChanges()
end

return SpeedController
