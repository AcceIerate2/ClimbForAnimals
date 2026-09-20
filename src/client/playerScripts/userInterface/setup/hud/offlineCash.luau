-- Hud/OfflineCash: how much the plot pays for a full absence, shown only while the player is
-- standing on their own plot.

-- Roblox Services
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Packages
local knit = require(ReplicatedStorage.src.Packages.knit)

-- Utility Modules
local NumberShortner = require(ReplicatedStorage.src.utility.NumberShortner)
local PlayTween = require(ReplicatedStorage.src.utility.PlayTween)

-- Constants
local Player = Players.LocalPlayer
local PollInterval = 0.25 -- how often the plot test runs
local RefreshInterval = 3 -- how often the amount is asked for again while standing there
local VerticalSlack = 20 -- studs above the plot that still count as being on it
local FadeTweenInfo = TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
-- The same green the floating income popup uses, so every cash figure reads alike.
local CashColor = "rgb(166, 255, 0)"

-->
local OfflineCash = {}

-- Private Methods
-- Inside the fence, not merely inside the plot model: the fence enclosure is the same bound
-- egg placement uses (eggPlacementService.getPlotBounds), so both agree on what the plot is.
-- Looked up every tick because upgrading the base destroys the Fences model and clones a new one.
function OfflineCash:isOnPlot(): boolean
	local base = self.BaseController:GetBase()
	local fences = base and base:FindFirstChild("Fences")
	local character = Player.Character
	local rootPart = character and character:FindFirstChild("HumanoidRootPart")
	if not fences or not fences.Parent or not rootPart then
		return false
	end

	local boxCFrame, boxSize = fences:GetBoundingBox()
	local localPosition = boxCFrame:PointToObjectSpace(rootPart.Position)
	local half = boxSize / 2

	return math.abs(localPosition.X) <= half.X
		and math.abs(localPosition.Z) <= half.Z
		and localPosition.Y >= -half.Y
		and localPosition.Y <= half.Y + VerticalSlack
end

function OfflineCash:setShown(shown: boolean)
	if self.Shown == shown then
		return
	end

	self.Shown = shown
	if self.Tween then
		self.Tween:Cancel()
	end

	if shown then
		self.Frame.Visible = true
		self.Label.TextTransparency = 1
		if self.Stroke then
			self.Stroke.Transparency = 1
		end
	end

	if self.Stroke then
		PlayTween(self.Stroke, FadeTweenInfo, { Transparency = shown and self.StrokeTransparency or 1 })
	end

	self.Tween = PlayTween(
		self.Label,
		FadeTweenInfo,
		{ TextTransparency = shown and self.TextTransparency or 1 },
		function()
			if not self.Shown then
				self.Frame.Visible = false
			end
		end
	)
end

-- An empty plot pays nothing, and a banner saying so is worse than no banner.
function OfflineCash:refresh()
	self.CashFlowService
		:GetOfflineEstimate()
		:andThen(function(amount: number)
			if typeof(amount) ~= "number" or amount ~= amount then
				amount = 0
			end

			self.Amount = amount
			if amount > 0 then
				local cash = `<font color="{CashColor}">${NumberShortner(math.round(amount))}</font>`
				self.Label.Text = `You Make {cash}/Day Offline 😈`
			end

			self:setShown(self.OnPlot and amount > 0)
		end)
		:catch(warn)
end

-- LifeCycle
function OfflineCash:Init(player: Player)
	self.CashFlowService = knit.GetService("CashFlowService")
	self.BaseController = knit.GetController("BaseController")

	self.Frame = player.PlayerGui:WaitForChild("Hud"):WaitForChild("OfflineCash")
	self.Label = self.Frame:WaitForChild("Time")
	self.Stroke = self.Label:FindFirstChildOfClass("UIStroke")
	self.TextTransparency = self.Label.TextTransparency
	self.StrokeTransparency = self.Stroke and self.Stroke.Transparency or 0
	self.Frame.Visible = false
	self.Shown = false
	self.OnPlot = false
	self.Amount = 0

	task.spawn(function()
		local nextRefresh = 0
		while true do
			local onPlot = self:isOnPlot()
			if onPlot ~= self.OnPlot then
				self.OnPlot = onPlot
				if onPlot then
					nextRefresh = os.clock() + RefreshInterval
					self:refresh()
				else
					self:setShown(false)
				end
			elseif onPlot and os.clock() >= nextRefresh then
				nextRefresh = os.clock() + RefreshInterval
				self:refresh()
			end

			task.wait(PollInterval)
		end
	end)
end

return OfflineCash
