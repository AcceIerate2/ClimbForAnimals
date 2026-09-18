-- Roblox Services
local Players = game:GetService("Players")
local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

-- Packages
local knit = require(ReplicatedStorage.src.Packages.knit)

-- Utility Modules
local Geometry = require(ReplicatedStorage.src.utility.guardGeometry)

-- Modules
local Ragdoll = require(script.ragdoll)

-- Config Modules
local Config = require(ReplicatedStorage.src.GameConfiguration.Gameplay.guardConfig)

-- Constants
local Islands = workspace:WaitForChild("Structures"):WaitForChild("Islands")
local Assets = ReplicatedStorage:WaitForChild("Assets")

-->
local GuardService = knit.CreateService({
	Name = "GuardService",
	Client = {},
	Guards = {},
	NextRequest = {},
	NextCapture = {},
	Stuns = {},
	PlayerConnections = {},
})

-- Client Exposed Methods
function GuardService.Client:Capture(player: Player, guardId: string, guardPosition: Vector3, capturePosition: Vector3)
	return self.Server:Capture(player, guardId, guardPosition, capturePosition)
end

-- Private Methods
function GuardService:register(template: Instance)
	if not template:IsA("Model") or not template.Parent or template.Parent.Parent ~= self.Templates then
		return
	end

	local id = HttpService:GenerateGUID(false)
	self.Guards[id] = template
	template:SetAttribute("GuardId", id)
end

function GuardService:clearStun(player: Player)
	local stun = self.Stuns[player]
	if not stun then
		return
	end

	self.Stuns[player] = nil
	if stun.Timer then
		task.cancel(stun.Timer)
	end

	stun.Cleanup()
end

function GuardService:applyStun(
	player: Player,
	character: Model,
	humanoid: Humanoid,
	root: BasePart,
	direction: Vector3
)
	local owner
	local ownershipChanged = pcall(function()
		owner = root:GetNetworkOwner()
		root:SetNetworkOwner(nil)
	end)

	local restoreRagdoll = Ragdoll.Start(character, humanoid)
	local launchConnection
	local stun = {
		Cleanup = function()
			if launchConnection then
				launchConnection:Disconnect()
				launchConnection = nil
			end

			restoreRagdoll()
			if ownershipChanged and root.Parent then
				pcall(function()
					if owner and owner.Parent == Players then
						root:SetNetworkOwner(owner)
					else
						root:SetNetworkOwnershipAuto()
					end
				end)
			end
		end,
	}
	self.Stuns[player] = stun
	stun.Timer = task.delay(Config.RagdollDuration, function()
		stun.Timer = nil
		if self.Stuns[player] == stun then
			self:clearStun(player)
		end
	end)

	-- Wait for the physics step to rebuild assemblies after releasing the ragdoll joints.
	humanoid:ChangeState(Enum.HumanoidStateType.Physics)
	local flightTime = math.max(Config.PunchFlightTime, 0.1)
	local punchVelocity = direction * (Config.PunchDistance / flightTime)
		+ Vector3.yAxis * (workspace.Gravity * flightTime / 2)
	launchConnection = RunService.Heartbeat:Once(function()
		launchConnection = nil
		if self.Stuns[player] ~= stun or player.Character ~= character or humanoid.Health <= 0 then
			return
		end

		local pushed = {}
		for _, part in ipairs(character:GetDescendants()) do
			if part:IsA("BasePart") then
				local assembly = part.AssemblyRootPart
				if assembly and not assembly.Anchored and not pushed[assembly] then
					pushed[assembly] = true
					assembly:SetNetworkOwner(nil)
					assembly.AssemblyLinearVelocity = punchVelocity
				end
			end
		end
	end)
end

