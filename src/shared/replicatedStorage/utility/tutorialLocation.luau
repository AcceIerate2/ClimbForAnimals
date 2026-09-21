-- Roblox Services
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Utility Modules
local Geometry = require(ReplicatedStorage.src.utility.guardGeometry)

-- Config Modules
local Config = require(ReplicatedStorage.src.GameConfiguration.Gameplay.tutorialConfig)

local Location = {}

function Location.GetBiome(position: Vector3): string?
	local structures = workspace:FindFirstChild("Structures")
	local islands = structures and structures:FindFirstChild("Islands")
	for _, island in ipairs(islands and islands:GetChildren() or {}) do
		local area = island:FindFirstChild("Area")
		if area and area:IsA("BasePart") and Geometry.Contains(area, position, Config.PlatformHeight) then
			return island.Name
		end
	end
	return nil
end

return Location
