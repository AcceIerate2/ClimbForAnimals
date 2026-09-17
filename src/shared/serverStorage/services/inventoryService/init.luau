-- Roblox Services
local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Packages
local knit = require(ReplicatedStorage.src.Packages.knit)

-- Utility Modules
local InstanceCreator = require(ReplicatedStorage.src.utility.InstanceCreator)
local EggHandler = require(ReplicatedStorage.src.utility.eggHandler)

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
	local backpack = player:FindFirstChildOfClass("Backpack")
	return backpack and backpack:FindFirstChild(referenceName)
		or player.Character and player.Character:FindFirstChild(referenceName)
end

local function fetchHandle(name: string, itemHandler: string, variant: string?): BasePart?
	local asset
	if itemHandler == "Egg" then
		asset = EggHandler.GetTemplate(name, variant)
	else
		local assetsFolder = AssetsFolder:FindFirstChild(`{itemHandler}s`)
		asset = assetsFolder and assetsFolder:FindFirstChild(name)
	end

	local meshPart = asset and asset:FindFirstChildWhichIsA("MeshPart", true)
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

-- Public Methods
function InventoryService:StoreInBackpack(player: Player, referenceName: string, itemHandler: string): Tool
	local existing = fetchTool(player, referenceName)
	if existing then
		return existing
	end
	local inventory = self:getValueObject(player):Get()
	local item = inventory[referenceName]
	local tool = createTool(referenceName, player.Backpack, {
		RequiresHandle = false,
		Attributes = {
			Handler = itemHandler,
		},
	})

	local handle = fetchHandle(item and item.Name or referenceName:split("_")[1], itemHandler, item and item.Variant)
	if handle then
		handle.Parent = tool
		tool.Grip = CFrame.new(0, -(handle.Size.Y / 2), 0)
			* CFrame.Angles(0, math.rad(itemHandler == "Egg" and -90 or 0), 0)
	end

	return tool
end

function InventoryService:RemoveTool(player: Player, referenceName: string)
	local toolToDestroy = fetchTool(player, referenceName)
	if toolToDestroy then
		self.Client.DisconnectTool:Fire(player, toolToDestroy)
		toolToDestroy:Destroy()
	end
end

function InventoryService:OwnsItem(player: Player, referenceName: string)
	return typeof(self:getValueObject(player):Get()[referenceName]) == "table"
end

function InventoryService:GiveItem(
	player: Player,
	data: ItemData,
	storeInBackpack: boolean?
): { ReferenceName: string, Tool: Tool? }
	local id = HttpService:GenerateGUID(false)
	local referenceName = `{data.Name}_{id}`

	local valueObject = self:getValueObject(player)
	valueObject:Update(function(mutator)
		mutator[referenceName] = data
	end)

	local tool
	if storeInBackpack ~= false then
		tool = self:StoreInBackpack(player, referenceName, data.Handler)
	end

	return { ReferenceName = referenceName, Tool = tool }
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
	local equippedAnimals = self.DataService:GetValue(player, "EquippedAnimals") or {}
	for referenceName: string, itemData: ItemData in pairs(valueObject:Get()) do
		if itemData.Handler == "Animal" then
			if equippedAnimals[referenceName] or self.EggHatchService:IsRevealing(player, referenceName) then
				continue
			end
		end

		self:StoreInBackpack(player, referenceName, itemData.Handler)
	end
end

-- LifeCycle
function InventoryService:KnitInit()
	self.DataService = knit.GetService("DataService")
	self.EggHatchService = knit.GetService("EggHatchService")
end

function InventoryService:KnitStart()
	knit.GetService("PlayerService").CharacterReset:Connect(function(player)
		task.defer(function()
			local backpack = player:WaitForChild("Backpack", 10)
			if backpack and player.Parent and self.DataService:GetProfile(player) then
				self:ConnectTools(player)
			end
		end)
	end)

	workspace.TempEggEquipper.ProximityPrompt.Triggered:Connect(function(player: Player)
		self:GiveItem(player, {
			Name = "Owl",
			Handler = "Egg",
			Variant = "Default",
		})
	end)
end

return InventoryService
