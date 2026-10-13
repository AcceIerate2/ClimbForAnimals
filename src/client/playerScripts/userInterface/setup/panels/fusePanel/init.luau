-- Roblox Services
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

-- Packages
local knit = require(ReplicatedStorage.src.Packages.knit)

-- Utility Modules
local ScrollingCanvas = require(ReplicatedStorage.src.utility.scrollingCanvas)

-- Config Modules
local Config = require(ReplicatedStorage.src.GameConfiguration.Gameplay.fuseConfig)

-- Modules
local Row = require(script.row)

-->
local FusePanel = { Rows = {}, Slots = {}, Connections = {}, LinkedButtons = {}, Data = {} }

-- Private Methods
function FusePanel:link(button, action: string?)
	self.Buttons:Unlink(button)
	if action then
		button:SetAttribute("Type", "Action")
		button:SetAttribute("Action", action)
	end
	CollectionService:AddTag(button, "GuiButton")
	self.Buttons:Link(button)
	self.LinkedButtons[button] = true
end

function FusePanel:removeRow(reference: string)
	local row = self.Rows[reference]
	self.Buttons:Unlink(row.Frame)
	self.LinkedButtons[row.Frame] = nil
	Row.Clear(row)
	row.Frame:Destroy()
	self.Rows[reference] = nil
end

function FusePanel:updateTimer()
	local state = self.Data.Fuse or { Slots = {} }
	local seconds = state.FinishAt and math.max(0, state.FinishAt - workspace:GetServerTimeNow())
	if not seconds then
		local variant = "Normal"
		for _, reference in pairs(state.Slots) do
			local item = (self.Data.Inventory or {})[reference]
			if item then
				variant = Config.GetVariant(item)
				break
			end
		end
		seconds = state.Remaining or Config.GetDuration(variant)
	end
	seconds = math.ceil(seconds)
	self.Timer.RichText = true
	self.Timer.Text = string.format('Fuse Time <font color="#00FF00">(%d:%02d)</font>', math.floor(seconds / 60), seconds % 60)
end

function FusePanel:update()
	if not self.Ready or not self.Frame.Visible then
		return
	end
	local state = self.Data.Fuse or { Slots = {} }
	local inventory = self.Data.Inventory or {}
	self.Content.Visible = self.Controller.SelectingSlot == nil
	self.Selection.Visible = not self.Content.Visible
	for index, row in ipairs(self.Slots) do
		Row.Update(row, inventory[state.Slots[tostring(index)]])
		row.Frame.Interactable = not self.Controller.Pending
	end

	local result = Config.GetResult(state, inventory)
	self.Preview.Frame.Visible = result ~= nil
	Row.Update(self.Preview, result)
	self:updateTimer()
	if not self.Selection.Visible then
		return
	end

	local eligible = {}
	for reference, item in pairs(inventory) do
		if not Config.IsSelected(state, reference) and Config.CanSelect(item, state, inventory) then
			table.insert(eligible, reference)
		end
	end
	table.sort(eligible, function(a, b)
		if inventory[a].Name ~= inventory[b].Name then
			return inventory[a].Name < inventory[b].Name
		end
		return a < b
	end)
	local present = {}
	for order, reference in ipairs(eligible) do
		present[reference] = true
		local row = self.Rows[reference]
		if not row then
			local frame = self.Template:Clone()
			frame.Name = reference
			frame:SetAttribute("ReferenceName", reference)
			frame.Visible = true
			frame.Parent = self.Template.Parent
			row = { Frame = frame }
			self.Rows[reference] = row
			self:link(frame, "Fuse")
		end
		row.Frame.LayoutOrder = order
		row.Frame.Interactable = not self.Controller.Pending
		Row.Update(row, inventory[reference])
	end
	for reference in pairs(self.Rows) do
		if not present[reference] then
			self:removeRow(reference)
		end
	end
	local title = self.Selection:FindFirstChild("Title")
	if title and title:IsA("TextLabel") then
		title.Text = #eligible == 0 and "No matching animals available" or "Select an animal"
	end
