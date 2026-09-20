-- Roblox Services
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")

-- Packages
local knit = require(ReplicatedStorage.src.Packages.knit)

-- Utility Modules
local Geometry = require(ReplicatedStorage.src.utility.guardGeometry)

-- Modules
local Rig = require(script.rig)
local Hitbox = require(script.hitbox)

-- Config Modules
local Config = require(ReplicatedStorage.src.GameConfiguration.Gameplay.guardConfig)

-- Constants
local IslandAssets = workspace:WaitForChild("Structures"):WaitForChild("Islands")
local Assets = ReplicatedStorage:WaitForChild("Assets")
local AlertGui = Assets:WaitForChild("Gui"):WaitForChild("GuardAlertGui")
local Player = Players.LocalPlayer
local RandomGenerator = Random.new()

-->
local GuardController = knit.CreateController({
	Name = "GuardController",
	Guards = {},
	NextCapture = 0,
	NextRequest = 0,
	CapturePending = false,
})

-- Private Methods
function GuardController:syncGuards()
	local templates = Assets:FindFirstChild("Guards")
	if not templates then
		return
	end

	local found = {}
	for _, group in ipairs(templates:GetChildren()) do
		local island = IslandAssets:FindFirstChild(group.Name)
		local area = island and island:FindFirstChild("Area")
		if not area or not area:IsA("BasePart") then
			continue
		end

		for _, template in ipairs(group:GetChildren()) do
			if not template:IsA("Model") then
				continue
			end

			local id = template:GetAttribute("GuardId")
			local patrol = Geometry.GetPatrolArea(island, template)
			if not id or not patrol then
				continue
			end

			found[id] = true
			local existing = self.Guards[id]
			if existing and (existing.Area ~= patrol or existing.ProtectedArea ~= area) then
				Rig.Destroy(existing)
				self.Guards[id] = nil
			end

			if not self.Guards[id] then
				local data = Rig.Create(template, patrol, self.Folder, AlertGui, area)
				if data then
					data.Id = id
					data.ProtectedArea = area
					self.Guards[id] = data
				end
			end
		end
	end

	for id, data in pairs(self.Guards) do
		if not found[id] then
			Rig.Destroy(data)
			self.Guards[id] = nil
		end
	end
end

function GuardController:setDanger(active: boolean)
	if self.Danger == active then
		return
	end

	self.Danger = active
	if active then
		self.AudioController:PlaySfx("AlertDanger", { PlayOver = true, Parent = SoundService })
	end

	self.MusicController:SetDanger(active)
end

function GuardController:requestCapture(data, character: Model, root: BasePart)
	local now = os.clock()
	if self.CapturePending or now < self.NextCapture or now < self.NextRequest then
		return
	end

	self.CapturePending = true
	self.NextRequest = now + Config.RequestCooldown
	data.Model:SetAttribute("CaptureStatus", "Requesting")
	self.GuardService
		:Capture(data.Id, data.Hitbox.Position, root.Position)
		:andThen(function(response)
			if not response.Status then
				data.Model:SetAttribute("CaptureStatus", response.Reason or "Rejected (cooldown or invalid request)")
				if response.Reason and data.LastCaptureReason ~= response.Reason then
					data.LastCaptureReason = response.Reason
					warn(`[GuardController] Capture rejected: {response.Reason}`)
				end

				return
			end

			data.LastCaptureReason = nil
			data.Model:SetAttribute("CaptureStatus", "Captured")
			self.NextCapture = os.clock() + Config.CaptureCooldown
			if
				Player.Character ~= character
				or not root.Parent
				or workspace:GetServerTimeNow() >= response.ExpiresAt
			then
				return
			end

			-- Only the sound here: the ragdoll follows the GuardStunned attribute, so it fires from
			-- updateStun whether or not this response arrives first.
			self.AudioController:PlaySfx("Punch", { PlayOver = true, Parent = root })
		end)
		:catch(function(message)
			data.Model:SetAttribute("CaptureStatus", "Request failed")
			warn(`[GuardController] Capture request failed: {tostring(message)}`)
		end)
		:finally(function()
			self.CapturePending = false
		end)
end

