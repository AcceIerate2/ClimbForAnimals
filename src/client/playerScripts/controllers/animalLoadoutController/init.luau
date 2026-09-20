-- Roblox Services
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Packages
local knit = require(ReplicatedStorage.src.Packages.knit)
local Signal = require(ReplicatedStorage.src.Packages.Signal)

-->
local AnimalLoadoutController = knit.CreateController({
	Name = "AnimalLoadoutController",
	Visible = false,
	Pending = false,

	Signals = {
		ToggleVisibility = Signal.new(),
	},
})

-- Public Methods
function AnimalLoadoutController:SetVisible(visible: boolean)
	if visible and self.HudController.HeightBarVisible then
		return
	end

	if self.Visible == visible then
		return
	end

	if visible then
		self.EggController:SetVisible(false)
	end

	self.Visible = visible
	self.HudController:ToggleRightButtonsVisibility(not visible)
	self.Signals.ToggleVisibility:Fire(visible)
end

function AnimalLoadoutController:ToggleVisibility()
	self:SetVisible(not self.Visible)
end

function AnimalLoadoutController:Request(action: string, referenceName: string?)
	if self.Pending then
		return
	end

	self.Pending = true

	self.AnimalLoadoutService
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
			elseif response.Message then
				self.NotificationController:Push({
					Message = response.Message,
					Color = Color3.fromRGB(80, 255, 100),
				})
			end
		end)
		:catch(warn)
		:finally(function()
			self.Pending = false
		end)
end

-- LifeCycle
function AnimalLoadoutController:KnitInit()
	self.AnimalLoadoutService = knit.GetService("AnimalLoadoutService")
	self.HudController = knit.GetController("HudController")
	self.EggController = knit.GetController("EggController")
	self.NotificationController = knit.GetController("NotificationController")
end

return AnimalLoadoutController
