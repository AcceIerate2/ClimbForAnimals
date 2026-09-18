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
	return InstanceCreator("ProximityPrompt", "ProximityPrompt", parent:FindFirstChildOfClass("MeshPart"), {
		HoldDuration = 0,
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
function EggGrowController:getEggAsset(referenceName: string): any
	return self.Base:WaitForChild("PlacedEggs"):WaitForChild(referenceName, 3)
end

function EggGrowController:connectPrompt(referenceName: string, eggAsset: any)
	local prompt = newPrompt(eggAsset)
	prompt.Triggered:Once(function()
		prompt:Destroy()
		self.EggHatchController:Hatch(referenceName)
	end)
end

function EggGrowController:connectEgg(referenceName: string, secondsLeft: number)
	local eggAsset = self:getEggAsset(referenceName)
	if not eggAsset then
		warn("Couldn't fetch Egg Asset - EggGrowController:connectGui")
	end

	setupEggAsset(eggAsset)
	setupGui(eggAsset)
	updateCountdown(eggAsset, math.clamp(secondsLeft, 0, math.huge))

	local initialSecondsLeft = secondsLeft
	local baseScale = eggAsset:GetAttribute("BaseScale") or eggAsset:GetScale()
	local elapsed = 0
	local scaleElapsed = 0
	local connection

	local function disconnect()
		if typeof(connection) == "RBXScriptConnection" then
			connection:Disconnect()
		end
	end

	local function updateScale()
		local progress = 1
			- (math.clamp(secondsLeft, 0, math.clamp(initialSecondsLeft, 0, math.huge)) / initialSecondsLeft)
		local scale = baseScale * (1 + progress * (eggConfig.PlacedGrowthMultiplier - 1))
		Spring.target(eggAsset, 3, 3, {
			Scale = scale,
		})
	end

	connection = RunService.RenderStepped:Connect(function(deltaTime: number)
		local attachment = eggAsset:WaitForChild("EggStats")
		attachment.Position = Vector3.new(0, eggAsset:GetExtentsSize().Y + 1, 0)

		elapsed += deltaTime
		scaleElapsed += deltaTime

		if scaleElapsed >= 2 then
			scaleElapsed = 0
			updateScale()
		end

		if elapsed < 1 then
			return
		end

		elapsed -= 1
		secondsLeft -= 1

		updateCountdown(eggAsset, math.clamp(secondsLeft, 0, math.huge))

		if secondsLeft <= 0 then
			updateScale()
			disconnect()
			self:connectPrompt(referenceName, eggAsset)
		end
	end)
end

-- LifeCycle
function EggGrowController:KnitInit()
	self.EggGrowService = knit.GetService("EggGrowService")
	self.BaseController = knit.GetController("BaseController")
	self.EggHatchController = knit.GetController("EggHatchController")
end

function EggGrowController:KnitStart()
	self.Base = self.BaseController:GetBase()
	self.EggGrowService.ConnectGui:Connect(function(referenceName: string, secondsLeft: number)
		self:connectEgg(referenceName, secondsLeft)
	end)
end

return EggGrowController
