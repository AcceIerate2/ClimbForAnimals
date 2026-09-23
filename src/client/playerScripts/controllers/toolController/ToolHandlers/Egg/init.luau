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
	-- The tool is labelled with the egg name, so its identity is the attribute.
	self.ReferenceName = tool:GetAttribute("ReferenceName") or tool.Name
	-- The label carries the weight now, so the asset name is an attribute too.
	self.EggName = tool:GetAttribute("ItemName") or tool.Name

	self.Connections = {}
	self.EggPlacementController = knit.GetController("EggPlacementController")

	self:Bind()
	return self
end

-- The egg in the hand is built by the server (InventoryService), so other players see it too.
function Egg:Bind()
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
end

return Egg
