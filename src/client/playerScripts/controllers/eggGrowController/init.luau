-- Roblox Services
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

-- Packages
local knit = require(ReplicatedStorage.src.Packages.knit)

-- Utility Modules
local FormatTime = require(ReplicatedStorage.src.utility.FormatTime)
local eggConfig = require(ReplicatedStorage.src.GameConfiguration.Gameplay.eggConfig)
local InstanceCreator = require(ReplicatedStorage.src.utility.InstanceCreator)
local Spring = require(ReplicatedStorage.src.utility.Spring)
local RarityStyle = require(ReplicatedStorage.src.utility.rarityStyle)
local EggHandler = require(ReplicatedStorage.src.utility.eggHandler)

-- Constants
local AssetsFolder = ReplicatedStorage:WaitForChild("Assets")
local GuiFolder = AssetsFolder:WaitForChild("Gui")
local EggStatsAttachment = GuiFolder:WaitForChild("EggStats")
local DefaultVariant = "Normal" -- the Variant row stays hidden for it

-- Helper Functions
local function getEggStatsAttachment()
	return EggStatsAttachment:Clone()
end

local function setupGui(eggAsset: any)
	local attachment = getEggStatsAttachment()
	attachment.Parent = eggAsset
	attachment.Position = Vector3.new(0, eggAsset:GetExtentsSize().Y + 1, 0)

	local guiObjectValue = Instance.new("ObjectValue")
	guiObjectValue.Name = "AdorneeGui"
	guiObjectValue.Parent = attachment

	local gui = attachment:WaitForChild("Gui")
	guiObjectValue.Value = gui

	local eggName = eggAsset.Name:split("_")[1]
	gui:WaitForChild("EggName").Text = eggName

	-- Rarity and Variant were placeholder text in the asset until now.
	local eggData = eggConfig.Eggs[eggName]
	local rarityLabel = gui:WaitForChild("Rarity")
	rarityLabel.Visible = eggData ~= nil
	if eggData then
		rarityLabel.Text = eggData.Rarity
		RarityStyle.ApplyRarity(rarityLabel, eggData.Rarity)
	end

	local variant = eggAsset:GetAttribute("Variant")
	local variantLabel = gui:WaitForChild("Variant")
	variantLabel.Visible = variant ~= nil and variant ~= DefaultVariant
	if variantLabel.Visible then
		variantLabel.Text = variant
		RarityStyle.ApplyVariant(variantLabel, variant)
	end

	gui:WaitForChild("Timer").Visible = true
	gui.Enabled = true
	gui.Adornee = attachment
	gui.Parent = Players.LocalPlayer.PlayerGui
end

local function updateCountdown(eggAsset: any, secondsLeft: number)
	local attachment = eggAsset:WaitForChild("EggStats")
	local gui = attachment:WaitForChild("AdorneeGui").Value
	local countdownLabel = gui:WaitForChild("Timer"):WaitForChild("Label")

	local lessThanAnHour = secondsLeft <= 600
	local lessThanAMinute = secondsLeft <= 60
	local formattedSeconds =
		`{secondsLeft <= 0 and "Ready! Hatch IT!" or lessThanAMinute and secondsLeft .. "s" or FormatTime(
			secondsLeft,
			lessThanAnHour
		)}`

	countdownLabel.Text = formattedSeconds
end

local function newPrompt(parent)
	local meshPart = parent:FindFirstChildOfClass("MeshPart")
	local attachment = InstanceCreator("Attachment", "Attachment", meshPart, {
		CFrame = CFrame.new(0, -(meshPart.Size.Y / 3), 0),
	})

	return InstanceCreator("ProximityPrompt", "ProximityPrompt", attachment, {
		HoldDuration = 0,
		ObjectText = `{parent.Name:split("_")[1]} Egg`,
		ActionText = "Hatch Egg",
		RequiresLineOfSight = false,
	})
end

local function setupEggAsset(eggAsset: any)
	local meshPart = eggAsset:FindFirstChildOfClass("MeshPart")
	meshPart.PivotOffset = CFrame.new(0, -(meshPart.Size.Y / 2), 0)
	eggAsset.PrimaryPart = meshPart
end

-->
local EggGrowController = knit.CreateController({
	Name = "EggGrowController",
	Connections = {},
})

-- Private Methods
function EggGrowController:connectPrompt(referenceName: string, eggAsset: Model)
	local prompt = newPrompt(eggAsset)
	prompt.Triggered:Connect(function()
		self.EggHatchController:Hatch(referenceName)
	end)

	return prompt
end

