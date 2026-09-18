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
				local data = Rig.Create(template, patrol, self.Folder, AlertGui)
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

			self.AudioController:PlaySfx("Punch", { PlayOver = true, Parent = root })
			local humanoid = character:FindFirstChildOfClass("Humanoid")
			if humanoid and humanoid.Health > 0 then
				self.AnimationController:StopAnimations()
				humanoid:ChangeState(Enum.HumanoidStateType.Physics)
			end
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
			local target = Geometry.Clamp(data.Area, root.Position, data.Radius, data.PivotHeight)
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
		local target = Geometry.Clamp(data.Area, point, data.Radius, data.PivotHeight)
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
			self.AnimationController:StopAnimations()
			humanoid:ChangeState(Enum.HumanoidStateType.Physics)
		else
			humanoid:ChangeState(Enum.HumanoidStateType.GettingUp)
		end
	end

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
