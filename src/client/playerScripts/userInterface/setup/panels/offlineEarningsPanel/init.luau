-- Roblox Services
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Packages
local knit = require(ReplicatedStorage.src.Packages.knit)

-- Utility Modules
local FormatTime = require(ReplicatedStorage.src.utility.FormatTime)
local NumberShortner = require(ReplicatedStorage.src.utility.NumberShortner)
local PlayTween = require(ReplicatedStorage.src.utility.PlayTween)

-- Tween Config
local CountTweenInfo = TweenInfo.new(0.9, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local PopTweenInfo = TweenInfo.new(0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local ResetTweenInfo = TweenInfo.new(0.25, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
local PopScale = 1.15
local TickInterval = 0.07

-->
local OfflineEarningsPanel = {}

-- Private Methods
function OfflineEarningsPanel:updateTime(seconds: number)
	self.TimeOffline.Text = `Time Offline: {FormatTime(math.floor(seconds), false)}`
end

function OfflineEarningsPanel:updateEarnings(amount: number)
	self.PendingAmount = amount
	self:stopAnimation()

	if amount <= 0 or not self.Panel.Visible then
		self.DisplayedCash.Value = amount
		return
	end

	self:animateEarnings()
end

function OfflineEarningsPanel:stopAnimation()
	self.Counting = false
	self.AnimationRevision = (self.AnimationRevision or 0) + 1
	if self.ActiveTween then
		local tween = self.ActiveTween
		self.ActiveTween = nil
		tween:Cancel()
	end

	if self.EarningsScale then
		self.EarningsScale.Scale = self.DefaultScale
	end
end

function OfflineEarningsPanel:playAnimationTween(instance: Instance, tweenInfo: TweenInfo, properties, onComplete)
	local revision = self.AnimationRevision
	self.ActiveTween = PlayTween(instance, tweenInfo, properties, function()
		if self.AnimationRevision ~= revision then
			return
		end

		self.ActiveTween = nil
		if onComplete then
			onComplete()
		end
	end)
end

function OfflineEarningsPanel:animateEarnings()
	self:stopAnimation()
	if self.PendingAmount <= 0 then
		return
	end

	self.DisplayedCash.Value = 0
	self.Counting = true
	self.NextTick = 0
	self:playAnimationTween(self.DisplayedCash, CountTweenInfo, { Value = self.PendingAmount }, function()
		self.Counting = false
		self.AudioController:PlaySfx("Cash", { PlayOver = true, Parent = self.Earnings })

		self:playAnimationTween(self.EarningsScale, PopTweenInfo, { Scale = self.DefaultScale * PopScale }, function()
			self:playAnimationTween(self.EarningsScale, ResetTweenInfo, { Scale = self.DefaultScale })
		end)
	end)
end

-- LifeCycle
function OfflineEarningsPanel:Destroy()
	self:stopAnimation()

	for _, connection in pairs(self.Connections or {}) do
		connection:Disconnect()
	end

	self.Connections = nil
	if self.DisplayedCash then
		self.DisplayedCash:Destroy()
		self.DisplayedCash = nil
	end

	if self.CreatedScale and self.EarningsScale then
		self.EarningsScale:Destroy()
	end
	self.EarningsScale = nil
	self.CreatedScale = nil
	self.Panel = nil
	self.TimeOffline = nil
	self.Earnings = nil
end

function OfflineEarningsPanel:Init(player: Player)
	self:Destroy()

	self.Panel = player.PlayerGui:WaitForChild("Panels"):WaitForChild("OfflineEarnings")
	local content = self.Panel:WaitForChild("Body"):WaitForChild("Content")
	self.TimeOffline = content:WaitForChild("TimeOffline")
	self.Earnings = content:WaitForChild("Earnings")
	self.EarningsScale = self.Earnings:FindFirstChildOfClass("UIScale")
	self.CreatedScale = self.EarningsScale == nil
	if not self.EarningsScale then
		self.EarningsScale = Instance.new("UIScale")
		self.EarningsScale.Parent = self.Earnings
	end
	self.DefaultScale = self.EarningsScale.Scale

	self.DisplayedCash = Instance.new("NumberValue")
	self.DisplayedCash.Name = "DisplayedOfflineCash"
	self.DisplayedCash.Parent = self.Earnings
	self.Earnings.Text = "$0"
	self.AudioController = knit.GetController("AudioController")
	self.DisplayedCash.Changed:Connect(function(amount: number)
		local text = `${NumberShortner(math.round(amount))}`
		local changed = self.Earnings.Text ~= text
		self.Earnings.Text = text

		local now = os.clock()
		if self.Counting and self.Panel.Visible and changed and now >= self.NextTick then
			self.NextTick = now + TickInterval
			self.AudioController:PlaySfx("Tick", { PlayOver = true, Parent = self.Earnings })
		end
	end)

	self.DataController = knit.GetController("DataController")
	local timeChanged = self.DataController:GetValueChangedSignal("LastOfflineSeconds")
	local cashChanged = self.DataController:GetValueChangedSignal("PendingOfflineCash")

	self:updateTime(self.DataController:GetValue("LastOfflineSeconds"))
	self:updateEarnings(self.DataController:GetValue("PendingOfflineCash"))

	self.Connections = {
		timeChanged:Connect(function(seconds: number)
			self:updateTime(seconds)
		end),
		cashChanged:Connect(function(amount: number)
			self:updateEarnings(amount)
		end),
		self.Panel:GetPropertyChangedSignal("Visible"):Connect(function()
			if self.Panel.Visible then
				self:animateEarnings()
			else
				self:stopAnimation()
			end
		end),
		self.Panel.Destroying:Once(function()
			self:Destroy()
		end),
	}
end

return OfflineEarningsPanel
