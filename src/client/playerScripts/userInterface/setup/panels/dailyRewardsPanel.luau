-- Panels/DailyRewards: every day frame (Body/1, Body/2...) is filled from dailyRewardsConfig, so
-- adding a day is a config entry plus a frame with the same children.

-- Roblox Services
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

-- Packages
local knit = require(ReplicatedStorage.src.Packages.knit)

-- Utility Modules
local NumberShortner = require(ReplicatedStorage.src.utility.NumberShortner)
local EggHandler = require(ReplicatedStorage.src.utility.eggHandler)
local RarityStyle = require(ReplicatedStorage.src.utility.rarityStyle)
local AnimalPreview = require(ReplicatedStorage.src.utility.animalPreview)
local asButton = require(ReplicatedStorage.src.utility.frameToButton)

-- Config Modules
local Config = require(ReplicatedStorage.src.GameConfiguration.Economy.dailyRewardsConfig)
local tutorialConfig = require(ReplicatedStorage.src.GameConfiguration.Gameplay.tutorialConfig)

-- Constants
local Gradients = ReplicatedStorage:WaitForChild("Assets"):WaitForChild("DailyRewards")
local ClaimGradient = Gradients:WaitForChild("Claim")
local NotReadyGradient = Gradients:WaitForChild("NotReady")
local RefreshInterval = 1
local OpenOnJoinDelay = 1.5 -- lets the offline earnings panel open first, it takes priority
local OfflinePanelName = "OfflineEarnings"

-- Helper Functions
local function formatTime(seconds: number): string
	local whole = math.max(math.ceil(seconds), 0)
	return string.format("%dh %02dm %02ds", whole // 3600, whole % 3600 // 60, whole % 60)
end

local function rewardName(reward): string
	if reward.Type == "Cash" then
		return `${NumberShortner(reward.Amount)}`
	end
	return reward.Animal
end

-->
local DailyRewardsPanel = { Days = {}, Connections = {}, LinkedButtons = {}, SpecialGradients = {} }

-- Private Methods
function DailyRewardsPanel:link(button: GuiButton, buttonType: string, key: string, value: string)
	self.Buttons:Unlink(button)
	button:SetAttribute("Type", buttonType)
	button:SetAttribute(key, value)
	CollectionService:AddTag(button, "GuiButton")
	self.Buttons:Link(button)
	table.insert(self.LinkedButtons, button)
end

-- Day, prize, rarity and the picture never change, so they are set once.
function DailyRewardsPanel:buildDay(index: number, reward, frame: GuiObject)
	-- The whole day card is the button (with the usual hover); Area only shows its status.
	frame = asButton(frame)
	local requirements = frame:WaitForChild("Requirements")
	local area = requirements:WaitForChild("Area")
	local label = area:WaitForChild("Text") :: TextLabel
	for _, child in ipairs(label:GetChildren()) do
		if child:IsA("UIGradient") then
			child:Destroy()
		end
	end

	local record = {
		Reward = reward,
		Frame = frame,
		Area = area,
		Label = label,
		Claimed = frame:WaitForChild("Claimed"),
		ClaimGradient = ClaimGradient:Clone(),
		NotReadyGradient = NotReadyGradient:Clone(),
	}

	frame:WaitForChild("Day").Text = `Day {index}`
	frame:WaitForChild("Prize").Text = rewardName(reward)

	local rarityLabel = frame:WaitForChild("Rarity")
	local icon = requirements:WaitForChild("Icon")
	local viewport = requirements:WaitForChild("ViewportFrame")
	if reward.Type == "Cash" then
		rarityLabel.Text = Config.CashRarityText
		icon.Image = Config.CashIcon
		icon.Visible = true
		viewport.Visible = false
	else
		local rarity = EggHandler.GetRarity(reward.Animal)
		rarityLabel.Text = rarity or ""
		RarityStyle.ApplyRarity(rarityLabel, rarity)
		icon.Visible = false
		viewport.Visible = true
		record.Preview = AnimalPreview.Create(viewport, reward.Animal, true, false, Config.ViewportPadding)
		table.insert(
			self.Connections,
			viewport:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
				if record.Preview then
					record.Preview:Refit()
				end
			end)
		)
	end

	frame:SetAttribute("Day", index)
	self:link(frame, "Action", "Action", "ClaimDailyReward")
	-- Special turns the card background and the rarity text; AnimatedRarity turns the text only.
	local holders = {}
	if reward.Special then
		table.insert(holders, requirements)
	end
	if reward.Special or reward.AnimatedRarity then
		table.insert(holders, rarityLabel)
	end
	for _, holder in ipairs(holders) do
		local gradient = holder:FindFirstChildOfClass("UIGradient")
		if gradient then
			table.insert(self.SpecialGradients, { Gradient = gradient, BaseRotation = gradient.Rotation })
		end
	end
	self.Days[index] = record
end

function DailyRewardsPanel:setGradient(record, gradient: UIGradient)
	if record.Gradient == gradient then
		return
	end
	if record.Gradient then
		record.Gradient.Parent = nil
	end
	gradient.Parent = record.Label
	record.Gradient = gradient
end

