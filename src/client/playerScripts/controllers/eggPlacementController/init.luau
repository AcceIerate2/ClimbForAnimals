-- Roblox Services
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Packages
local knit = require(ReplicatedStorage.src.Packages.knit)

-- Constants
local Player = Players.LocalPlayer
local Mouse = Player:GetMouse()

-->
local EggPlacementController = knit.CreateController({
	Name = "EggPlacementController",
	Debounce = false,
	CooldownDuration = 1,
})

-- Public Methods
function EggPlacementController:Place(referenceName: string)
	if self.Debounce then
		return
	end

	self.Debounce = true
	task.delay(self.CooldownDuration, function()
		self.Debounce = false
	end)

	local mouseCFrame = Mouse.Hit
	self.EggPlacementService
		:RequestToPlace(referenceName, mouseCFrame)
		:andThen(function(response: { Status: boolean, Reason: string })
			if not response.Status and response.Reason then
				self.NotificationController:Push({
					Message = response.Reason,
					Color = Color3.fromRGB(255, 0, 0),
					Sound = "Decline",
				})
				return
			end

			self.NotificationController:Push({
				Message = `{referenceName:split("_")[1]} Egg Placed!`,
				Color = Color3.fromRGB(0, 255, 4),
				Sound = "Generic",
			})
		end)
		:catch(warn)
end

-- LifeCycle
function EggPlacementController:KnitInit()
	self.EggPlacementService = knit.GetService("EggPlacementService")
	self.DataController = knit.GetController("DataController")
	self.NotificationController = knit.GetController("NotificationController")
end

return EggPlacementController
