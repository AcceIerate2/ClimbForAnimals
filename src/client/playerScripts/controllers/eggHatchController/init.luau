-- Roblox Services
local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")

-- Packages
local knit = require(ReplicatedStorage.src.Packages.knit)
local promise = require(ReplicatedStorage.src.Packages.promise)

-- Utility Modules
local InstanceCreator = require(ReplicatedStorage.src.utility.InstanceCreator)
local PlayTween = require(ReplicatedStorage.src.utility.PlayTween)
local particleEmitter = require(ReplicatedStorage.src.utility.particleEmitter)

-- Modules
local Reveal = require(script.reveal)

-- Config Modules
local eggConfig = require(ReplicatedStorage.src.GameConfiguration.Gameplay.eggConfig)

-- Constants
local DebrisCount = 3
local DebrisCollisionGroup = "Debris" -- registered in ServerScriptService.world.physics
local Player = Players.LocalPlayer
local AssetsFolder = ReplicatedStorage:WaitForChild("Assets")
local VfxFolder = AssetsFolder:WaitForChild("Vfx")
local VfxEggHatch = VfxFolder:FindFirstChild("VfxEggHatch") or VfxFolder:FindFirstChild("RevealEggHatch")

-->
local EggHatchController = knit.CreateController({
	Name = "EggHatchController",
	Pending = {},
})

-- Private Methods
function EggHatchController:getEggAsset(referenceName: string): any
	return self.Base:WaitForChild("PlacedEggs"):WaitForChild(referenceName, 3)
end

function EggHatchController:breakEffect(referenceName: string, meshPart: MeshPart)
	local cFrame = meshPart.CFrame
	local size = meshPart.Size

	-- Debris
	for _ = DebrisCount, 1, -1 do
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

			Color = eggConfig.Eggs[referenceName:split("_")[1]].EggColor,
			CollisionGroup = DebrisCollisionGroup,
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
		if meshPart.Parent then
			meshPart.Parent:Destroy()
		end
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

function EggHatchController:getRevealCFrame(groundCFrame: CFrame, elapsed: number): CFrame
	local character = Player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local targetPosition = root and root.Position

	return Reveal.GetCFrame(groundCFrame, elapsed, targetPosition)
end

function EggHatchController:animalEffect(response)
	return promise.new(function(resolve, reject, onCancel)
		local referenceName = response.ReferenceName
		local groundCFrame = response.CFrame
		local animal =
			self.AnimalController:BeginReveal(referenceName, response.AnimalName, self:getRevealCFrame(groundCFrame, 0))
		if not animal then
			reject("Couldn't create the revealed animal.")
			return
		end

		local defaultScale = animal:GetScale()
		animal:ScaleTo(Reveal.GetScale(defaultScale, 0))
		animal:PivotTo(self:getRevealCFrame(groundCFrame, 0))

		local meshPart = animal:FindFirstChildOfClass("MeshPart")
		if meshPart then
			if VfxEggHatch then
				particleEmitter(VfxEggHatch, meshPart)
			end

			local highlight = InstanceCreator("Highlight", "Highlight", animal, {
				OutlineTransparency = 1,
				FillTransparency = 0.5,
			})

			PlayTween(highlight, TweenInfo.new(0.35, Enum.EasingStyle.Linear, Enum.EasingDirection.Out), {
				FillTransparency = 1,
			}, function()
				highlight:Destroy()
			end)
		end

		local elapsed = 0
		local connection
		connection = RunService.RenderStepped:Connect(function(deltaTime: number)
			if not animal.Parent then
				connection:Disconnect()
				reject("Animal reveal was interrupted.")
				return
			end

			elapsed += deltaTime
			animal:ScaleTo(Reveal.GetScale(defaultScale, elapsed))
			animal:PivotTo(self:getRevealCFrame(groundCFrame, elapsed))

			if elapsed >= Reveal.Duration then
				connection:Disconnect()
				resolve()
			end
		end)

		onCancel(function()
			connection:Disconnect()
			self.AnimalController:CancelReveal(referenceName)
		end)
	end)
end

-- Public Methods
function EggHatchController:Hatch(referenceName: string)
	if self.Pending[referenceName] then
		return
	end

	local eggAsset = self:getEggAsset(referenceName)
	local meshPart = eggAsset and eggAsset:FindFirstChildOfClass("MeshPart")
	if not meshPart then
		return
	end

	self.Pending[referenceName] = true
	local animalReferenceName

	self.EggHatchService
		:Hatch(referenceName)
		:andThen(function(response)
			if not response.Status then
				self.NotificationController:Push({
					Message = response.Reason,
					Color = Color3.fromRGB(255, 0, 0),
					Sound = "Decline",
				})
				return
			end

			animalReferenceName = response.ReferenceName

			local eggStats = eggAsset:FindFirstChild("EggStats")
			local adornee = eggStats and eggStats:FindFirstChild("AdorneeGui")
			if adornee and adornee.Value then
				adornee.Value:Destroy()
			end

			if eggStats then
				eggStats:Destroy()
			end

			return self:shakeEffect(meshPart)
				:andThen(function()
					self:breakEffect(referenceName, meshPart)

					return promise.delay(0.12)
				end)
				:andThen(function()
					self.AudioController:PlaySfx("Reveal", { PlayOver = true, Parent = SoundService })

					return self:animalEffect(response)
				end)
				:andThen(function()
					return self.EggHatchService:CompleteHatch(animalReferenceName)
				end)
				:andThen(function(result)
					if not result.Status then
						self.AnimalController:CancelReveal(animalReferenceName)
						self.NotificationController:Push({
							Message = result.Reason .. " Your animal is in your backpack.",
							Color = Color3.fromRGB(255, 0, 0),
							Sound = "Decline",
						})
					end
				end)
		end)
		:catch(function(reason)
			if animalReferenceName then
				self.AnimalController:CancelReveal(animalReferenceName)
			end

			warn(reason)
		end)
		:finally(function()
			self.Pending[referenceName] = nil
		end)
end

-- LifeCycle
function EggHatchController:KnitInit()
	self.EggHatchService = knit.GetService("EggHatchService")
	self.NotificationController = knit.GetController("NotificationController")
	self.BaseController = knit.GetController("BaseController")
	self.AudioController = knit.GetController("AudioController")
	self.AnimalController = knit.GetController("AnimalController")
end

function EggHatchController:KnitStart()
	self.Base = self.BaseController:GetBase()
end

return EggHatchController