function GuardController:updateGuard(data, character: Model, root: BasePart, canChase: boolean, now: number)
	local chase = canChase and Geometry.Contains(data.ProtectedArea, root.Position, Config.ZoneHeight)
	if chase then
		if data.State ~= "Chase" then
			Rig.Stop(data)
			data.State = "Chase"
			data.NextRepath = 0
			data.Model:SetAttribute("CaptureStatus", "Waiting for hitbox")
			Rig.Alert(data, true)
		end

		if now >= data.NextRepath then
			data.NextRepath = now + Config.ChaseRepathInterval
			-- Not inset by the guard's radius, and measured against the protected area instead of the
			-- patrol zone: the chase only runs while the player is already inside the protected area
			-- (the check above), so insetting it only left a strip along the border where the guard
			-- stopped short and could never reach the player -- 31 studs wide on the FirePhoenix.
			local target = Geometry.Clamp(data.ProtectedArea, root.Position, 0, data.PivotHeight)
			local distance = (target - data.Model:GetPivot().Position).Magnitude
			Rig.Move(data, target, distance / Config.ChaseSpeed)
			Rig.Animate(data, "Walk")
		end

		if Hitbox.Check(data, character) then
			self:requestCapture(data, character, root)
		end

		return true
	end

	if data.State == "Chase" then
		Rig.Stop(data)
		Rig.Alert(data, false)
		Rig.Animate(data, "Idle")
		data.State = "Idle"
		data.NextAction = now + Config.PatrolIdleDuration
		data.Model:SetAttribute("CaptureStatus", "Patrolling")
	end

	if now < data.NextAction then
		return false
	end

	if data.State == "Walk" then
		Rig.Stop(data)
		Rig.Animate(data, "Idle")
		data.State = "Idle"
		data.NextAction = now + Config.PatrolIdleDuration
	else
		local point = data.Area.CFrame:PointToWorldSpace(
			Vector3.new(
				RandomGenerator:NextNumber(-data.Area.Size.X / 2, data.Area.Size.X / 2),
				0,
				RandomGenerator:NextNumber(-data.Area.Size.Z / 2, data.Area.Size.Z / 2)
			)
		)
		-- Patrol keeps the radius inset (a wander point must not hang the guard off the edge), but
		-- the height comes from the protected area, since the patrol zone is a thin floating part.
		local target = Geometry.Clamp(data.Area, point, data.Radius, data.PivotHeight, data.ProtectedArea)
		Rig.Move(data, target, Config.PatrolWalkDuration)
		data.State = "Walk"
		data.NextAction = now + Config.PatrolWalkDuration
	end

	return false
end

function GuardController:updateGuards(now: number)
	local character = Player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local canChase = root ~= nil
		and Player:GetAttribute("CarryingEgg") ~= nil
		and humanoid ~= nil
		and humanoid.Health > 0
		and not character:GetAttribute("GuardStunned")
		and now >= self.NextCapture
	local danger = false
	for _, data in pairs(self.Guards) do
		if data.Model.Parent and data.Area.Parent and data.ProtectedArea.Parent then
			danger = self:updateGuard(data, character, root, canChase, now) or danger
		end
	end

	self:setDanger(danger)
end

function GuardController:cleanup()
	self.RenderConnection:Disconnect()
	self.Connection:Disconnect()
	self.CharacterAddedConnection:Disconnect()
	self.CharacterRemovingConnection:Disconnect()
	if self.StunConnection then
		self.StunConnection:Disconnect()
	end

	for _, data in pairs(self.Guards) do
		Rig.Destroy(data)
	end

	table.clear(self.Guards)
	self:setDanger(false)
end

-- The knockback is computed on this side for the same reason as the ragdoll: a velocity written
-- by the server is discarded by the client that simulates the character. The direction is the
-- same value the server used, since PunchDirection is a shared config constant. Applying it is
-- the ragdoll's job, because it has to happen before the joints are released.
-- Freezes the character for the knockback: no input, no turning, no animation. The body flies
-- rigid, which is the whole look of the punch. A ragdoll here fought the Humanoid instead (the
-- balance force held the player floating, and hinged knees locked the legs straight), so the stun
-- is these four properties plus an animation block.
function GuardController:freezeCharacter(character: Model, humanoid: Humanoid)
	local walkSpeed, jumpHeight = humanoid.WalkSpeed, humanoid.JumpHeight
	local jumpPower, autoRotate = humanoid.JumpPower, humanoid.AutoRotate

	humanoid.WalkSpeed = 0
	humanoid.JumpHeight = 0
	humanoid.JumpPower = 0
	humanoid.AutoRotate = false

	-- Physics takes the character away from the Humanoid controller, and it is what makes the
	-- knockback survive: a grounded Humanoid brakes horizontal velocity to match its WalkSpeed, so
	-- with WalkSpeed = 0 it cancelled the sideways part of the punch in the same frame and only the
	-- upward part was left. The joints stay intact, so the body still flies rigid.
	humanoid:ChangeState(Enum.HumanoidStateType.Physics)

	-- Stopping the current tracks is not enough: the default Animate script keeps feeding the run
	-- animation while the body flies, and fallController plays Falling once the fall passes half a
	-- second. Blocking AnimationPlayed for the whole stun covers every source at once.
	self.AnimationController:StopAnimations()

	local animator = humanoid:FindFirstChildOfClass("Animator")
	local blocker = animator and animator.AnimationPlayed:Connect(function(track: AnimationTrack)
		track:Stop(0)
	end)
	if animator then
		for _, track in ipairs(animator:GetPlayingAnimationTracks()) do
			track:Stop(0)
		end
	end

	return function()
		if blocker then
			blocker:Disconnect()
		end

		if humanoid.Parent then
			humanoid.WalkSpeed = walkSpeed
			humanoid.JumpHeight = jumpHeight
			humanoid.JumpPower = jumpPower
			humanoid.AutoRotate = autoRotate
			if humanoid.Health > 0 then
				humanoid:ChangeState(Enum.HumanoidStateType.GettingUp)
			end
		end
	end
