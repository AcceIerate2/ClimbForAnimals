-- Roblox Services
local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Packages
local knit = require(ReplicatedStorage.src.Packages.knit)

-- Utility Modules
local InstanceCreator = require(ReplicatedStorage.src.utility.InstanceCreator)

-- Constants
local AssetsFolder = ReplicatedStorage.Assets

-- Types
type ItemData = {
	Name: string,
	Handler: string,
	CustomData: { [any]: any },
}

-- Helper Functions
local function createTool(referenceName: string, backPack: Backpack, customProps: { [string]: any }): Tool
	return InstanceCreator("Tool", referenceName, backPack, customProps) :: Tool
end

local function fetchTool(player: Player, referenceName: string)
	return player.Backpack:FindFirstChild(referenceName)
		or player.Character and player.Character:FindFirstChild(referenceName)
end

local function fetchHandle(name: string, itemHandler: string): BasePart?
	itemHandler = `{itemHandler}s`
	warn(itemHandler)
	local assetsFolder = AssetsFolder:FindFirstChild(itemHandler)
	local asset = assetsFolder:FindFirstChild(name)
	local meshPart = asset:FindFirstChildOfClass("MeshPart")
	if not meshPart then
		return
	end

	meshPart = meshPart:Clone()
	meshPart.CanCollide = false
	meshPart.Anchored = false
	meshPart.Massless = true
	meshPart.Name = "Handle"
	return meshPart
end

-->
local InventoryService = knit.CreateService({
	Name = "InventoryService",
	Client = {
		DisconnectTool = knit.CreateSignal(),
	},
})

-- Private Methods
function InventoryService:getValueObject(player: Player)
	return self.DataService:GetValueObject(player, "Inventory")
end

function InventoryService:storeInBackpack(player: Player, referenceName: string, itemHandler: string): Tool
	local tool = createTool(referenceName, player.Backpack, {
		RequiresHandle = false,
		Attributes = {
			Handler = itemHandler,
		},
	})

	local handle = fetchHandle(referenceName:split("_")[1], itemHandler)
	if handle then
		handle.Parent = tool
		tool.Grip = CFrame.new(0, -(handle.Size.Y / 2), 0) * CFrame.Angles(0, math.rad(-90), 0)
	end

	return tool
end

-- Public Methods
function InventoryService:OwnsItem(player: Player, referenceName: string)
	return typeof(self:getValueObject(player):Get()[referenceName]) == "table"
end

function InventoryService:GiveItem(player: Player, data: ItemData): { ReferenceName: string, Tool: Tool }
	local id = HttpService:GenerateGUID(false)
	local referenceName = `{data.Name}_{id}`

	local valueObject = self:getValueObject(player)
	valueObject:Update(function(mutator)
		mutator[referenceName] = data
	end)

	return { ReferenceName = referenceName, Tool = self:storeInBackpack(player, referenceName, data.Handler) }
end

function InventoryService:RemoveItem(player: Player, referenceName: string)
	local valueObject = self:getValueObject(player)
	if not valueObject:Get()[referenceName] then
		return
	end

	valueObject:Update(function(mutator)
		mutator[referenceName] = nil
	end)

	local tool = fetchTool(player, referenceName)
	if tool then
		self.Client.DisconnectTool:Fire(player, tool)
		tool:Destroy()
	end
end

function InventoryService:ConnectTools(player: Player)
	local valueObject = self:getValueObject(player)
	for referenceName: string, itemData: ItemData in pairs(valueObject:Get()) do
		self:storeInBackpack(player, referenceName, itemData.Handler)
	end
end

-- LifeCycle
function InventoryService:KnitInit()
	self.DataService = knit.GetService("DataService")
end

function InventoryService:KnitStart()
	workspace.TempEggEquipper.ProximityPrompt.Triggered:Connect(function(player: Player)
		self:GiveItem(player, {
			Name = "Owl",
			Handler = "Egg",
			Variant = "Default",
		})
	end)
end

return InventoryService
