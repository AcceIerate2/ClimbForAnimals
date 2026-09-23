-- Roblox Services
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Packages
local knit = require(ReplicatedStorage.src.Packages.knit)

-- Utility Modules
local NumberShortner = require(ReplicatedStorage.src.utility.NumberShortner)
local RarityStyle = require(ReplicatedStorage.src.utility.rarityStyle)
local PlayTween = require(ReplicatedStorage.src.utility.PlayTween)

-- Config Modules
local eggConfig = require(ReplicatedStorage.src.GameConfiguration.Gameplay.eggConfig)
local animalConfig = require(ReplicatedStorage.src.GameConfiguration.Gameplay.animalConfig)
local zoneConfig = require(ReplicatedStorage.src.GameConfiguration.Gameplay.zoneConfig)
local rarityColors = require(ReplicatedStorage.src.GameConfiguration.General.rarityColors)
local rarityGradients = require(ReplicatedStorage.src.GameConfiguration.General.rarityGradients)
local RebirthConfig = require(ReplicatedStorage.src.GameConfiguration.Economy.rebirthConfig)

-- Modules
local Preview = require(ReplicatedStorage.src.utility.animalPreview)
local asButton = require(ReplicatedStorage.src.utility.frameToButton)

-- Constants
local BackgroundBaseColor = Color3.fromRGB(25, 25, 25)
local BackgroundTintStrength = (152 - 25) / (255 - 25)
local ClaimableColor = Color3.fromRGB(0, 182, 24)
local SelectionTweenInfo = TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local DetailTweenInfo = TweenInfo.new(0.16, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

local IndexPanel = { Cards = {}, Biomes = {}, Connections = {}, Rewards = {} }

-- Private Methods
local function setProgress(frame, fullSize: UDim2, count: number, total: number)
	local fraction = total > 0 and count / total or 0
	frame.Number.Text = `{count}/{total}`
	frame.Bar.Size =
		UDim2.new(fullSize.X.Scale * fraction, fullSize.X.Offset * fraction, fullSize.Y.Scale, fullSize.Y.Offset)
end

local function paint(frame, rarity: string)
	frame.BackgroundColor3 = Color3.new(1, 1, 1)
	local gradient = frame:FindFirstChildOfClass("UIGradient")
	if not gradient then
		gradient = Instance.new("UIGradient")
		gradient.Parent = frame
	end
	local style = rarityGradients[rarity]
	local color = rarityColors[rarity] or Color3.new(1, 1, 1)
	local points = {}
	if style then
		for _, point in ipairs(style.Color.Keypoints) do
			table.insert(
				points,
				ColorSequenceKeypoint.new(point.Time, BackgroundBaseColor:Lerp(point.Value, BackgroundTintStrength))
			)
		end
	else
		local tint = BackgroundBaseColor:Lerp(color, BackgroundTintStrength)
		points = {
			ColorSequenceKeypoint.new(0, tint),
			ColorSequenceKeypoint.new(1, tint:Lerp(BackgroundBaseColor, 0.25)),
		}
	end
	gradient.Color = ColorSequence.new(points)
	gradient.Rotation = style and style.Rotation or 90
end

function IndexPanel:setSelected(card, selected: boolean)
	if not card then
		return
	end
	if card.SelectionTween then
		card.SelectionTween:Cancel()
	end
	local tween
	tween = PlayTween(card.Stroke, SelectionTweenInfo, {
		Color = selected and Color3.fromRGB(255, 245, 210) or card.StrokeColor,
		Thickness = selected and math.max(2, card.StrokeThickness + 1) or card.StrokeThickness,
		Transparency = selected and 0.1 or card.StrokeTransparency,
	}, function()
		if card.SelectionTween == tween then
			card.SelectionTween = nil
		end
	end)
	card.SelectionTween = tween
end

function IndexPanel:layoutDetailPreview()
	local height = self.Info.AbsoluteSize.Y
	if height <= 0 then
		return
	end
	local bottom = 1
	for _, label in ipairs({ self.Info:WaitForChild("Name"), self.Info.Rarity, self.Info.Earnings }) do
		bottom = math.min(bottom, (label.AbsolutePosition.Y - self.Info.AbsolutePosition.Y) / height)
	end
	self.Info.ViewportFrame.AnchorPoint = Vector2.new(0.5, 0)
	self.Info.ViewportFrame.Position = UDim2.fromScale(0.5, 0.04)
	self.Info.ViewportFrame.Size = UDim2.fromScale(0.92, math.max(0.1, bottom - 0.06))
end

function IndexPanel:select(name: string)
	self:setSelected(self.Cards[self.PreviewName], false)
	self.Controller.Selected = name
	self:setSelected(self.Cards[name], true)
	if self.PreviewName ~= name then
		if self.DetailTween then
			self.DetailTween:Cancel()
		end
		if self.DetailPreview then
			self.DetailPreview:Destroy()
		end
		self:layoutDetailPreview()
		self.DetailPreview = Preview.Create(self.Info.ViewportFrame, name, true, true)
		Preview.SetActive(self.DetailPreview, self.Panel.Visible)
		self.PreviewName = name
		self.Info.ViewportFrame.ImageTransparency = self.Panel.Visible and 1 or 0
		if self.Panel.Visible then
			local tween
			tween = PlayTween(self.Info.ViewportFrame, DetailTweenInfo, { ImageTransparency = 0 }, function()
				if self.DetailTween == tween then
					self.DetailTween = nil
				end
			end)
			self.DetailTween = tween
		end
	end
	self:updateDetails()
end

function IndexPanel:updateDetails()
	local name = self.Controller.Selected
	local card = name and self.Cards[name]
	if not card then
		self.ClaimBtn.Interactable = false
		return
	end

	local discovered = self.Data.Discovered[name] == true
	local claimed = self.Data.Claimed[name] == true
	local reward = self.Rewards[name]
	paint(self.Info, card.Rarity)
	self.Info:WaitForChild("Name").Text = discovered and name or "???"
	self.Info.Rarity.Text = card.Rarity
	self.Info.Earnings.Text = discovered and `${NumberShortner(animalConfig[name].CashPerSecond)}/s` or "???"
	RarityStyle.ApplyRarity(self.Info.Rarity, card.Rarity)
	Preview.SetDiscovered(self.Info.ViewportFrame, discovered)
	local rewardCash = (reward and reward.Cash or 0) * RebirthConfig.ForSource(self.CashMultiplier, "IndexRewards")
	rewardCash *= self.AllTimeCashMultiplier or 1
	self.RewardsFrame.CashReward.Reward.Text = `+${NumberShortner(rewardCash)}`
	self.RewardsFrame.SpeedReward.Reward.Text = `+{NumberShortner(reward and reward.Speed or 0)}`

	local available = discovered and not claimed and reward ~= nil and reward.Ready
	self.ClaimBtn.Active = available == true
	self.ClaimBtn.Interactable = available == true
	self.ClaimBtn.AutoButtonColor = available == true
	-- Green only while it can be claimed; Locked and Claimed keep the authored colour.
	self.ClaimBtn.BackgroundColor3 = available and ClaimableColor or self.ClaimBtnColor
	self.ClaimBtn.TextLabel.Text = claimed and "CLAIMED!"
		or not discovered and "LOCKED"
		or available and "CLAIM!"
		or "COMING SOON"
end

function IndexPanel:updateTotalProgress(unlocked: number, total: number)
	local claimable = 0
	for name in pairs(self.Data.Discovered) do
		local reward = self.Rewards[name]
		if self.Data.Claimed[name] ~= true and reward ~= nil and reward.Ready then
			claimable += 1
		end
	end

	local bar = self.TotalProgress
	bar.Active = claimable > 0
	bar.Interactable = claimable > 0
	if claimable > 0 then
		bar.Bar.Size = UDim2.new(1, 0, self.TotalFullSize.Y.Scale, self.TotalFullSize.Y.Offset)
		bar.Number.Text = `Claim ALL! ({claimable})`
		return
	end

	setProgress(bar, self.TotalFullSize, unlocked, total)
end

function IndexPanel:refresh()
	local total, unlocked = 0, 0
	for _, biome in ipairs(self.Biomes) do
		local count = 0
		for _, name in ipairs(biome.Animals) do
			local card = self.Cards[name]
			local discovered = self.Data.Discovered[name] == true
			card.Frame:WaitForChild("Name").Text = discovered and name or "???"
			Preview.SetDiscovered(card.Viewport, discovered)
			if discovered then
				count += 1
			end
		end
		setProgress(biome.Frame.ProgressBar, biome.FullSize, count, #biome.Animals)
		total += #biome.Animals
		unlocked += count
	end
	self:updateTotalProgress(unlocked, total)
	self:updateDetails()
end

local function overlaps(frame: GuiObject, container: ScrollingFrame): boolean
	local point, size = frame.AbsolutePosition, frame.AbsoluteSize
	local clip, clipSize = container.AbsolutePosition, container.AbsoluteWindowSize
	return frame.Visible
		and size.X > 0
		and size.Y > 0
		and point.X < clip.X + clipSize.X
		and point.X + size.X > clip.X
		and point.Y < clip.Y + clipSize.Y
		and point.Y + size.Y > clip.Y
end

function IndexPanel:loadPreviews()
	for name, card in pairs(self.Cards) do
		local visible = self.Panel.Visible and overlaps(card.Frame, self.Container)
		if visible and not card.Preview then
			card.Preview = Preview.Create(card.Viewport, name, true)
		end
		Preview.SetActive(card.Preview, visible)
	end
	Preview.SetActive(self.DetailPreview, self.Panel.Visible)
end

function IndexPanel:queuePreviews()
	if self.PreviewUpdateQueued or self.Destroyed then
		return
	end
	self.PreviewUpdateQueued = true
	task.defer(function()
		self.PreviewUpdateQueued = false
		if not self.Destroyed then
			self:loadPreviews()
		end
	end)
end

function IndexPanel:build()
	local groups, seen = {}, {}
	local eggNames = {}
	for name in pairs(eggConfig.Eggs) do
		table.insert(eggNames, name)
	end
	table.sort(eggNames)
	for _, eggName in ipairs(eggNames) do
		local egg = eggConfig.Eggs[eggName]
		if animalConfig[egg.Animal] and zoneConfig[egg.Biome] and not seen[egg.Animal] then
			seen[egg.Animal] = true
			groups[egg.Biome] = groups[egg.Biome] or {}
			table.insert(groups[egg.Biome], { Name = egg.Animal, Rarity = egg.Rarity })
		end
	end

	local ordered = {}
	for biome in pairs(groups) do
		table.insert(ordered, biome)
	end
	table.sort(ordered, function(a, b)
		return zoneConfig[a].Height < zoneConfig[b].Height
	end)
	for order, biome in ipairs(ordered) do
		local frame = self.Container:FindFirstChild(biome)
			or (biome == "Mystic Isles" and self.Container:FindFirstChild("Mistic Isles"))
		if not frame then
			warn(`Index is missing the biome frame: {biome}`)
			continue
		end
		frame.LayoutOrder = order
		local entries = groups[biome]
		table.sort(entries, function(a, b)
			local aIncome, bIncome = animalConfig[a.Name].CashPerSecond, animalConfig[b.Name].CashPerSecond
			return if aIncome == bIncome then a.Name < b.Name else aIncome < bIncome
		end)
		local record = { Frame = frame, Animals = {}, FullSize = frame.ProgressBar.Bar.Size }
		table.insert(self.Biomes, record)
		for _, child in ipairs(frame:GetChildren()) do
			if child:IsA("GuiObject") and tonumber(child.Name) then
				child.Visible = false
			end
		end

		for index, entry in ipairs(entries) do
			local card = frame:FindFirstChild(tostring(index))
			if not card then
				warn(`Index is missing {biome} card {index} for {entry.Name}`)
				continue
			end
			card = asButton(card)
			local anchorDelta = Vector2.new(0.5, 0.5) - card.AnchorPoint
			local position, size = card.Position, card.Size
			card.Position = UDim2.new(
				position.X.Scale + size.X.Scale * anchorDelta.X,
				position.X.Offset + size.X.Offset * anchorDelta.X,
				position.Y.Scale + size.Y.Scale * anchorDelta.Y,
				position.Y.Offset + size.Y.Offset * anchorDelta.Y
			)
			card.AnchorPoint = Vector2.new(0.5, 0.5)
			card.Visible = true
			paint(card, entry.Rarity)
			local viewport = Instance.new("ViewportFrame")
			viewport.Name = "AnimalViewport"
			viewport.BackgroundTransparency = 1
			viewport.Size = UDim2.fromScale(0.9, 0.7)
			viewport.Position = UDim2.fromScale(0.05, 0.26)
			viewport.ZIndex = card.ZIndex + 2
			viewport.Parent = card
			card:WaitForChild("Name").ZIndex = viewport.ZIndex + 1

			self.ButtonsController:Unlink(card)
			card:SetAttribute("Type", "Action")
			card:SetAttribute("Action", "SelectIndexAnimal")
			card:SetAttribute("AnimalName", entry.Name)
			card.Active = true
			card.Interactable = true
			CollectionService:AddTag(card, "GuiButton")
			self.ButtonsController:Link(card)
			local stroke = card:FindFirstChildOfClass("UIStroke")
			if not stroke then
				stroke = Instance.new("UIStroke")
				stroke.Transparency = 1
				stroke.Parent = card
			end
			local data = {
				Frame = card,
				Viewport = viewport,
				Rarity = entry.Rarity,
				Button = card,
				Stroke = stroke,
				StrokeColor = stroke.Color,
				StrokeThickness = stroke.Thickness,
				StrokeTransparency = stroke.Transparency,
				Preview = nil,
			}
			self.Cards[entry.Name] = data
			table.insert(record.Animals, entry.Name)
			table.insert(
				self.Connections,
				viewport:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
					if data.Preview then
						data.Preview:Refit()
					end
				end)
			)
			self.FirstAnimal = self.FirstAnimal or entry.Name
		end
	end
end

-- LifeCycle
function IndexPanel:Init(player: Player)
	self.Controller = knit.GetController("IndexController")
	local buttons = knit.GetController("ButtonsController")
	self.ButtonsController = buttons
	local dataController = knit.GetController("DataController")
	self.Panel = player.PlayerGui:WaitForChild("Panels"):WaitForChild("Index")
	local content = self.Panel.Body.Content
	self.Info = content.AnimalInfo
	self.RewardsFrame = content.Rewards
	self.ClaimBtn = self.RewardsFrame.ClaimBtn
	self.ClaimBtnColor = self.ClaimBtn.BackgroundColor3
	self.TotalProgress = asButton(content.TotalProgressBar)
	self.TotalFullSize = self.TotalProgress.Bar.Size
	self.Container = content.Holder.ScrollingFrame
	self.Data = dataController:GetValue("AnimalIndex")
	self.CashMultiplier = dataController:GetValue("CashMultiplier")
	self.AllTimeCashMultiplier = dataController:GetValue("AllTimeCashMultiplier")
	table.insert(
		self.Connections,
		dataController:GetValueChangedSignal("AllTimeCashMultiplier"):Connect(function(value)
			self.AllTimeCashMultiplier = value
			self:updateDetails()
		end)
	)
	table.insert(
		self.Connections,
		dataController:GetValueChangedSignal("CashMultiplier"):Connect(function(value)
			self.CashMultiplier = value
			self:updateDetails()
		end)
	)
	table.insert(
		self.Connections,
		self.Controller.SelectionChanged:Connect(function(name)
			if self.Cards[name] then
				self:select(name)
			end
		end)
	)
	self:build()
	for _, property in ipairs({ "CanvasPosition", "AbsolutePosition", "AbsoluteSize" }) do
		table.insert(
			self.Connections,
			self.Container:GetPropertyChangedSignal(property):Connect(function()
				self:queuePreviews()
			end)
		)
	end
	table.insert(
		self.Connections,
		self.Info:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
			self:layoutDetailPreview()
		end)
	)
	self:refresh()
	if self.FirstAnimal then
		self:select(self.FirstAnimal)
	end

	buttons:Unlink(self.ClaimBtn)
	self.ClaimBtn:SetAttribute("Type", "Action")
	self.ClaimBtn:SetAttribute("Action", "ClaimIndexReward")
	CollectionService:AddTag(self.ClaimBtn, "GuiButton")
	buttons:Link(self.ClaimBtn)

	buttons:Unlink(self.TotalProgress)
	self.TotalProgress:SetAttribute("Type", "Action")
	self.TotalProgress:SetAttribute("Action", "ClaimAllIndexReward")
	CollectionService:AddTag(self.TotalProgress, "GuiButton")
	buttons:Link(self.TotalProgress)

	-- Use the existing panel toggler for authored open/close buttons.
	local close = self.Panel:FindFirstChild("Close", true) or self.Panel.Header:FindFirstChild("Shop")
	if close and close:IsA("GuiButton") then
		buttons:Unlink(close)
		close:SetAttribute("Type", "PanelToggler")
		close:SetAttribute("PanelName", "Index")
		CollectionService:AddTag(close, "GuiButton")
		buttons:Link(close)
	end

	table.insert(
		self.Connections,
		dataController:GetValueChangedSignal("AnimalIndex"):Connect(function(data)
			self.Data = data
			self:refresh()
		end)
	)
	table.insert(
		self.Connections,
		self.Panel:GetPropertyChangedSignal("Visible"):Connect(function()
			if self.Panel.Visible then
				self:layoutDetailPreview()
			end
			self:queuePreviews()
		end)
	)
	table.insert(
		self.Connections,
		self.Info.ViewportFrame:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
			if self.DetailPreview then
				self.DetailPreview:Refit()
			end
		end)
	)
	self.Controller.IndexService
		:GetRewards()
		:andThen(function(rewards)
			if self.Destroyed then
				return
			end
			self.Rewards = rewards
			self:refresh()
		end)
		:catch(warn)
	if self.Panel.Visible then
		self:loadPreviews()
	end

	self.Panel.Destroying:Once(function()
		self.Destroyed = true
		if self.DetailTween then
			self.DetailTween:Cancel()
		end
		for _, connection in ipairs(self.Connections) do
			connection:Disconnect()
		end
		for _, card in pairs(self.Cards) do
			if card.SelectionTween then
				card.SelectionTween:Cancel()
			end
			buttons:Unlink(card.Button)
			if card.Preview then
				card.Preview:Destroy()
			end
		end
		if self.DetailPreview then
			self.DetailPreview:Destroy()
		end
		buttons:Unlink(self.ClaimBtn)
		buttons:Unlink(self.TotalProgress)
		if close then
			buttons:Unlink(close)
		end
		table.clear(self.Connections)
		table.clear(self.Cards)
		table.clear(self.Biomes)
	end)
end

return IndexPanel
