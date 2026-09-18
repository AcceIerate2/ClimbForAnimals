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
-- Satchel labels a slot with tool.Name, so the tool is named for display only: the asset name
-- lives in ItemName and the identity in ReferenceName, never an id in the label.
-- "Bunny (12Kg)": the same weight the billboard shows, so the numbers always agree.
local function buildLabel(displayName: string, assetScale: number?): string
	return string.format("%s (%s)", displayName, EggHandler.GetWeightKgDisplay(displayName, assetScale))
end

local function createTool(displayName: string, backPack: Backpack, customProps: { [string]: any }): Tool
	return InstanceCreator("Tool", displayName, backPack, customProps) :: Tool
end

local function findByReference(container: Instance?, referenceName: string): Tool?
	if not container then
		return nil
	end

	for _, child in ipairs(container:GetChildren()) do
		if child:IsA("Tool") and child:GetAttribute("ReferenceName") == referenceName then
			return child
		end
	end

	return nil
end

local function fetchTool(player: Player, referenceName: string)
	return findByReference(player:FindFirstChildOfClass("Backpack"), referenceName)
		or findByReference(player.Character, referenceName)
end

-- The visible model is built on the client when the tool is equipped (see
-- toolController.heldModel); the server only supplies an invisible Handle for Roblox's grip
-- system plus the attributes the client needs to render it.
local function createHandle(tool: Tool): BasePart
	return InstanceCreator("Part", "Handle", tool, {
		Size = Vector3.new(0.2, 0.2, 0.2),
		Transparency = 1,
		CanCollide = false,
		CanQuery = false,
		CanTouch = false,
		Anchored = false,
		Massless = true,
	}) :: BasePart
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
	local displayName = item and item.Name or referenceName:split("_")[1]
	local customData = item and item.CustomData
	-- An egg keeps its variant on the item, an animal keeps it in CustomData.
	local variant = (item and item.Variant) or (customData and customData.Variant)
	local assetScale = customData and customData.AssetScale
	-- Like the reference, the slot shows how heavy this particular one is, so two Bunnies of
	-- different sizes are told apart. The asset name moves to an attribute because the label
	-- is no longer a plain name.
	local tool = createTool(buildLabel(displayName, assetScale), player.Backpack, {
		RequiresHandle = true,
		CanBeDropped = false,
		Attributes = {
			Handler = itemHandler,
			ReferenceName = referenceName,
			ItemName = displayName,
			-- Satchel paints the slot from these two.
			Rarity = EggHandler.GetRarity(displayName),
			Variant = variant,
			AssetScale = assetScale,
		},
	})

	createHandle(tool)

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
	self.PlayerService = knit.GetService("PlayerService")
end

function InventoryService:KnitStart()
	self.PlayerService.CharacterReset:Connect(function(player)
		task.defer(function()
			local backpack = player:WaitForChild("Backpack", 10)
			if backpack and player.Parent and self.DataService:GetProfile(player) then
				self:ConnectTools(player)
			end
		end)
	end)
end

return InventoryService
