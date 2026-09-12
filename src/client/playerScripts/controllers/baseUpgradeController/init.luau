-- Roblox Services
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Packages
local knit = require(ReplicatedStorage.src.Packages.knit)

-- Utility Modules
local Spring = require(ReplicatedStorage.src.utility.Spring)

-- Helper Functions
local function storeFencesAssetSize(asset)
	for _, v in pairs(asset:GetDescendants()) do
		if not v:IsA("BasePart") then
			continue
		end

		v:SetAttribute("Size", v.Size)
		v.Size = Vector3.new(0, 0, 0)
	end
end

-->

local BaseUpgradeController = knit.CreateController({
	Name = "BaseUpgradeController",
})

-- Public Methods
function BaseUpgradeController:Upgrade()
	self.BaseUpgradeService
		:RequestToUpgrade()
		:andThen(function(response: { Status: boolean, Reason: string?, FencesAsset: any })
			if not response.Status and typeof(response.Reason) == "string" then
				self.NotificationController:Push({
					Message = response.Reason,
					Color = Color3.fromRGB(255, 0, 0),
					Sound = "Decline",
				})
				return
			end

			self.AudioController:PlaySound("PlotExpand", { PlayOver = false })
			self.NotificationController:Push({
				Message = "Successfully upgraded your base!",
				Color = Color3.fromRGB(115, 255, 0),
				Sound = "Generic",
			})

			if response.FencesAsset then
				storeFencesAssetSize(response.FencesAsset)
				for _, v in pairs(response.FencesAsset:GetDescendants()) do
					if not v:IsA("BasePart") then
						continue
					end

					Spring.target(v, 0.5, 10, {
						Size = v:GetAttribute("Size"),
					})
				end
			end
		end)
		:catch(warn)
end

-- LifeCycle
function BaseUpgradeController:KnitInit()
	self.BaseUpgradeService = knit.GetService("BaseUpgradeService")
	self.NotificationController = knit.GetController("NotificationController")
	self.AudioController = knit.GetController("AudioController")
end

return BaseUpgradeController
