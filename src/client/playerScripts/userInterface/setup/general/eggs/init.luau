-- Roblox Services
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

-- Packages
local knit = require(ReplicatedStorage.src.Packages.knit)

-- Utility Modules
local Spring = require(ReplicatedStorage.src.utility.Spring)
local ScrollingCanvas = require(ReplicatedStorage.src.utility.scrollingCanvas)

-- Modules
local Row = require(script.row)

local Eggs = { Rows = {}, Connections = {}, Visible = false, VisibilityRevision = 0 }

-- Private Methods
function Eggs:toggleVisibility(visible: boolean)
	self.Visible = visible
	self.VisibilityRevision += 1
	local revision = self.VisibilityRevision

	if visible then
		self.Frame.Visible = true
		self:updateTimers()
	end

	Spring.target(self.Frame, 0.75, 6, {
		Position = visible and self.VisiblePosition or self.HiddenPosition,
	})

	Spring.completed(self.Frame, function()
		if self.VisibilityRevision == revision and not self.Visible then
			self.Frame.Visible = false
		end
	end)
end

function Eggs:updateTimers()
	local now = workspace:GetServerTimeNow()
	local growing = false
	for _, row in pairs(self.Rows) do
		Row.Update(row, now)
		growing = growing or not row.Data.CanHatch
	end

	self.GrowAll.Active = growing
	self.GrowAll.AutoButtonColor = growing
end

function Eggs:updateEggs(data)
	local growing, total = 0, 0
	for _, egg in pairs(data) do
		total += 1
		if not egg.CanHatch then
			growing += 1
		end
	end

	self.Header.Text = `GROWING EGGS ({growing}/{total})`

	for referenceName, row in pairs(self.Rows) do
		if not data[referenceName] then
			Row.Destroy(row, self.ButtonsController)
			self.Rows[referenceName] = nil
		end
	end

	local ordered = {}
	for referenceName, egg in pairs(data) do
		local row = self.Rows[referenceName]
		if not row then
			row = Row.Create(self.Template, referenceName, egg, self.ButtonsController)
			self.Rows[referenceName] = row
		end

		if row then
			row.Data = egg
			table.insert(ordered, referenceName)
		end
	end

	table.sort(ordered, function(a, b)
		if data[a].PlaceDate == data[b].PlaceDate then
			return a < b
		end
		return data[a].PlaceDate < data[b].PlaceDate
	end)

	for index, referenceName in ipairs(ordered) do
		self.Rows[referenceName].Frame.LayoutOrder = index
	end

	self:updateTimers()
end

function Eggs:linkButton(button: GuiButton, action: string)
	self.ButtonsController:Unlink(button)
	button:SetAttribute("Type", "Action")
	button:SetAttribute("Action", action)
	CollectionService:AddTag(button, "GuiButton")
	self.ButtonsController:Link(button)
end

-- LifeCycle
function Eggs:Init(player: Player)
	self.EggController = knit.GetController("EggController")
	self.ButtonsController = knit.GetController("ButtonsController")
	local dataController = knit.GetController("DataController")

	self.Frame = player.PlayerGui:WaitForChild("General"):WaitForChild("Eggs")
	local body = self.Frame:WaitForChild("Body")
	self.Header = body:WaitForChild("Header"):WaitForChild("header")
	self.Container = body:WaitForChild("Holder"):WaitForChild("ScrollingFrame")
	self.Template = self.Container:WaitForChild("EggTemplate")
	self.Template.Visible = false
	for _, connection in ipairs(ScrollingCanvas.Connect(self.Container)) do
		table.insert(self.Connections, connection)
	end
	self.GrowAll = self.Frame:WaitForChild("Grow All")

	self.VisiblePosition = self.Frame:GetAttribute("VisiblePosition") or self.Frame.Position
	self.HiddenPosition = self.Frame:GetAttribute("HiddenPosition")
		or UDim2.new(1.5, 0, self.VisiblePosition.Y.Scale, self.VisiblePosition.Y.Offset)
	self.Frame.Position = self.HiddenPosition
	self.Frame.Visible = false

	self:linkButton(body:WaitForChild("Close"), "CloseEggs")
	self:linkButton(self.GrowAll, "GrowAllEggs")
	table.insert(
		self.Connections,
		self.EggController.Signals.ToggleVisibility:Connect(function(visible)
			self:toggleVisibility(visible)
		end)
	)

	dataController:GetValue("PlacedEggs")
	table.insert(
		self.Connections,
		dataController:GetValueChangedSignal("PlacedEggs"):Connect(function(data)
			self:updateEggs(data)
		end)
	)
	self:updateEggs(dataController:GetValue("PlacedEggs"))
	self:toggleVisibility(self.EggController.Visible)

	local elapsed = 0
	table.insert(
		self.Connections,
		RunService.Heartbeat:Connect(function(deltaTime)
			elapsed += deltaTime
			if self.Visible and elapsed >= 0.25 then
				elapsed = 0
				self:updateTimers()
			end
		end)
	)

	self.Frame.Destroying:Once(function()
		for _, connection in ipairs(self.Connections) do
			connection:Disconnect()
		end
		table.clear(self.Connections)

		for _, row in pairs(self.Rows) do
			Row.Destroy(row, self.ButtonsController)
		end
		table.clear(self.Rows)
		self.ButtonsController:Unlink(self.GrowAll)
		self.ButtonsController:Unlink(body.Close)
		self.EggController:SetVisible(false)
	end)
end

return Eggs
