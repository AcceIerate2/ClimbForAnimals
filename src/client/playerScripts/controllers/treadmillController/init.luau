-- Roblox Services
local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")

-- Packages
local Signal = require(ReplicatedStorage.src.Packages.Signal)
local knit = require(ReplicatedStorage.src.Packages.knit)

-- Utility Modules
local partOfCharacter = require(ReplicatedStorage.src.utility.partOfCharacter)
local InstanceCreator = require(ReplicatedStorage.src.utility.InstanceCreator)
local CollisionHandler = require(ReplicatedStorage.src.utility.CollisionHandler)
local particleEmitter = require(ReplicatedStorage.src.utility.particleEmitter)
local PlayTween = require(ReplicatedStorage.src.utility.PlayTween)
local Spring = require(ReplicatedStorage.src.utility.Spring)
local WaitForUiDesc = require(ReplicatedStorage.src.utility.WaitForUiDesc)

-- Config Modules
local treadmillConfig = require(ReplicatedStorage.src.GameConfiguration.Gameplay.treadmillConfig)

-- Constants
local Player = Players.LocalPlayer
local AssetsFolder = ReplicatedStorage:WaitForChild("Assets")
local TreadmillAssets = AssetsFolder:WaitForChild("Treadmills")
local BonusVFX = AssetsFolder:WaitForChild("Vfx"):WaitForChild("BonusVfx")

-- Helper Functions
local function playerOnTreadmill(primaryPart: BasePart): boolean
	local partsInPart = workspace:GetPartsInPart(primaryPart)
	for _, basePart in pairs(partsInPart) do
		local character = partOfCharacter(basePart)
		if character then
			local playerCharacter = Players:GetPlayerFromCharacter(character)
			if playerCharacter == Player then
				return true
			end
		end
	end
	return false
end

-->
local TreadmillController = knit.CreateController({
	Name = "TreadmillController",
	OnTreadmill = false,
	DisableActivation = false,
	Connections = {},
	Signals = {
		ShowMultiplierButton = Signal.new(),
		TreadmillDeactivated = Signal.new(),
		ToggleStopBtnVisibility = Signal.new(),
	},
})

-- Private Methods
function TreadmillController:disconnect()
	for _, connection in pairs(self.Connections or {}) do
		if typeof(connection) == "RBXScriptConnection" then
			connection:Disconnect()
		end
	end
	table.clear(self.Connections)
end

function TreadmillController:connect(treadmillAsset: any)
	self:disconnect()

	local elapsed = 0
	table.insert(
		self.Connections,
		RunService.Heartbeat:Connect(function(deltaTime: number)
			elapsed += deltaTime
			if elapsed < 0.25 then
				return
			end

			elapsed = 0
			if not playerOnTreadmill(treadmillAsset.PrimaryPart) then
				if self.OnTreadmill then
					self:DeactivateTreadmill(treadmillAsset)
				end

				self.OnTreadmill = false
				return
			end

			if self.DisableActivation then
				return
			end

			if not self.OnTreadmill then
				self.OnTreadmill = true
				self:ActivateTreadmill(treadmillAsset)
			end
		end)
	)
end

function TreadmillController:playWalkAnimation()
	local character = Player.Character
	if not character then
		return
	end

	local humanoid = character:FindFirstChild("Humanoid")
	if not humanoid then
		return
	end

	local animator = humanoid:FindFirstChild("Animator") :: Animator
	if not animator then
		return
	end

	local animation = InstanceCreator("Animation", "Animation", script, {
		AnimationId = "rbxassetid://507777826",
	})

	self.LoadedAnimation = animator:LoadAnimation(animation)
	self.LoadedAnimation:Play(0.1)
	self.LoadedAnimation:AdjustSpeed(self:GetWalkSpeed() / 16)
	animation:Destroy()
end

function TreadmillController:toggleAnimateScript(character: any, toggle: boolean)
	local animateScriot = character:FindFirstChild("Animate")
	if animateScriot then
		animateScriot.Enabled = toggle
	end
end

function TreadmillController:removeCharacterFromTreadmill(character: any)
	local humanoid: Humanoid, HumanoidRootPart: BasePart =
		character:FindFirstChildOfClass("Humanoid"), character:FindFirstChild("HumanoidRootPart")

	if not humanoid or not HumanoidRootPart then
		return
	end

	self:toggleAnimateScript(character, true)

	humanoid.Jump = false
	humanoid:ChangeState(Enum.HumanoidStateType.Running)
	humanoid.WalkSpeed = self.LastWalkSpeed or 16
	humanoid:Move(Vector3.zero, false)

	-- Clear Velocity
	for _, desc in pairs(character:GetDescendants()) do
		if desc:IsA("BasePart") then
			desc.AssemblyLinearVelocity = Vector3.zero
		end
	end

	-- Pivot Character away from Treadmill
	character:PivotTo(
		self.Base:WaitForChild("TreadmillOffCFrame"):GetPivot() * CFrame.new(0, character:GetExtentsSize().Y / 2, 0)
	)

	-- Unanchor
	HumanoidRootPart.Anchored = false
