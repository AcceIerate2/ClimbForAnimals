-- Roblox Services
local Players = game:GetService("Players")
local MarketplaceService = game:GetService("MarketplaceService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Packages
local Signal = require(ReplicatedStorage.src.Packages.Signal)
local knit = require(ReplicatedStorage.src.Packages.knit)

-- Constants
local AutoHatchTimeout = 5 -- seconds to wait for the skipped egg's CanHatch to replicate

-->
local EggController = knit.CreateController({
	Name = "EggController",
	Signals = {
		ToggleVisibility = Signal.new(),
	},

	Visible = false,
})

-- Public Methods
function EggController:SetVisible(visible: boolean)
	if visible and self.HudController.HeightBarVisible then
		return
	end

	if self.Visible == visible then
		return
	end

	if visible then
		knit.GetController("AnimalLoadoutController"):SetVisible(false)
	end

	self.Visible = visible
	self.HudController:ToggleRightButtonsVisibility(not visible)
	self.Signals.ToggleVisibility:Fire(visible)
end

function EggController:ToggleVisibility()
	self:SetVisible(not self.Visible)
end

function EggController:ActivateEgg(referenceName: string)
	local egg = self.DataController:GetValue("PlacedEggs")[referenceName]
	if not egg then
		return
	end

	if egg.CanHatch then
		self:SetVisible(false)
		self.EggHatchController:Hatch(referenceName)
	else
		self:PurchaseGrowth("SkipTimer", referenceName)
	end
end

-- A skipped egg hatches on its own once the server marks it ready.
function EggController:hatchWhenReady(referenceName: string)
	task.spawn(function()
		local deadline = os.clock() + AutoHatchTimeout
		while os.clock() < deadline do
			local egg = self.DataController:GetValue("PlacedEggs")[referenceName]
			if not egg then
				return
			end
			if egg.CanHatch then
				self:SetVisible(false)
				self.EggHatchController:Hatch(referenceName)
				return
			end
			task.wait(0.1)
		end
	end)
end

function EggController:PurchaseGrowth(action: string, referenceName: string?)
	if self.PurchasePending or self.MonetizationController.PromptActive then
		return
	end

	self.PurchasePending = true
	self.PendingSkip = action == "SkipTimer" and referenceName or nil
	self.EggPurchaseService
		:RequestPurchase(action, referenceName)
		:andThen(function(response)
			if not response.Status then
				self.PurchasePending = false
				if response.Silent then
					return
				end

				self.NotificationController:Push({
					Message = response.Reason,
					Color = Color3.fromRGB(255, 0, 0),
					Sound = "Decline",
				})
				return
			end

			if response.UsedCredit then
				self.PurchasePending = false
				if self.PendingSkip then
					self:hatchWhenReady(self.PendingSkip)
					self.PendingSkip = nil
				end
				return
			end

			self.PendingProductId = response.ProductId
			if not self.MonetizationController:promptPurchase("Product", response.ProductId) then
				self.EggPurchaseService:CancelPrompt(response.ProductId):catch(warn)
				self.PurchasePending = false
				self.PendingProductId = nil
			end
		end)
		:catch(function(message)
			if self.PendingProductId then
				self.EggPurchaseService:CancelPrompt(self.PendingProductId):catch(warn)
			end
			self.PurchasePending = false
			self.PendingProductId = nil
			warn(message)
		end)
end

-- LifeCycle
function EggController:KnitInit()
	self.HudController = knit.GetController("HudController")
	self.DataController = knit.GetController("DataController")
	self.EggHatchController = knit.GetController("EggHatchController")
	self.NotificationController = knit.GetController("NotificationController")
	self.MonetizationController = knit.GetController("MonetizationController")
	self.EggPurchaseService = knit.GetService("EggPurchaseService")
end

function EggController:KnitStart()
	self.Signals.ToggleVisibility:Fire(self.Visible)
	self.EggPurchaseService.PurchaseResolved:Connect(function(used: boolean)
		self.PurchasePending = false
		self.PendingProductId = nil
		if used and self.PendingSkip then
			self:hatchWhenReady(self.PendingSkip)
		end
		self.PendingSkip = nil
		if not used then
			self.NotificationController:Push({
				Message = "Purchase saved! Use it on your next growing egg.",
				Color = Color3.fromRGB(80, 255, 100),
				Sound = "Success",
			})
		end
	end)

	MarketplaceService.PromptProductPurchaseFinished:Connect(function(userId, productId, purchased)
		if userId == Players.LocalPlayer.UserId and productId == self.PendingProductId and not purchased then
			self.PurchasePending = false
			self.PendingProductId = nil
		end
	end)
end

return EggController
