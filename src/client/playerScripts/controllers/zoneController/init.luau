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
	Signals = {
		ZoneChanged = Signal.new(),
	},
})

-- Public Methods
-- LifeCycle
function ZoneController:KnitInit()
	self.ZoneService = knit.GetService("ZoneService")
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
			self.Zone = zone
			self.Signals.ZoneChanged:Fire(zone)
		end
	end)
end

return ZoneController
