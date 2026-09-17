-- Roblox Services
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Packages
local knit = require(ReplicatedStorage.src.Packages.knit)

-- Constants
local Player = Players.LocalPlayer
local Mouse = Player:GetMouse()

-->
local AnimalController = knit.CreateController({
	Name = "AnimalController",
})

-- Public Methods
function AnimalController:PlaceAnimal(referenceName)
	local cFrame = Mouse.Hit
	print(cFrame)

	self.AnimalService
		:EquipAnimal(referenceName, cFrame)
		:andThen(function(response: { Status: boolean, Reason: string })
			if not response.Status and response.Reason then
				self.NotificationController:Push({
					Message = response.Reason,
					Color = Color3.fromRGB(255, 0, 0),
					Sound = "Decline",
				})
				return
			end

			print(response)
		end)
		:catch(warn)
end

-- LifeCycle
function AnimalController:KnitInit()
	self.AnimalService = knit.GetService("AnimalService")
	self.NotificationController = knit.GetController("NotificationController")
end

return AnimalController
