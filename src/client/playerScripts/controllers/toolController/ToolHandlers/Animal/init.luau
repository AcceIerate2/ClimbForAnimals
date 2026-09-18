-- Roblox Services
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Packages
local knit = require(ReplicatedStorage.src.Packages.knit)

-- Modules
local HeldModel = require(script.Parent.Parent.heldModel)

-->
local Animal = {}
Animal.__index = Animal

function Animal.new(tool: Tool)
	local self = setmetatable({}, Animal)

	self.Tool = tool
	-- The tool is labelled with the animal name, so its identity is the attribute.
	self.ReferenceName = tool:GetAttribute("ReferenceName") or tool.Name
	-- The label carries the weight now, so the asset name is an attribute too.
	self.AnimalName = tool:GetAttribute("ItemName") or tool.Name

	self.Connections = {}
	self.AnimalController = knit.GetController("AnimalController")

	self:Bind()

	return self
end

-- Same lifetime as the egg's: the rig is only cloned while the tool is held.
function Animal:Render()
	self:Clear()
	self.Model = HeldModel.BuildAnimal(self.Tool)
end

function Animal:Clear()
	if self.Model then
		self.Model:Destroy()
		self.Model = nil
	end
end

function Animal:Bind()
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
			self.AnimalController:PlaceAnimal(self.ReferenceName)
		end)
	)
end

function Animal:Disconnect()
	for _, connection in pairs(self.Connections) do
		if typeof(connection) == "RBXScriptConnection" then
			connection:Disconnect()
		end
	end

	table.clear(self.Connections)

	self:Clear()
end

return Animal