end

function TreadmillController:listenForCharacterDeath()
	local connection = nil
	local function disconnect()
		if typeof(connection) == "RBXScriptConnection" then
			connection:Disconnect()
			connection = nil
		end
	end

	local function connect(newCharacter)
		local humanoid = newCharacter:WaitForChild("Humanoid") :: Humanoid
		connection = humanoid.Died:Connect(function()
			disconnect()
			self:DeactivateTreadmill()
		end)
	end

	if Player.Character then
		connect(Player.Character)
	end

	Player.CharacterAdded:Connect(function(newCharacter: any)
		disconnect()
		connect(newCharacter)
	end)
end

function TreadmillController:toggleOtherPlayerTreadmillVisibility(data: {
	Owner: Player,
	Treadmill: string,
	Base: any,
	Visible: boolean,
})
	if data.Owner == Player then
		return
	end

	data.Base:WaitForChild("Treadmill"):ClearAllChildren()

	if data.Visible then
		-- Spawn Treadmill Asset on player's Base
		local treadmillAsset = TreadmillAssets:WaitForChild(data.Treadmill):Clone()
		CollisionHandler.ToggleCollisionProperties(treadmillAsset, {
			CanCollide = false,
			Anchored = true,
		}, {})

		treadmillAsset:PivotTo(data.Base:WaitForChild("TreadmillCFrame"):GetPivot())
		treadmillAsset.Parent = data.Base:WaitForChild("Treadmill")

		-- Place Owner's Character on treadmill
		local function pivotCharacter()
			if data.Owner.Character then
				data.Owner.Character:PivotTo(
					treadmillAsset:GetPivot()
						* CFrame.Angles(0, math.rad(-90), 0)
						* CFrame.new(0, (data.Owner.Character:GetExtentsSize().Y / 2) + 1.25, 0)
				)
			end
		end

		pivotCharacter()
		task.delay(1, pivotCharacter)
	end
end

-- Public Methods
function TreadmillController:ActivateTreadmill(treadmillAsset)
	local character = Player.Character
	if not character then
		self.OnTreadmill = false
		return
	end

	-- Bind Jump/Deactivate Action
	ContextActionService:BindActionAtPriority("TreadmillJump", function(_, inputState)
		if inputState == Enum.UserInputState.Begin then
			self.OnTreadmill = false
			self:DeactivateTreadmill()
		end

		return Enum.ContextActionResult.Sink
	end, false, Enum.ContextActionPriority.High.Value, Enum.PlayerActions.CharacterJump)

	--ContextActionService:SetTitle("TreadmillJump", "Exit")
	--ContextActionService:SetPosition("TreadmillJump", UDim2.fromScale(0.6, 0.7))
	self.Signals.ToggleStopBtnVisibility:Fire(true)

	--
	local humanoid: Humanoid, HumanoidRootPart: BasePart =
		character:FindFirstChildOfClass("Humanoid"), character:FindFirstChild("HumanoidRootPart")

	if humanoid and HumanoidRootPart then
		-- Reset Character Animations
		self:toggleAnimateScript(character, false)
		local animator = humanoid:FindFirstChildOfClass("Animator")
		if animator then
			for _, track in animator:GetPlayingAnimationTracks() do
				track:Stop(0.1)
			end
		end

		--
		self.LastWalkSpeed = humanoid.WalkSpeed
		humanoid.WalkSpeed = 0
		HumanoidRootPart.Anchored = true
	end

	self:playWalkAnimation()
	character:PivotTo(
		treadmillAsset:GetPivot()
			* CFrame.Angles(0, math.rad(-90), 0)
			* CFrame.new(0, (character:GetExtentsSize().Y / 2) + 1.25, 0)
	)

	self.TreadmillService:ActivateTreadmill():andThen(function() end):catch(warn)
end

function TreadmillController:DeactivateTreadmill()
	self.Signals.TreadmillDeactivated:Fire()

	local character = Player.Character
	if character then
		self:removeCharacterFromTreadmill(character)
	end

	if self.LoadedAnimation then
		self.LoadedAnimation:Stop()
		self.LoadedAnimation:Destroy()
		self.LoadedAnimation = nil
	end

	self.TreadmillService:DeactivateTreadmill():andThen(function() end):catch(warn)

	ContextActionService:UnbindAction("TreadmillJump")
	self.Signals.ToggleStopBtnVisibility:Fire(false)

	self.DisableActivation = true
	task.delay(1, function()
		self.DisableActivation = false
	end)
end

