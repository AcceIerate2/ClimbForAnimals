-- Roblox Services
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Packages
local knit = require(ReplicatedStorage.src.Packages.knit)

-- Utility Modules
local NumberShortner = require(ReplicatedStorage.src.utility.NumberShortner)
local PlayTween = require(ReplicatedStorage.src.utility.PlayTween)
local WaitForUiDesc = require(ReplicatedStorage.src.utility.WaitForUiDesc)

-- Constants
local Assets = ReplicatedStorage:WaitForChild("Assets")
local Gui = Assets:WaitForChild("Gui"):WaitForChild("PopSpeed")

-- Helper Functions
local function getHrp(player: Player)
	return player.Character and player.Character:FindFirstChild("HumanoidRootPart")
end

local function getPosition()
	local x = math.random(-50, 50) / 10
	local y = math.random(15, 50) / 10
	local z = math.random(-25, 25) / 10
	return Vector3.new(x, y, z)
end

-->
local TreadmillSpeedPopup = {}

-- Private Methods
function TreadmillSpeedPopup:animate(newGui)
	local position = getPosition()
	PlayTween(newGui, TweenInfo.new(0.5), {
		Size = UDim2.fromScale(4.5, 2.5),
	})

	PlayTween(newGui, TweenInfo.new(0.5), {
		StudsOffset = position,
	}, function()
		PlayTween(newGui:WaitForChild("CanvasGroup"), TweenInfo.new(0.15), {
			GroupTransparency = 1,
		}, function()
			newGui:Destroy()
		end)

		PlayTween(newGui, TweenInfo.new(0.15), {
			StudsOffset = position - Vector3.new(0, 1, 0),
		})
	end)
end

function TreadmillSpeedPopup:new(player: Player, change: number)
	local hrp = getHrp(player)
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

	self:animate(newGui)
end

-- LifeCycle
function TreadmillSpeedPopup:Init(player: Player)
	self.SpeedController = knit.GetController("SpeedController")
	self.SpeedController.Signals.PopupEffect:Connect(function(change: number)
		self:new(player, change)
	end)
end

return TreadmillSpeedPopup
