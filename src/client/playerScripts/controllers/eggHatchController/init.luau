-- Roblox Services
local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")

-- Packages
local knit = require(ReplicatedStorage.src.Packages.knit)
local promise = require(ReplicatedStorage.src.Packages.promise)

-- Utility Modules
local InstanceCreator = require(ReplicatedStorage.src.utility.InstanceCreator)
local WaitForUiDesc = require(ReplicatedStorage.src.utility.WaitForUiDesc)
local PlayTween = require(ReplicatedStorage.src.utility.PlayTween)

-- Config Modules
local eggConfig = require(ReplicatedStorage.src.GameConfiguration.Gameplay.eggConfig)

-->
local EggHatchController = knit.CreateController({ Name = "EggHatchController" })

-- Private Methods
function EggHatchController:getEggAsset(referenceName: string): any
	return self.Base:WaitForChild("PlacedEggs"):WaitForChild(referenceName, 3)
end

function EggHatchController:breakEffect(referenceName: string, meshPart: MeshPart)
	local cFrame = meshPart.CFrame
	local size = meshPart.Size

	-- Debris
	for _ = 8, 1, -1 do
		local debrisSize = Vector3.new(
			size.X * math.random(18, 32) / 100,
			size.Y * math.random(12, 24) / 100,
			size.Z * math.random(18, 32) / 100
		)

		local offset = Vector3.new(
			size.X * math.random(-35, 35) / 100,
			size.Y * math.random(-15, 35) / 100,
			size.Z * math.random(-35, 35) / 100
		)

		local debrisPart = InstanceCreator("Part", "EggDebris", workspace, {
			Size = debrisSize,
			CFrame = cFrame * CFrame.new(offset) * CFrame.Angles(
				math.rad(math.random(0, 360)),
				math.rad(math.random(0, 360)),
				math.rad(math.random(0, 360))
			),

			Color = eggConfig[referenceName:split("_")[1]].EggColor,
			CanCollide = true,
			CanTouch = false,
			CanQuery = false,
			Anchored = false,
		}) :: BasePart

		local direction =
			Vector3.new(math.random(-100, 100) / 100, math.random(80, 140) / 100, math.random(-100, 100) / 100).Unit

		debrisPart:ApplyImpulse(direction * debrisPart.AssemblyMass * math.random(18, 26))

		debrisPart:ApplyAngularImpulse(
			Vector3.new(math.random(-10, 10), math.random(-10, 10), math.random(-10, 10)) * debrisPart.AssemblyMass
		)

		task.delay(0.8, function()
			if not debrisPart.Parent then
				return
			end

			PlayTween(debrisPart, TweenInfo.new(0.25, Enum.EasingStyle.Linear), {
				Transparency = 1,
			})
		end)

		Debris:AddItem(debrisPart, 1.1)
	end

	-- Egg pop
	PlayTween(meshPart, TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Size = size * 1.3,
		Transparency = 1,
	}, function()
		meshPart:Destroy()
	end)
end

function EggHatchController:shakeEffect(meshPart: MeshPart)
	return promise.new(function(resolve, _reject, _onCancel)
		for i = 1, 3 do
			local axis = math.random(1, 2)
			local direction = math.random(0, 1) == 0 and -1 or 1

			local angle = math.rad(math.random(7, 10) + (i * 3)) * direction

			local rotation = if axis == 1 then CFrame.Angles(angle, 0, 0) else CFrame.Angles(0, 0, angle)

			local origin = meshPart.CFrame

			local target = origin
				* CFrame.new(0, -meshPart.Size.Y / 2, 0)
				* rotation
				* CFrame.new(0, meshPart.Size.Y / 2, 0)

			self.AudioController:PlaySfx("EggMovement", {
				PlayOver = true,
				Parent = SoundService,
			})

			local tweenInfo = TweenInfo.new(0.045, Enum.EasingStyle.Linear, Enum.EasingDirection.Out, i, true)

			PlayTween(meshPart, tweenInfo, {
				CFrame = target,
			}).Completed:Wait()

			task.wait(0.6 - (i * 0.13))
		end

		resolve()
	end)
end

function EggHatchController:animalEffect(referenceName: string)
	local eggName = referenceName:split("_")[1]
	local eggData = eggConfig[eggName]
	local animalName = eggData.Animal
end

-- Public Methods
function EggHatchController:Hatch(referenceName: string)
	local eggAsset = self:getEggAsset(referenceName)
	local meshPart = WaitForUiDesc(eggAsset, "MeshPart", {}, 3)

	-- Destroy Gui
	local adorneeGui = eggAsset:WaitForChild("EggStats"):WaitForChild("AdorneeGui").Value
	if adorneeGui then
		adorneeGui:Destroy()
	end
	eggAsset:WaitForChild("EggStats"):Destroy()

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
					self:breakEffect(referenceName, meshPart)
					self.AudioController:PlaySfx("Reveal", { playOver = true, Parent = SoundService })
					self:animalEffect()
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