end

function GuardController:getPunchVelocity(): Vector3
	local direction = Vector3.new(Config.PunchDirection.X, 0, Config.PunchDirection.Z)
	direction = direction.Magnitude > 0.01 and direction.Unit or Vector3.xAxis
	local flightTime = math.max(Config.PunchFlightTime, 0.1)

	return direction * (Config.PunchDistance / flightTime) + Vector3.yAxis * (workspace.Gravity * flightTime / 2)
end

function GuardController:connectCharacter(character: Model)
	if self.StunConnection then
		self.StunConnection:Disconnect()
	end

	local function updateStun()
		local humanoid = character:FindFirstChildOfClass("Humanoid")
		if Player.Character ~= character or not humanoid or humanoid.Health <= 0 then
			return
		end

		if character:GetAttribute("GuardStunned") then
			if self.RestoreStun then
				return
			end

			-- Done here, on the client that owns this character: the Humanoid state machine and the
			-- physics of a player's character run locally, so a freeze or a velocity written by the
			-- server is undone on the next frame.
			self.RestoreStun = self:freezeCharacter(character, humanoid)

			-- One frame after the state change, the way the old server version did it: writing the
			-- velocity in the same step gives the Humanoid controller one last chance to brake it.
			local root = character:FindFirstChild("HumanoidRootPart")
			local velocity = self:getPunchVelocity()
			RunService.Heartbeat:Once(function()
				if root and root.Parent and self.RestoreStun then
					root.AssemblyLinearVelocity = velocity
				end
			end)
		elseif self.RestoreStun then
			local restore = self.RestoreStun
			self.RestoreStun = nil
			restore()
		end
	end

	self.RestoreStun = nil
	self.StunConnection = character:GetAttributeChangedSignal("GuardStunned"):Connect(updateStun)
	if character:GetAttribute("GuardStunned") then
		updateStun()
	end

	for _, data in pairs(self.Guards) do
		data.LastCharacter = nil
	end
end

-- LifeCycle
function GuardController:KnitInit()
	self.GuardService = knit.GetService("GuardService")
	self.AudioController = knit.GetController("AudioController")
	self.MusicController = knit.GetController("MusicController")
	self.AnimationController = knit.GetController("AnimationController")
end

function GuardController:KnitStart()
	self.CharacterAddedConnection = Player.CharacterAdded:Connect(function(character)
		self:connectCharacter(character)
	end)

	self.CharacterRemovingConnection = Player.CharacterRemoving:Connect(function()
		if self.StunConnection then
			self.StunConnection:Disconnect()
			self.StunConnection = nil
		end

		self:setDanger(false)
	end)

	if Player.Character then
		self:connectCharacter(Player.Character)
	end

	self.Folder = Instance.new("Folder")
	self.Folder.Name = "LocalGuards"
	self.Folder.Parent = workspace

	self:syncGuards()
	local elapsed, nextSync = 0, 0
	self.RenderConnection = RunService.RenderStepped:Connect(function(deltaTime)
		local character = Player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")

		for _, data in pairs(self.Guards) do
			if data.Model.Parent then
				Rig.Update(data, deltaTime, root)
			end
		end
	end)

	self.Connection = RunService.Heartbeat:Connect(function(deltaTime)
		elapsed += deltaTime
		if elapsed < Config.UpdateInterval then
			return
		end

		elapsed %= Config.UpdateInterval
		local now = os.clock()
		if now >= nextSync then
			self:syncGuards()
			nextSync = now + 1
		end

		self:updateGuards(now)
	end)

	self.Folder.Destroying:Once(function()
		self:cleanup()
	end)
end

return GuardController