end

function FusePanel:queueUpdate()
	if self.UpdateQueued then
		return
	end
	self.UpdateQueued = true
	task.defer(function()
		self.UpdateQueued = false
		self:update()
	end)
end

-- LifeCycle
function FusePanel:Init(player: Player)
	self.Controller = knit.GetController("FuseController")
	self.Buttons = knit.GetController("ButtonsController")
	local data = knit.GetController("DataController")
	self.Frame = player.PlayerGui:WaitForChild("Panels"):WaitForChild("Fuse")
	local body = self.Frame:WaitForChild("Body")
	self.Content = body:WaitForChild("Content")
	self.Selection = body:WaitForChild("Selection")
	local returnButton = self.Selection:WaitForChild("ReturnBtn")
	returnButton:SetAttribute("FuseReturn", true)
	self:link(returnButton, "Fuse")

	self.Timer = self.Content:WaitForChild("Timer")
	local animals = self.Content:WaitForChild("Animals")
	for index = 1, Config.SlotCount do
		local frame = animals:WaitForChild(`Slot{index}`)
		frame:SetAttribute("FuseSlot", index)
		self.Slots[index] = { Frame = frame }
		self:link(frame, "Fuse")
	end
	local scrolling = self.Selection:WaitForChild("ScrollingFrame")
	self.Template = scrolling:WaitForChild("Template")
	self.Template.Visible = false
	self.Template.Size = UDim2.fromScale(0.5, 0.5)
	self.Template.SizeConstraint = Enum.SizeConstraint.RelativeYY
	local layout = scrolling:FindFirstChildOfClass("UIListLayout")
	if layout then
		layout.SortOrder = Enum.SortOrder.LayoutOrder
		layout.HorizontalFlex = Enum.UIFlexAlignment.None
		layout.VerticalFlex = Enum.UIFlexAlignment.None
	end
	for _, connection in ipairs(ScrollingCanvas.Connect(scrolling)) do
		table.insert(self.Connections, connection)
	end
	local preview = self.Content:WaitForChild("PossibleFusions"):WaitForChild("Template")
	preview.Visible = false
	preview.Interactable = false
	CollectionService:RemoveTag(preview, "GuiButton")
	self.Preview = { Frame = preview }
	local close = self.Frame:WaitForChild("Header"):WaitForChild("FusePanelToggler")
	close:SetAttribute("Type", "PanelToggler")
	close:SetAttribute("PanelName", "Fuse")
	self:link(close)

	for _, key in { "Inventory", "Fuse" } do
		self.Data[key] = data:GetValue(key)
		table.insert(
			self.Connections,
			data:GetValueChangedSignal(key):Connect(function(value)
				self.Data[key] = value
				self:queueUpdate()
			end)
		)
	end
	table.insert(
		self.Connections,
		self.Controller.Changed:Connect(function()
			self:queueUpdate()
		end)
	)
	table.insert(
		self.Connections,
		self.Frame:GetPropertyChangedSignal("Visible"):Connect(function()
			self.Controller:CancelSelection()
			self:queueUpdate()
		end)
	)
	local elapsed = 0
	table.insert(
		self.Connections,
		RunService.Heartbeat:Connect(function(deltaTime)
			elapsed += deltaTime
			if elapsed >= 0.25 then
				elapsed = 0
				if self.Ready and self.Frame.Visible then
					self:updateTimer()
				end
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
		for _, row in ipairs(self.Slots) do
			Row.Clear(row)
		end
		Row.Clear(self.Preview)
		for reference in pairs(self.Rows) do
			self:removeRow(reference)
		end
		for button in pairs(self.LinkedButtons) do
			self.Buttons:Unlink(button)
		end
		table.clear(self.Connections)
		table.clear(self.LinkedButtons)
	end)
end

return FusePanel
