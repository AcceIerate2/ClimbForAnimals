-- Roblox Services
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Packages
local knit = require(ReplicatedStorage.src.Packages.knit)
local Signal = require(ReplicatedStorage.src.Packages.Signal)

-- Config Modules
local Config = require(ReplicatedStorage.src.GameConfiguration.Economy.staminaUpgradeConfig)

-->
local StaminaUpgradeController = knit.CreateController({
	Name = "StaminaUpgradeController",
	Pending = false,
	Changed = Signal.new(),
})

-- Public Methods
function StaminaUpgradeController:Purchase()
	if self.Pending then
		return
	end

	self.Pending = true
	self.Changed:Fire()

	self.Service
		:Purchase(self.DataController:GetValue("StaminaLevel"))
		:andThen(function(response)
			if response.Silent then
				return
			end

			self.NotificationController:Push({
				-- Stamina points, the same numbers the bar and the panel show.
				Message = response.Status
						and `Upgraded Stamina {Config.GetMaxStamina(response.Level - 1)} > {Config.GetMaxStamina(
							response.Level
						)}!`
					or response.Reason,
				Color = response.Status and Color3.fromRGB(115, 255, 0) or Color3.fromRGB(255, 0, 0),
				Sound = response.Status and "Upgrade" or "Decline",
			})
		end)
		:catch(function(message)
			warn(message)
			self.NotificationController:Push({
				Message = "Couldn't upgrade stamina. Please try again.",
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
function StaminaUpgradeController:KnitInit()
	self.Service = knit.GetService("StaminaUpgradeService")
	self.DataController = knit.GetController("DataController")
	self.NotificationController = knit.GetController("NotificationController")
end

return StaminaUpgradeController
