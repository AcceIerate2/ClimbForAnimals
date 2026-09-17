-- Roblox Services
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Packages
local knit = require(ReplicatedStorage.src.Packages.knit)

-- Utility Modules
local WaitForUiDesc = require(ReplicatedStorage.src.utility.WaitForUiDesc)
local NumberShortner = require(ReplicatedStorage.src.utility.NumberShortner)
local PlayTween = require(ReplicatedStorage.src.utility.PlayTween)

-- Tween Config
local CountTweenInfo = TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

-->
local CashGui = {}

-- Private Methods
function CashGui:updateCash(newValue: number)
	if self.ActiveTween then
		local tween = self.ActiveTween
		self.ActiveTween = nil
		tween:Cancel()
	end

	-- Continue from the displayed amount if another change arrives mid-tween.
	local tween
	tween = PlayTween(self.DisplayedCash, CountTweenInfo, {
		Value = newValue,
	}, function()
		if self.ActiveTween == tween then
			self.ActiveTween = nil
		end
	end)
	self.ActiveTween = tween
end

-- LifeCycle
function CashGui:Destroy()
	if self.CashConnection then
		self.CashConnection:Disconnect()
		self.CashConnection = nil
	end

	if self.DestroyConnection then
		self.DestroyConnection:Disconnect()
		self.DestroyConnection = nil
	end

	if self.ActiveTween then
		local tween = self.ActiveTween
		self.ActiveTween = nil
		tween:Cancel()
	end

	if self.DisplayedCash then
		self.DisplayedCash:Destroy()
		self.DisplayedCash = nil
	end

	self.TextLabel = nil
end

function CashGui:Init(player: Player)
	self:Destroy()

	self.TextLabel = WaitForUiDesc(player.PlayerGui:WaitForChild("Hud"), "TextLabel", {
		Name = "CashAmount",
	})

	self.DataController = knit.GetController("DataController")
	local cashChanged = self.DataController:GetValueChangedSignal("Cash")
	local currentCash = self.DataController:GetValue("Cash")

	self.DisplayedCash = Instance.new("NumberValue")
	self.DisplayedCash.Name = "DisplayedCash"
	self.DisplayedCash.Value = currentCash
	self.DisplayedCash.Parent = self.TextLabel
	self.TextLabel.Text = NumberShortner(currentCash)

	self.DisplayedCash.Changed:Connect(function(value: number)
		self.TextLabel.Text = NumberShortner(math.round(value))
	end)

	self.CashConnection = cashChanged:Connect(function(newValue: number)
		self:updateCash(newValue)
	end)

	self.DestroyConnection = self.TextLabel.Destroying:Once(function()
		self:Destroy()
	end)
end

return CashGui
