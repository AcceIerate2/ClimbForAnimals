-- Roblox Services
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Packages
local knit = require(ReplicatedStorage.src.Packages.knit)

-- Config Modules
local Config = require(ReplicatedStorage.src.GameConfiguration.Economy.rebirthConfig)

-- Utility Modules
local NumberShortner = require(ReplicatedStorage.src.utility.NumberShortner)

-- Helper Functions
local function setText(label, text)
	if label and (label:IsA("TextLabel") or label:IsA("TextButton")) then
		label.Text = text
	end
end

local function enabled(button, value)
	button.Active = value
	button.Interactable = value
	button.AutoButtonColor = value
end

-->
local RebirthPanel = {
	Connections = {},
	Data = {},
	LinkedButtons = {},
}

-- Private Methods
function RebirthPanel:update()
	local count = self.Data.Rebirths or 0
	local capped = Config.MaxRebirths > 0 and count >= Config.MaxRebirths
	local requirements = Config.GetRequirements(count)
	local lines, keys = {}, {}

	for key in pairs(requirements) do
		table.insert(keys, key)
	end

	table.sort(keys)
	local fraction = 1
	local valid = true

	for _, key in ipairs(keys) do
		local required = requirements[key]
		local current = self.Data[key] or 0
		valid = valid and required >= 0 and required < math.huge
		fraction = math.min(fraction, required > 0 and math.clamp(current / required, 0, 1) or 1)
		table.insert(lines, `{key} {NumberShortner(current)} / {NumberShortner(required)}`)
	end

	local nextMultiplier = Config.GetMultiplier(count + 1)
	valid = valid and nextMultiplier > 0 and nextMultiplier < math.huge and count + 1 < 2 ^ 53

	setText(self.Title, capped and "MAX REBIRTH" or `REBIRTH {count + 1}`)
	setText(self.Number, capped and "MAX" or table.concat(lines, " | "))
	self.Bar.Size = UDim2.new(capped and 1 or fraction, 0, self.Bar.Size.Y.Scale, self.Bar.Size.Y.Offset)
	setText(self.Now, `x{self.Data.CashMultiplier or Config.GetMultiplier(count)} Cash`)
	setText(self.Next, capped and "MAX" or `x{nextMultiplier} Cash`)

	local available = Config.Enabled and not capped and valid and not self.Controller.Pending
	-- Let the server explain unmet requirements instead of disabling the button.
	enabled(self.Rebirth, true)

	local credits = self.Data.RebirthPurchases and self.Data.RebirthPurchases.Credits or 0
	enabled(self.Skip, available and Config.Skip.Enabled and (credits > 0 or self.Controller.ProductId ~= nil))

	local resetNames = {}

	for key, value in pairs(Config.Reset) do
		if value ~= false then
			table.insert(resetNames, key)
		end
	end

	if Config.RemoveAnimals then
		table.insert(resetNames, "Animals")
	end

	if Config.RemoveEggs then
		table.insert(resetNames, "Eggs")
	end

	table.sort(resetNames)
	setText(
		self.Warning,
		#resetNames > 0 and `Your {table.concat(resetNames, ", ")} Will Reset!` or "Your progress will be kept!"
	)
end

function RebirthPanel:link(button, action)
	self.Buttons:Unlink(button)
	button:SetAttribute("Type", "Action")
	button:SetAttribute("Action", action)
	CollectionService:AddTag(button, "GuiButton")
	self.Buttons:Link(button)
	table.insert(self.LinkedButtons, button)
end

-- LifeCycle
function RebirthPanel:Init(player: Player)
	self.Controller = knit.GetController("RebirthController")
	self.Buttons = knit.GetController("ButtonsController")
	local dataController = knit.GetController("DataController")

	self.Frame = player.PlayerGui:WaitForChild("Panels"):WaitForChild("Rebirth")
	local content = self.Frame:WaitForChild("Body"):WaitForChild("Content")
	local progress = content:WaitForChild("Requirements"):WaitForChild("ProgressBar")
	self.Bar = progress:WaitForChild("Bar")
	self.Number = progress:FindFirstChild("Number", true)

	local rewards = content:WaitForChild("Rewards")
	self.Now = rewards:FindFirstChild("InfoNow", true)
	self.Next = rewards:FindFirstChild("InfoNext", true)

	-- The authored Rewards frame has two children named Title; identify the warning by its text.
	for _, label in ipairs(rewards:GetDescendants()) do
		if label:IsA("TextLabel") and string.find(string.lower(label.Text), "reset", 1, true) then
			self.Warning = label
			break
		end
	end

	self.Title = content:FindFirstChild("Title")
	self.Rebirth = content:WaitForChild("Rebirth")
	self.Skip = content:WaitForChild("Skip Rebirth")

	-- Preserve the authored placement while centering button animation pivots.
	for _, button in ipairs({ self.Rebirth, self.Skip }) do
		local anchorDelta = Vector2.new(0.5, 0.5) - button.AnchorPoint
		local position, size = button.Position, button.Size

		button.Position = UDim2.new(
			position.X.Scale + size.X.Scale * anchorDelta.X,
			position.X.Offset + size.X.Offset * anchorDelta.X,
			position.Y.Scale + size.Y.Scale * anchorDelta.Y,
			position.Y.Offset + size.Y.Offset * anchorDelta.Y
		)
		button.AnchorPoint = Vector2.new(0.5, 0.5)
	end

	self:link(self.Rebirth, "Rebirth")
	self:link(self.Skip, "SkipRebirth")
	local header = self.Frame:FindFirstChild("Header") or self.Frame.Body:FindFirstChild("Header")
	local close = header
		and (
			header:FindFirstChild("Close", true)
			or header:FindFirstChild("Shop")
			or header:FindFirstChildWhichIsA("GuiButton", true)
		)
	if close then
		self.Buttons:Unlink(close)
		close:SetAttribute("Type", "PanelToggler")
		close:SetAttribute("PanelName", "Rebirth")
		CollectionService:AddTag(close, "GuiButton")
		self.Buttons:Link(close)
		table.insert(self.LinkedButtons, close)
	end

	local keys = { Rebirths = true, CashMultiplier = true, RebirthPurchases = true }

	for key in pairs(Config.Requirements) do
		keys[key] = true
	end

	for _, override in pairs(Config.Overrides) do
		for key in pairs(override.Requirements or {}) do
			keys[key] = true
		end
	end

	for key in pairs(keys) do
		self.Data[key] = dataController:GetValue(key)
		table.insert(
			self.Connections,
			dataController:GetValueChangedSignal(key):Connect(function(value)
				self.Data[key] = value
				if self.Ready then
					self:update()
				end
			end)
		)
	end

	table.insert(
		self.Connections,
		self.Controller.Changed:Connect(function()
			if self.Ready then
				self:update()
			end
		end)
	)
	table.insert(
		self.Connections,
		self.Frame:GetPropertyChangedSignal("Visible"):Connect(function()
			if self.Frame.Visible then
				self.Controller:Refresh()
			end
		end)
	)
	self.Ready = true
	self:update()
	self.Frame.Destroying:Once(function()
		self.Ready = false
		for _, connection in ipairs(self.Connections) do
			connection:Disconnect()
		end

		for _, button in ipairs(self.LinkedButtons) do
			self.Buttons:Unlink(button)
		end
	end)
end

return RebirthPanel
