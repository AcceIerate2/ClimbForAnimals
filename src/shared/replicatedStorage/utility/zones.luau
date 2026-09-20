-- Roblox Services
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Config Modules
local zoneConfig = require(ReplicatedStorage.src.GameConfiguration.Gameplay.zoneConfig)

-- Constants
local HeightBarAssets = ReplicatedStorage:WaitForChild("Assets"):WaitForChild("HeightBar")
local ClimbStart = HeightBarAssets:WaitForChild("StartCFrame") :: BasePart
local ClimbZoneExtents = Vector3.new(3, 0, 30) -- half size (X/Z) of the truss column, measured from StartCFrame

-->
local Zones = {}

-- The lobby ends where the lowest climbing zone begins.
Zones.LobbyMaxHeight = math.huge
for zoneName: string, zone in pairs(zoneConfig) do
	if zoneName ~= "Lobby" then
		Zones.LobbyMaxHeight = math.min(Zones.LobbyMaxHeight, zone.Height)
	end
end

function Zones.GetFromHeight(height: number): string?
	local currentZone = nil
	local currentHeight = -math.huge

	for zoneName: string, zone in pairs(zoneConfig) do
		if height >= zone.Height and zone.Height > currentHeight then
			currentZone = zoneName
			currentHeight = zone.Height
		end
	end

	return currentZone
end

function Zones.IsAboveLobby(position: Vector3): boolean
	return position.Y >= Zones.LobbyMaxHeight
end

function Zones.GetClimbStartHeight(): number
	return ClimbStart.Position.Y
end

-- Leaving the lobby means being on the climb, not being above a height: the first stretch of the
-- truss runs below the Forest ceiling, so the height alone leaves it out.
function Zones.IsInClimbZone(position: Vector3): boolean
	if Zones.IsAboveLobby(position) then
		return true
	end

	local offset = position - ClimbStart.Position
	return offset.Y >= 0 and math.abs(offset.X) <= ClimbZoneExtents.X and math.abs(offset.Z) <= ClimbZoneExtents.Z
end

return Zones
