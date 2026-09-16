-- Roblox Services
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

-- Packages
local knit = require(ReplicatedStorage.src.Packages.knit)

-- Config Modules
local zoneConfig = require(ReplicatedStorage.src.GameConfiguration.Gameplay.zoneConfig)
local Signal = require(ReplicatedStorage.src.Packages.Signal)

-- Constants
local Player = Players.LocalPlayer
local HeightBarAssets = ReplicatedStorage:WaitForChild("Assets"):WaitForChild("HeightBar")
local ClimbStart = HeightBarAssets:WaitForChild("StartCFrame") :: BasePart
local ClimbZoneExtents = Vector3.new(3, 0, 30) -- half size (X/Z) of the truss column, measured from StartCFrame
local ZoneNotificationCooldown = 5

-- Helper Functions
local function getZoneFromHeight(charHeight: number): string
	local currentZone = nil
	local currentHeight = -math.huge

	for zoneName: string, config: { Height: number } in pairs(zoneConfig) do
		if charHeight >= config.Height and config.Height > currentHeight then
			currentZone = zoneName
			currentHeight = config.Height
		end
	end

	return currentZone
end

-->
local ZoneController = knit.CreateController({
	Name = "ZoneController",
	Zone = nil,
	NotificationCooldowns = {}, -- [zoneName]: os.clock()
	ZoneNotificationId = nil,
	Signals = {
		ZoneChanged = Signal.new(),
	},
})

-- Private Methods
function ZoneController:pushZoneNotification(zone: string?, previousZone: string?)
	local config = zone and zoneConfig[zone]
	local previousConfig = previousZone and zoneConfig[previousZone]
	if not config or not previousConfig or zone == "Lobby" then
		return
	end

	-- Only when going up, never while falling
	if config.Height <= previousConfig.Height then
		return
	end

	local lastNotification = self.NotificationCooldowns[zone]
	if lastNotification and os.clock() - lastNotification < ZoneNotificationCooldown then
		return
	end
	self.NotificationCooldowns[zone] = os.clock()

	-- Replace the previous biome notification (other notifications are untouched)
	self.NotificationController:Hide(self.ZoneNotificationId)
	self.ZoneNotificationId = self.NotificationController:Push({
		Message = `{config.Emoji or ""} Welcome to {zone}!`,
		Color = config.Color,
		Sound = "Generic",
	})
end

-- Public Methods
function ZoneController:GetClimbStartHeight(): number
	return ClimbStart.Position.Y
end

function ZoneController:IsInClimbZone(position: Vector3): boolean
	local zone = getZoneFromHeight(position.Y)
	if zone and zone ~= "Lobby" then
		return true
	end

	local offset = position - ClimbStart.Position
	return offset.Y >= 0 and math.abs(offset.X) <= ClimbZoneExtents.X and math.abs(offset.Z) <= ClimbZoneExtents.Z
end

-- LifeCycle
function ZoneController:KnitInit()
	self.ZoneService = knit.GetService("ZoneService")
	self.NotificationController = knit.GetController("NotificationController")
end

function ZoneController:KnitStart()
	RunService.RenderStepped:Connect(function()
		local character = Player.Character
		if not character then
			return
		end

		local yPosition = character:GetPivot().Y
		local zone = getZoneFromHeight(yPosition)

		if zone ~= self.Zone then
			local previousZone = self.Zone
			self.Zone = zone
			self.Signals.ZoneChanged:Fire(zone)
			self:pushZoneNotification(zone, previousZone)
		end
	end)
end

return ZoneController
