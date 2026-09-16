-- Roblox Services
local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")

-- Packages
local knit = require(ReplicatedStorage.src.Packages.knit)
local promise = require(ReplicatedStorage.src.Packages.promise)

-- Utility Modules
local WaitForUiDesc = require(ReplicatedStorage.src.utility.WaitForUiDesc)
local PlayTween = require(ReplicatedStorage.src.utility.PlayTween)
local InstanceCreator = require(ReplicatedStorage.src.utility.InstanceCreator)

-->
local EggHatchController = knit.CreateController({ Name = "EggHatchController" })

-- Private Methods
function EggHatchController:getEggAsset(referenceName: string): any
	return self.Base:WaitForChild("PlacedEggs"):WaitForChild(referenceName, 3)
end

function EggHatchController:breakEffect(meshPart: MeshPart)
	local eggCFrame = meshPart.CFrame
	local eggColor = meshPart.Color
	local eggMaterial = meshPart.Material

	meshPart:Destroy()

	for _ = 1, 7 do
		local offset = Vector3.new(math.random(-10, 10) / 10, math.random(-5, 10) / 10, math.random(-10, 10) / 10)
		local newPart = InstanceCreator("Part", "EggDebris", workspace, {
			Size = Vector3.new(math.random(8, 14) / 10, math.random(8, 16) / 10, math.random(8, 14) / 10),

			Color = eggColor,
			Material = eggMaterial,

			CanCollide = false,
			CanQuery = false,
			Anchored = false,

			CFrame = eggCFrame * CFrame.new(offset),
		}) :: BasePart

		local direction =
			Vector3.new(math.random(-100, 100) / 100, math.random(40, 100) / 100, math.random(-100, 100) / 100).Unit

		newPart:ApplyImpulse(direction * newPart.AssemblyMass * math.random(12, 20))
		newPart.AssemblyAngularVelocity = Vector3.new(math.random(-10, 10), math.random(-10, 10), math.random(-10, 10))
		Debris:AddItem(newPart, 1.5)
	end
end

function EggHatchController:shakeEffect(meshPart: MeshPart)
	return promise.new(function(resolve, _reject, _onCancel)
		for _ = 3, 1, -1 do
			local axis = math.random(1, 2)
			local direction = math.random(0, 1) == 0 and -1 or 1
			local angle = math.rad(math.random(14, 18) * direction)

			local rotation = if axis == 1 then CFrame.Angles(angle, 0, 0) else CFrame.Angles(0, 0, angle)

			local origin = meshPart.CFrame

			local target = origin
				* CFrame.new(0, -meshPart.Size.Y / 2, 0)
				* rotation
				* CFrame.new(0, meshPart.Size.Y / 2, 0)

			self.AudioController:PlaySfx("EggMovement", {
				PlayOver = true,
				SoundService,
			})

			local tweenInfo = TweenInfo.new(0.04, Enum.EasingStyle.Linear, Enum.EasingDirection.Out, 2, true)

			PlayTween(meshPart, tweenInfo, {
				CFrame = target,
			}).Completed:Wait()

			task.wait(0.7)
		end

		resolve()
	end)
end

-- Public Methods
function EggHatchController:Hatch(referenceName: string)
	local eggAsset = self:getEggAsset(referenceName)
	local meshPart = WaitForUiDesc(eggAsset, "MeshPart", {}, 3)

	-->
	self.EggHatchService
		:Hatch(referenceName)
		:andThen(function(response: { Status: boolean, Reason: string })
			if not response.Status then
				self.NotificationController:Push({
					Message = response.Reason,
					Color = Color3.fromRGB(255, 0, 0),
					Sound = "Decline",
				})
				return
			end

			self:shakeEffect(meshPart)
				:andThen(function()
					self:breakEffect(meshPart)
				end)
				:catch(warn)
		end)
		:catch(warn)
end

-- LifeCycle
function EggHatchController:KnitInit()
	self.EggHatchService = knit.GetService("EggHatchService")
	self.NotificationController = knit.GetController("NotificationController")
	self.BaseController = knit.GetController("BaseController")
	self.AudioController = knit.GetController("AudioController")
end

function EggHatchController:KnitStart()
	self.Base = self.BaseController:GetBase()
end

return EggHatchController
