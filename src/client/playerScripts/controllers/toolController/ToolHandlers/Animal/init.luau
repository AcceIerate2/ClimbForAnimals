-- Roblox Services
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Packages
local knit = require(ReplicatedStorage.src.Packages.knit)

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

-- The animal in the hand is built by the server (InventoryService), so other players see it too.
function Animal:Bind()
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
end

return Animal
