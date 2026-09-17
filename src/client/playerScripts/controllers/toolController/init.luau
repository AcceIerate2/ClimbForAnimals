-- Roblox Services
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Packages
local knit = require(ReplicatedStorage.src.Packages.knit)

-- Constants
local Player = Players.LocalPlayer

-->
local ToolController = knit.CreateController({
	Name = "ToolController",
	ActiveTools = {},
	ContainerConnections = {},
})

-- Private Methods
function ToolController:isConnected(tool: Tool)
	return self.ActiveTools[tool] ~= nil
end

function ToolController:connectTool(newTool: Tool)
	if not newTool:IsA("Tool") or self:isConnected(newTool) then
		return
	end

	local handler = newTool:GetAttribute("Handler")
	if typeof(handler) ~= "string" then
		warn("Couldn't fetch Handler attribute")
		return
	end

	local moduleScriptToRequire = script.ToolHandlers:FindFirstChild(handler)
	local requiredModuleScript = require(moduleScriptToRequire)
	self.ActiveTools[newTool] = requiredModuleScript.new(newTool)
	newTool.Destroying:Once(function()
		self:disconnectTool(newTool)
	end)
end

function ToolController:disconnectTool(removedTool: Tool)
	local handler = self.ActiveTools[removedTool]
	if not handler then
		return
	end

	handler:Disconnect()
	self.ActiveTools[removedTool] = nil
end

function ToolController:listenToContainer(parent)
	for _, tool in parent:GetChildren() do
		self:connectTool(tool)
	end
	table.insert(
		self.ContainerConnections,
		parent.ChildAdded:Connect(function(newTool: Tool)
			self:connectTool(newTool)
		end)
	)
end

-- LifeCycle
function ToolController:KnitInit()
	self.InventoryService = knit.GetService("InventoryService")
	self.CharacterController = knit.GetController("CharacterController")
end

function ToolController:KnitStart()
	for _, tool in Player.Backpack:GetChildren() do
		if tool:IsA("Tool") then
			self:connectTool(tool)
		end
	end

	if Player.Character then
		self:listenToContainer(Player.Backpack)
	end

	self.CharacterController.CharacterAdded:Connect(function()
		self:listenToContainer(Player.Backpack)
	end)

	self.CharacterController.CharacterRemoved:Connect(function()
		for _, connection: RBXScriptConnection in pairs(self.ContainerConnections) do
			connection:Disconnect()
		end
		table.clear(self.ContainerConnections)
	end)

	self.InventoryService.DisconnectTool:Connect(function(removedTool: Tool)
		self:disconnectTool(removedTool)
	end)
end

return ToolController
