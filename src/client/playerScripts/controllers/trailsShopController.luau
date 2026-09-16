-- Roblox Services
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Packages
local Signal = require(ReplicatedStorage.src.Packages.Signal)
local knit = require(ReplicatedStorage.src.Packages.knit)

-- Constants
local TrailsShop = workspace:WaitForChild("Tends"):WaitForChild("TrailsShop")
local NotificationColors = {
	Default = Color3.fromRGB(255, 255, 255),
	Success = Color3.fromRGB(0, 255, 0),
	Failed = Color3.fromRGB(255, 0, 0),
}
local ResultNotifications = {
	Purchased = { Message = "Purchased %s!", Color = NotificationColors.Success, Sound = "Purshace" },
	Equipped = { Message = "Equipped %s", Color = NotificationColors.Default, Sound = "Generic" },
	Unequipped = { Message = "Unequipped %s", Color = NotificationColors.Default, Sound = "Generic" },
}

-->
local TrailsShopController = knit.CreateController({
	Name = "TrailsShopController",
	Signals = {
		TrailsChanged = Signal.new(), -- (owned: { [trailName]: true }, equipped: string?)
	},

	IsClimbing = false,
	IsFalling = false,
	TrailMode = "Walk",
})

-- Private Methods
function TrailsShopController:updateTrailMode()
	local mode = (self.IsClimbing or self.IsFalling) and "Climb" or "Walk"
	if mode == self.TrailMode then
		return
	end

	self.TrailMode = mode
	self.TrailsService:SetTrailMode(mode):catch(warn)
end

-- Public Methods
function TrailsShopController:SyncTrails()
	self.TrailsService
		:GetTrails()
		:andThen(function(trails: { Owned: { [string]: boolean }, Equipped: string? })
			self.Signals.TrailsChanged:Fire(trails.Owned, trails.Equipped)
		end)
		:catch(warn)
end

function TrailsShopController:SelectTrail(trailName: string)
	self.TrailsService
		:SelectTrail(trailName)
		:andThen(function(response)
			if not response.Status then
				self.NotificationController:Push({
					Message = response.Reason,
					Color = NotificationColors.Failed,
					Sound = "Decline",
				})
				return
			end

			local notification = ResultNotifications[response.Result]
			if notification then
				self.NotificationController:Push({
					Message = string.format(notification.Message, trailName),
					Color = notification.Color,
					Sound = notification.Sound,
				})
			end

			self.Signals.TrailsChanged:Fire(response.Owned, response.Equipped)
		end)
		:catch(warn)
end

-- LifeCycle
function TrailsShopController:KnitInit()
	self.PanelController = knit.GetController("PanelController")
	self.NotificationController = knit.GetController("NotificationController")
	self.TrailsService = knit.GetService("TrailsService")
	self.SpeedStateController = knit.GetController("SpeedStateController")
	self.FallController = knit.GetController("FallController")
	self.CharacterController = knit.GetController("CharacterController")
end

function TrailsShopController:KnitStart()
	local hitbox = TrailsShop:WaitForChild("Hitbox") :: BasePart
	self.PanelController:BindHitbox(hitbox, "Trails")

	-- Trail mode: Walk (torso) or Climb (hands and feet) while climbing or falling
	self.SpeedStateController.Signals.StateChanged:Connect(function(data: { NewState: string, WalkSpeed: number })
		self.IsClimbing = data.NewState == "Climbing"
		self:updateTrailMode()
	end)

	self.FallController.Signals.FallingChanged:Connect(function(isFalling: boolean)
		self.IsFalling = isFalling
		self:updateTrailMode()
	end)

	-- The server resets the mode to Walk on respawn
	self.CharacterController.CharacterAdded:Connect(function()
		self.IsClimbing = false
		self.IsFalling = false
		self.TrailMode = "Walk"
	end)
end

return TrailsShopController