function DailyRewardsPanel:refresh()
	local state = Config.GetState(self.Data:GetValue("DailyRewards"), workspace:GetServerTimeNow())

	for index, record in pairs(self.Days) do
		local claimed = index < state.Day
		local ready = index == state.Day and state.Ready

		record.Claimed.Visible = claimed
		-- Special days never show "Not Ready!": their button only appears once they can be claimed.
		record.Area.Visible = not claimed and (ready or not record.Reward.Special)
		record.Label.Text = ready and "CLAIM!" or "Not Ready!"
		self:setGradient(record, ready and record.ClaimGradient or record.NotReadyGradient)
	end

	if state.Finished then
		self.TimeStatus.Text = "All Rewards Collected!"
	elseif state.Ready then
		self.TimeStatus.Text = "You Have A Reward To Collect!"
	else
		self.TimeStatus.Text = `Next Reward in: {formatTime(state.ReadyAt - workspace:GetServerTimeNow())}`
	end
end

function DailyRewardsPanel:setPreviewsActive(active: boolean)
	for _, record in pairs(self.Days) do
		AnimalPreview.SetActive(record.Preview, active)
	end
end

-- Shown when there is a reward waiting: on join for a player who finished the tutorial, and right
-- after the tutorial ends for a new one. The offline earnings panel always goes first.
function DailyRewardsPanel:tutorialDone(): boolean
	if not tutorialConfig.Enabled then
		return true
	end
	local tutorial = self.Data:GetValue("Tutorial")
	return tutorial ~= nil and tutorial.Completed == true
end

function DailyRewardsPanel:hasRewardReady(): boolean
	return Config.GetState(self.Data:GetValue("DailyRewards"), workspace:GetServerTimeNow()).Ready
end

function DailyRewardsPanel:openWhenFree()
	if self.Opening or self.Destroyed then
		return
	end
	self.Opening = true

	if self.PanelController.ActivePanel == OfflinePanelName then
		self.PanelController:WaitForPanelToClose(OfflinePanelName)
		task.wait(0.3)
	end

	if
		not self.Destroyed
		and self:hasRewardReady()
		and self.PanelController.ActivePanel == nil
		and not self.Panel.Visible
	then
		self.PanelController:TogglePanel("DailyRewards")
	end
	self.Opening = false
end

function DailyRewardsPanel:openOnJoin()
	task.wait(OpenOnJoinDelay)
	if self.Destroyed or not self:hasRewardReady() then
		return
	end

	if self:tutorialDone() then
		self:openWhenFree()
		return
	end

	-- New player: wait for the tutorial to finish, then open once.
	local connection
	connection = self.Data:GetValueChangedSignal("Tutorial"):Connect(function()
		if self:tutorialDone() then
			connection:Disconnect()
			task.spawn(function()
				self:openWhenFree()
			end)
		end
	end)
	table.insert(self.Connections, connection)
end

-- LifeCycle
function DailyRewardsPanel:Init(player: Player)
	self.Buttons = knit.GetController("ButtonsController")
	self.Data = knit.GetController("DataController")
	self.PanelController = knit.GetController("PanelController")
	self.Panel = player.PlayerGui:WaitForChild("Panels"):WaitForChild("DailyRewards")
	local body = self.Panel:WaitForChild("Body")
	self.TimeStatus = body:WaitForChild("TimeStatus")

	for index, reward in ipairs(Config.Days) do
		local frame = body:FindFirstChild(tostring(index))
		if frame then
			self:buildDay(index, reward, frame)
		else
			warn(`DailyRewards is missing the frame for Day {index} (Body/{index})`)
		end
	end

	local close = self.Panel:WaitForChild("Header"):FindFirstChild("Close")
	if close and close:IsA("GuiButton") then
		self:link(close, "PanelToggler", "PanelName", "DailyRewards")
	end

	table.insert(
		self.Connections,
		self.Data:GetValueChangedSignal("DailyRewards"):Connect(function()
			self:refresh()
		end)
	)
	table.insert(
		self.Connections,
		self.Panel:GetPropertyChangedSignal("Visible"):Connect(function()
			self:setPreviewsActive(self.Panel.Visible)
			self:refresh()
		end)
	)
	self:setPreviewsActive(self.Panel.Visible)
	self:refresh()

	-- Special days: the card gradient turns slowly, only while the panel is open.
	if #self.SpecialGradients > 0 and Config.SpecialGradientSeconds > 0 then
		local elapsed = 0
		table.insert(
			self.Connections,
			RunService.RenderStepped:Connect(function(deltaTime: number)
				if not self.Panel.Visible then
					return
				end
				elapsed = (elapsed + deltaTime) % Config.SpecialGradientSeconds
				local turn = elapsed / Config.SpecialGradientSeconds * 360
				for _, entry in ipairs(self.SpecialGradients) do
					entry.Gradient.Rotation = (entry.BaseRotation + turn) % 360
				end
			end)
		)
	end

	task.spawn(function()
		self:openOnJoin()
	end)

	task.spawn(function()
		while not self.Destroyed do
			task.wait(RefreshInterval)
			if self.Panel.Visible then
				self:refresh()
			end
		end
	end)

	self.Panel.Destroying:Once(function()
		self.Destroyed = true
		for _, connection in ipairs(self.Connections) do
			connection:Disconnect()
		end
		for _, button in ipairs(self.LinkedButtons) do
			self.Buttons:Unlink(button)
		end
		for _, record in pairs(self.Days) do
			if record.Preview then
				record.Preview:Destroy()
			end
		end
		table.clear(self.Connections)
		table.clear(self.Days)
	end)
end

return DailyRewardsPanel
