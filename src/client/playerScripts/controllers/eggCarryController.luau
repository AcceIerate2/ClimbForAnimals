-- Roblox Services
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")

-- Packages
local Signal = require(ReplicatedStorage.src.Packages.Signal)
local knit = require(ReplicatedStorage.src.Packages.knit)

-- Constants
local Player = Players.LocalPlayer

-->
local EggCarryController = knit.CreateController({
	Name = "EggCarryController",
	IsCarrying = false,
	Signals = {
		ToggleDropButton = Signal.new(), -- (visible: boolean)
	},
})

-- Private Methods
function EggCarryController:updateCarryState()
	local isCarrying = Player:GetAttribute("CarryingEgg") ~= nil
	if isCarrying == self.IsCarrying then
		return
	end

	self.IsCarrying = isCarrying
	if isCarrying and not self.FallController.IsFalling then
		self.AnimationController:Play("Carry", false, { 0.1 })
	elseif not isCarrying then
		self.AnimationController:Stop("Carry", { 0.1 })
	end

	self.Signals.ToggleDropButton:Fire(isCarrying)
	self:tryClaimEgg()
end

-- Reaching the lobby (not while falling) with an egg completes the steal
function EggCarryController:tryClaimEgg()
	if not self.IsCarrying or self.FallController.IsFalling or self.ZoneController.Zone ~= "Lobby" then
		return
	end

	self.EggSpawnService
		:ClaimEgg()
		:andThen(function(response: { Status: boolean, EggName: string?, Reason: string? })
			if not response.Status then
				-- The server used to reject the claim silently, which made a legitimate steal look
				-- like nothing happened at all.
				if response.Reason then
					warn(`[EggCarryController] Claim rejected: {response.Reason}`)
				end

				return
			end

			self.AudioController:PlaySfx("Success", {
				PlayOver = true,
				Parent = SoundService,
			})
			self.NotificationController:Push({
				Message = `{response.EggName} Egg Stolen Successfully!`,
				Color = Color3.fromRGB(0, 255, 0),
				Sound = "Generic",
			})
		end)
		:catch(warn)
end

-- Public Methods
function EggCarryController:DropEgg()
	self.EggSpawnService:DropEgg():catch(warn)
end

-- LifeCycle
function EggCarryController:KnitInit()
	self.EggSpawnService = knit.GetService("EggSpawnService")
	self.AnimationController = knit.GetController("AnimationController")
	self.FallController = knit.GetController("FallController")
	self.ZoneController = knit.GetController("ZoneController")
	self.NotificationController = knit.GetController("NotificationController")
	self.AudioController = knit.GetController("AudioController")
end

function EggCarryController:KnitStart()
	Player:GetAttributeChangedSignal("CarryingEgg"):Connect(function()
		self:updateCarryState()
	end)
	self:updateCarryState()

	-- Fall mode plays Falling (FallController stops the other animations); Carry comes back after the fall
	self.FallController.Signals.FallingChanged:Connect(function(isFalling: boolean)
		if not self.IsCarrying then
			return
		end

		if isFalling then
			self.AnimationController:Stop("Carry", { 0.1 })
		else
			-- deferred: the landing FrontFlip stops every animation right after this signal
			task.defer(function()
				if self.IsCarrying then
					self.AnimationController:Play("Carry", false, { 0.1 })
				end
			end)
			self:tryClaimEgg()
		end
	end)

	self.ZoneController.Signals.ZoneChanged:Connect(function()
		self:tryClaimEgg()
	end)
end

return EggCarryController
