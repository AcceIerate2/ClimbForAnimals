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
	self.AnimalName = tool.Name:split("_")[1]

	self.Connections = {}
	self.AnimalController = knit.GetController("AnimalController")

	self:Bind()
	return self
end

function Animal:Bind()
	table.insert(self.Connections, self.Tool.Equipped:Connect(function() end))

	table.insert(self.Connections, self.Tool.Unequipped:Connect(function() end))

	table.insert(
		self.Connections,
		self.Tool.Activated:Connect(function()
			self.AnimalController:Place(self.Tool.Name)
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
