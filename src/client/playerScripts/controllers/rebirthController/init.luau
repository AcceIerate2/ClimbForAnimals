-- Roblox Services
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Packages
local knit = require(ReplicatedStorage.src.Packages.knit)
local Signal = require(ReplicatedStorage.src.Packages.Signal)

-->
local RebirthController = knit.CreateController({
	Name = "RebirthController",

	Pending = false,
	Changed = Signal.new(),
})

-- Public Methods
function RebirthController:Request(skip: boolean?)
	if self.Pending then
		return
	end

	self.Pending = true
	self.Changed:Fire()
	self.Service
		:Request(skip == true)
		:andThen(function(response)
			if response.ProductId then
				self.MonetizationController:promptPurchase("Product", response.ProductId)
			elseif not response.Silent then
				self.NotificationController:Push({
					Message = response.Status and "Rebirth complete!"
						or response.Reason
						or "Couldn't rebirth. Please try again.",
					Color = response.Status and Color3.fromRGB(90, 255, 90) or Color3.fromRGB(255, 90, 90),
					Sound = response.Status and "Accept" or "Decline",
				})
			end
		end)
		:catch(function(message)
			warn(message)
			self.NotificationController:Push({
				Message = "Couldn't rebirth. Please try again.",
				Color = Color3.fromRGB(255, 90, 90),
				Sound = "Decline",
			})
		end)
		:finally(function()
			self.Pending = false
			self.Changed:Fire()
		end)
end

function RebirthController:Refresh()
	self.Service
		:GetState()
		:andThen(function(state)
			if state.Status then
				self.ProductId = state.ProductId
				self.Changed:Fire()
			end
		end)
		:catch(warn)
end

-- LifeCycle
function RebirthController:KnitInit()
	self.Service = knit.GetService("RebirthService")
	self.MonetizationController = knit.GetController("MonetizationController")
	self.NotificationController = knit.GetController("NotificationController")
end

function RebirthController:KnitStart()
	self:Refresh()
end

return RebirthController