-- Public Methods
function GuardService:Capture(player: Player, guardId: string, guardPosition: Vector3, capturePosition: Vector3)
	if player.Parent ~= Players then
		return { Status = false }
	end

	local now = os.clock()
	if now < (self.NextRequest[player] or 0) then
		return { Status = false }
	end

	self.NextRequest[player] = now + Config.RequestCooldown
	if
		typeof(guardId) ~= "string"
		or not Geometry.IsFiniteVector(guardPosition)
		or not Geometry.IsFiniteVector(capturePosition)
		or now < (self.NextCapture[player] or 0)
	then
		return { Status = false }
	end

	local template = self.Guards[guardId]
	local carrier = self.EggSpawnService.Carriers[player]
	local egg = carrier and self.EggSpawnService.Eggs[carrier.EggId]
	if not egg or egg.Carrier ~= player then
		return { Status = false, Reason = "The server has no stolen egg registered to this player." }
	end

	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if
		not template
		or not template.Parent
		or not root
		or not humanoid
		or humanoid.Health <= 0
		or character:GetAttribute("GuardStunned")
	then
		return { Status = false, Reason = "Guard or character is unavailable." }
	end

	local island = Islands:FindFirstChild(template.Parent.Name)
	local area = island and island:FindFirstChild("Area")
	local patrol = island and Geometry.GetPatrolArea(island, template)
	if not area or not area:IsA("BasePart") or not patrol then
		return { Status = false, Reason = "Guard Area or PatrolZone is missing." }
	end

	if not Geometry.Contains(area, root.Position, Config.ZoneHeight, Config.HitTolerance) then
		return { Status = false, Reason = "The server character position is outside the guard Area." }
	end

	if not Geometry.Contains(area, capturePosition, Config.ZoneHeight) then
		return { Status = false, Reason = "The reported player position is outside the guard Area." }
	end

	if not Geometry.Contains(patrol, guardPosition, Config.ZoneHeight, Config.HitTolerance) then
		return { Status = false, Reason = "The guard hitbox center is outside the PatrolZone bounds or height." }
	end

	if (capturePosition - root.Position).Magnitude > Config.CapturePositionTolerance then
		return { Status = false, Reason = "The reported player position is too far from the server character position." }
	end

	local _, size = Geometry.GetHitboxBounds(template, Config.FallbackHitboxSize)
	if
		(guardPosition - capturePosition).Magnitude
		> size.Magnitude / 2 + root.Size.Magnitude / 2 + Config.HitTolerance
	then
		return { Status = false, Reason = "Guard hitbox is too far from the capture position." }
	end

	-- Do not accept catches through walls. The guard positions themselves are client simulations.
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	-- The carried egg must not block the validation ray leading to its own capture.
	params.FilterDescendantsInstances = { character, area, patrol, egg.Model }
	params.RespectCanCollide = true
	local obstruction = workspace:Raycast(capturePosition, guardPosition - capturePosition, params)
	if obstruction then
		return { Status = false, Reason = `Guard hit blocked by {obstruction.Instance:GetFullName()}.` }
	end

	-- The server chooses the egg from Carriers[player]; clients never provide an egg ID or owner.
	local dropped = self.EggSpawnService:DropCapturedEgg(player, capturePosition, { area, patrol })
	if not dropped.Status then
		return dropped
	end

	self.NextCapture[player] = now + Config.CaptureCooldown
	local direction = Vector3.new(Config.PunchDirection.X, 0, Config.PunchDirection.Z)
	direction = direction.Magnitude > 0.01 and direction.Unit or Vector3.xAxis
	self:applyStun(player, character, humanoid, root, direction)

	return {
		Status = true,
		Direction = direction,
		Dropped = dropped.Dropped,
		ExpiresAt = workspace:GetServerTimeNow() + Config.RagdollDuration,
	}
end

function GuardService:DisconnectPlayer(player: Player)
	self:clearStun(player)
	self.NextRequest[player], self.NextCapture[player] = nil, nil
	local connection = self.PlayerConnections[player]
	if connection then
		connection:Disconnect()
		self.PlayerConnections[player] = nil
	end
end

-- LifeCycle
function GuardService:KnitInit()
	self.EggSpawnService = knit.GetService("EggSpawnService")
	-- Keep authored positions, but remove shared visual guards from Workspace.
	self.Templates = Assets:FindFirstChild("Guards") or workspace:FindFirstChild("Guards")
	if not self.Templates then
		self.Templates = Instance.new("Folder")
		self.Templates.Name = "Guards"
	end

	self.Templates.Parent = Assets
	for _, group in ipairs(self.Templates:GetChildren()) do
		for _, template in ipairs(group:GetChildren()) do
			self:register(template)
		end
	end

	self.Templates.DescendantAdded:Connect(function(object)
		self:register(object)
	end)

	self.Templates.DescendantRemoving:Connect(function(object)
		local id = object:GetAttribute("GuardId")
		if id and self.Guards[id] == object then
			self.Guards[id] = nil
		end
	end)
end

function GuardService:KnitStart()
	local function connect(player: Player)
		self.PlayerConnections[player] = player.CharacterRemoving:Connect(function()
			self:clearStun(player)
		end)
	end

	Players.PlayerAdded:Connect(connect)
	Players.PlayerRemoving:Connect(function(player)
		self:DisconnectPlayer(player)
	end)

	for _, player in ipairs(Players:GetPlayers()) do
		connect(player)
	end
end

return GuardService