function TreadmillController:PlaceTreadmill(treadmillName: string, playUpgradeEffects: boolean?)
	if typeof(treadmillName) ~= "string" then
		return
	end

	self:disconnect()
	self.Base:WaitForChild("Treadmill"):ClearAllChildren()
	local treadmillAsset = TreadmillAssets:WaitForChild(treadmillName):Clone()

	CollisionHandler.ToggleCollisionProperties(treadmillAsset, {
		CanCollide = false,
		Anchored = true,
	}, {})

	treadmillAsset:PivotTo(self.Base:WaitForChild("TreadmillCFrame"):GetPivot())
	treadmillAsset.Parent = self.Base:WaitForChild("Treadmill")

	if playUpgradeEffects then
		treadmillAsset:ScaleTo(0.85)
		Spring.target(treadmillAsset, 0.5, 6, {
			Scale = 1,
		})

		local highlight = InstanceCreator("Highlight", "Highlight", treadmillAsset, {
			FillColor = Color3.fromRGB(255, 255, 255),
			OutlineTransparency = 1,
			FillTransparency = 0.5,
		})

		PlayTween(highlight, TweenInfo.new(1), {
			FillTransparency = 1,
		}, function()
			highlight:Destroy()
		end)
	end

	self:connect(treadmillAsset)
end

function TreadmillController:ClaimMultiplier(id: string)
	-- Notify Server
	self.TreadmillService.MultiplierClicked:Fire(id)

	-- Emit Vfx
	local character, rootPart =
		Player.Character, Player.Character and Player.Character:FindFirstChild("HumanoidRootPart")
	if character and rootPart then
		particleEmitter(BonusVFX, rootPart)
	end

	-- Increase Animation Speed
	self.LoadedAnimation:AdjustSpeed(self:GetWalkSpeed() / 8)
	task.delay(treadmillConfig.MultiplierDuration, function()
		self.LoadedAnimation:AdjustSpeed(self:GetWalkSpeed() / 16)
	end)

	-- Play Sfx
	self.AudioController:PlaySound("Bonus", {
		PlayOver = true,
		Parent = SoundService,
	})
end

function TreadmillController:GetWalkSpeed()
	return treadmillConfig.LevelConfig[self:GetLevel()].WalkingSpeed
end

function TreadmillController:GetLevel()
	return self.DataController:GetValue("TreadmillLevel") or 0
end

function TreadmillController:GetLevelCost(level: number)
	if level == 0 then
		return 0
	end

	return treadmillConfig.LevelConfig[level].UpgradeCost
end

function TreadmillController:GetTreadmillFromLevel(): string?
	local level = self:GetLevel()
	local levelConfig = treadmillConfig.LevelConfig[level]
	if not levelConfig then
		return nil
	end
	return levelConfig.Treadmill
end

function TreadmillController:UpgradeTreadmill()
	self.TreadmillService
		:RequestToUpgrade()
		:andThen(function(response: { Status: boolean, Reason: string? })
			if not response.Status then
				self.NotificationController:Push({
					Message = response.Reason,
					Color = Color3.fromRGB(255, 0, 0),
					Sound = "Decline",
				})
				return
			end
		end)
		:catch(warn)
end

-- LifeCycle
function TreadmillController:KnitInit()
	self.TreadmillService = knit.GetService("TreadmillService")
	self.BaseController = knit.GetController("BaseController")
	self.DataController = knit.GetController("DataController")
	self.AudioController = knit.GetController("AudioController")
	self.NotificationController = knit.GetController("NotificationController")
	self.InputModeController = knit.GetController("InputModeController")
end

function TreadmillController:KnitStart()
	self.Base = self.BaseController:GetBase()
	self:PlaceTreadmill(self:GetTreadmillFromLevel())
	self:listenForCharacterDeath()

	-- Listen To TreadmillLevel Changes to update Treadmill Asset
	self.DataController:GetValueChangedSignal("TreadmillLevel"):Connect(function()
		local newTreadmillName = self:GetTreadmillFromLevel()

		local oldTreadmill = self.Base:WaitForChild("Treadmill"):FindFirstChildOfClass("Model")
		if oldTreadmill then
			Spring.target(oldTreadmill, 0.5, 12, {
				Scale = 0.85,
			})

			Spring.completed(oldTreadmill, function()
				self:PlaceTreadmill(newTreadmillName, true)
			end)
		else
			self:PlaceTreadmill(newTreadmillName, true)
		end

		self.AudioController:PlaySound("Upgrade", {
			PlayOver = false,
		})

		if self.OnTreadmill and self.LoadedAnimation then
			self.LoadedAnimation:AdjustSpeed(self:GetWalkSpeed() / 16)
		end
	end)

	-- Server Signals
	self.TreadmillService.ShowMultiplier:Connect(function(guid: string)
		self.Signals.ShowMultiplierButton:Fire(guid)
	end)

	self.TreadmillService.ToggleTreadmillVisibility:Connect(
		function(data: { Owner: Player, Treadmill: string, Visible: boolean, Base: any })
			self:toggleOtherPlayerTreadmillVisibility(data)
		end
	)

	-- Core Jump Button
	if self.InputModeController.CurrentInputMode == "Touch" then
		local jumpButton = WaitForUiDesc(Player.PlayerGui:WaitForChild("TouchGui"), "ImageButton", {
			Name = "JumpButton",
		}) :: GuiButton

		jumpButton.Activated:Connect(function()
			self:DeactivateTreadmill()
		end)
	end
end

return TreadmillController
