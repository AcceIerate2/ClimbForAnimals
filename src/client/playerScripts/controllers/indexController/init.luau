-- Roblox Services
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Packages
local knit = require(ReplicatedStorage.src.Packages.knit)
local Signal = require(ReplicatedStorage.src.Packages.Signal)

-->
local IndexController = knit.CreateController({
	Name = "IndexController",
	Selected = nil,
	Pending = false,
	SelectionChanged = Signal.new(),
})

-- Public Methods
function IndexController:Select(animalName: string)
	self.SelectionChanged:Fire(animalName)
end

function IndexController:Claim()
	if self.Pending or not self.Selected then
		return
	end

	self.Pending = true

	self.IndexService
		:Claim(self.Selected)
		:andThen(function(response)
			self.NotificationController:Push({
				Message = response.Status and "Index reward claimed!" or response.Reason,
				Color = response.Status and Color3.fromRGB(80, 255, 100) or Color3.fromRGB(255, 0, 0),
			})
		end)
		:catch(warn)
		:finally(function()
			self.Pending = false
		end)
end

-- LifeCycle
function IndexController:KnitInit()
	self.IndexService = knit.GetService("IndexService")
	self.NotificationController = knit.GetController("NotificationController")
end

return IndexController
