-- Roblox Services
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Packages
local knit = require(ReplicatedStorage.src.Packages.knit)

-- Modules
local HeldModel = require(script.Parent.Parent.heldModel)

-->
local Egg = {}
Egg.__index = Egg

function Egg.new(tool: Tool)
	local self = setmetatable({}, Egg)

	self.Tool = tool
	-- The tool is labelled with the egg name, so its identity is the attribute.
	self.ReferenceName = tool:GetAttribute("ReferenceName") or tool.Name
	-- The label carries the weight now, so the asset name is an attribute too.
	self.EggName = tool:GetAttribute("ItemName") or tool.Name

	self.Connections = {}
	self.EggPlacementController = knit.GetController("EggPlacementController")

	self:Bind()
	return self
end

-- The visible egg only exists while held, so it is built on equip and dropped on unequip.
function Egg:Render()
	self:Clear()
	self.Model = HeldModel.BuildEgg(self.Tool)
end

function Egg:Clear()
	if self.Model then
		self.Model:Destroy()
		self.Model = nil
	end
end

function Egg:Bind()
	table.insert(
		self.Connections,
		self.Tool.Equipped:Connect(function()
			self:Render()
		end)
	)

	table.insert(
		self.Connections,
		self.Tool.Unequipped:Connect(function()
			self:Clear()
		end)
	)

	table.insert(
		self.Connections,
		self.Tool.Activated:Connect(function()
			self.EggPlacementController:Place(self.ReferenceName)
		end)
	)
end

function Egg:Disconnect()
	for _, connection in pairs(self.Connections) do
		if typeof(connection) == "RBXScriptConnection" then
			connection:Disconnect()
		end
	end
	table.clear(self.Connections)

	self:Clear()
end

return Egg