function EggGrowController:disconnectEgg(referenceName: string)
	local record = self.Connections[referenceName]
	if not record then
		return
	end

	self.Connections[referenceName] = nil
	record.Connection:Disconnect()
	record.Destroying:Disconnect()
	Spring.stop(record.Asset)
	if record.Prompt then
		record.Prompt:Destroy()
	end

	if record.Gui then
		record.Gui:Destroy()
	end

	if record.Attachment then
		record.Attachment:Destroy()
	end
end

function EggGrowController:connectEgg(referenceName: string, data)
	if self.Connections[referenceName] then
		self.Connections[referenceName].Data = data
		return
	end

	local eggAsset = self.Base.PlacedEggs:FindFirstChild(referenceName)
	local config = eggConfig.Eggs[referenceName:split("_")[1]]
	if not eggAsset or not config or not eggAsset:FindFirstChildOfClass("MeshPart") then
		return
	end

	setupEggAsset(eggAsset)
	setupGui(eggAsset)
	local attachment = eggAsset:FindFirstChild("EggStats")
	local record = {
		Asset = eggAsset,
		Data = data,
		Attachment = attachment,
		Gui = attachment.AdorneeGui.Value,
		BaseScale = eggAsset:GetAttribute("BaseScale") or eggAsset:GetScale(),
		-- The size the egg rolled stretches its hatch time, so the countdown and the growth have
		-- to read the same duration the server hatches on.
		HatchDuration = EggHandler.GetHatchDuration(referenceName:split("_")[1], data.AssetScale),
		Prompt = nil,
	}
	self.Connections[referenceName] = record

	local elapsed = 1
	record.Connection = RunService.Heartbeat:Connect(function(deltaTime)
		if not attachment.Parent then
			self:disconnectEgg(referenceName)
			return
		end

		attachment.Position = Vector3.new(0, eggAsset:GetExtentsSize().Y + 1, 0)
		elapsed += deltaTime
		if elapsed < 1 then
			return
		end
		elapsed = 0

		local duration = record.Data.HatchDuration or record.HatchDuration
		local hatchDate = record.Data.HatchDate or (record.Data.PlaceDate + duration)
		local remaining = record.Data.CanHatch and 0 or math.max(0, hatchDate - workspace:GetServerTimeNow())
		updateCountdown(eggAsset, math.ceil(remaining))
		local progress = duration > 0 and math.clamp(1 - remaining / duration, 0, 1) or 1
		Spring.target(
			eggAsset,
			3,
			3,
			{ Scale = record.BaseScale * (1 + progress * (eggConfig.PlacedGrowthMultiplier - 1)) }
		)

		if record.Data.CanHatch and not record.Prompt then
			record.Prompt = self:connectPrompt(referenceName, eggAsset)
			record.Connection:Disconnect()
			Spring.completed(eggAsset, function()
				if attachment.Parent then
					attachment.Position = Vector3.new(0, eggAsset:GetExtentsSize().Y + 1, 0)
				end
			end)
		end
	end)

	record.Destroying = eggAsset.Destroying:Connect(function()
		self:disconnectEgg(referenceName)
	end)
end

function EggGrowController:updateEggs(data)
	self.EggData = data
	for referenceName in pairs(self.Connections) do
		if not data[referenceName] then
			self:disconnectEgg(referenceName)
		end
	end

	for referenceName, egg in pairs(data) do
		self:connectEgg(referenceName, egg)
	end
end

-- LifeCycle
function EggGrowController:KnitInit()
	self.DataController = knit.GetController("DataController")
	self.BaseController = knit.GetController("BaseController")
	self.EggHatchController = knit.GetController("EggHatchController")
end

function EggGrowController:KnitStart()
	self.Base = self.BaseController:GetBase()
	local folder = self.Base:WaitForChild("PlacedEggs")
	self.DataController:GetValue("PlacedEggs")
	self.DataConnection = self.DataController:GetValueChangedSignal("PlacedEggs"):Connect(function(data)
		self:updateEggs(data)
	end)
	self.AddedConnection = folder.DescendantAdded:Connect(function(egg)
		if not egg:IsA("Model") and not egg:IsA("MeshPart") then
			return
		end

		-- A model may replicate before its mesh; retry when its children arrive too.
		while egg.Parent and egg.Parent ~= folder do
			egg = egg.Parent
		end

		local data = self.EggData and self.EggData[egg.Name]
		if data then
			self:connectEgg(egg.Name, data)
		end
	end)
	self:updateEggs(self.DataController:GetValue("PlacedEggs"))
end

return EggGrowController
