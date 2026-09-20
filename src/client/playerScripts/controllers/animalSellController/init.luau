-- Roblox Services
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Packages
local knit = require(ReplicatedStorage.src.Packages.knit)
local Signal = require(ReplicatedStorage.src.Packages.Signal)

-- Utility Modules
local NumberShortner = require(ReplicatedStorage.src.utility.NumberShortner)

-->
local AnimalSellController = knit.CreateController({
	Name = "AnimalSellController",
	Pending = false,
	Changed = Signal.new(),
})

-- Public Methods
function AnimalSellController:Request(action: string, referenceName: string?)
	if self.Pending then
		return
	end
	self.Pending = true
	self.Changed:Fire()
	self.Service
		:Request(action, referenceName)
		:andThen(function(response)
			if response.Silent then
				return
			end
			if not response.Status then
				self.NotificationController:Push({
					Message = response.Reason,
					Color = Color3.fromRGB(255, 0, 0),
					Sound = "Decline",
				})
				return
			end

			local subject = response.Name or `{response.Count} animals`
			self.NotificationController:Push({
				Message = `{subject} sold for ${NumberShortner(response.Amount)}!`,
				Color = Color3.fromRGB(80, 255, 100),
				Sound = "Cash", -- The cash sound after the offline earnings count-up.
			})
		end)
		:catch(function(message)
			warn(message)
			self.NotificationController:Push({
				Message = "Couldn't complete the sale. Please try again.",
				Color = Color3.fromRGB(255, 0, 0),
				Sound = "Decline",
			})
		end)
		:finally(function()
			self.Pending = false
			self.Changed:Fire()
		end)
end

-- LifeCycle
function AnimalSellController:KnitInit()
	self.Service = knit.GetService("AnimalSellService")
	self.NotificationController = knit.GetController("NotificationController")
end

return AnimalSellController
