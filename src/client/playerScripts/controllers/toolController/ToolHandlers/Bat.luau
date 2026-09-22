-- Roblox Services
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Packages
local knit = require(ReplicatedStorage.src.Packages.knit)

-- Utility Modules
local Zones = require(ReplicatedStorage.src.utility.zones)

-- Constants
local NotificationCooldown = 1
local SafeZoneNotification = {
	Message = "You can't use that in the safe zone!",
	Color = Color3.fromRGB(255, 0, 0),
	Sound = "Decline",
}

-->
local Bat = {}
Bat.__index = Bat

function Bat.new(tool: Tool)
	local self = setmetatable({}, Bat)

	self.Tool = tool
	self.Connections = {}
	self.LastNotification = -math.huge
	self.NotificationController = knit.GetController("NotificationController")

	self:Bind()
	return self
end

-- The server refuses the swing in the lobby; this only tells the player why.
function Bat:Bind()
	table.insert(
		self.Connections,
		self.Tool.Activated:Connect(function()
			local character = Players.LocalPlayer.Character
			local root = character and character:FindFirstChild("HumanoidRootPart")
			if self.Tool:GetAttribute("LobbySafeZone") == false or not root or Zones.IsAboveLobby(root.Position) then
				return
			end
			if os.clock() - self.LastNotification < NotificationCooldown then
				return
			end
			self.LastNotification = os.clock()
			self.NotificationController:Push(table.clone(SafeZoneNotification))
		end)
	)
end

function Bat:Disconnect()
	for _, connection in pairs(self.Connections) do
		connection:Disconnect()
	end
	table.clear(self.Connections)
end

return Bat
