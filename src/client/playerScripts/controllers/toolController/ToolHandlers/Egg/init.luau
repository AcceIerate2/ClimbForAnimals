-- Roblox Services
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Packages
local knit = require(ReplicatedStorage.src.Packages.knit)

-->
local Egg = {}
Egg.__index = Egg

function Egg.new(tool: Tool)
	local self = setmetatable({}, Egg)

	self.Tool = tool
	self.EggName = tool.Name:split("_")[1]

	self.Connections = {}
	self.EggPlacementController = knit.GetController("EggPlacementController")

	self:Bind()
	return self
end

function Egg:Bind()
	table.insert(self.Connections, self.Tool.Equipped:Connect(function() end))

	table.insert(self.Connections, self.Tool.Unequipped:Connect(function() end))

	table.insert(
		self.Connections,
		self.Tool.Activated:Connect(function()
			self.EggPlacementController:Place(self.Tool.Name)
		end)
	)
end

function Egg:Disconnect()
	print("Disconnected.")
	for _, connection in pairs(self.Connections) do
		if typeof(connection) == "RBXScriptConnection" then
			connection:Disconnect()
		end
	end
	table.clear(self.Connections)
end

return Egg
