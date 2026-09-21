-- Roblox Services
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

-- Packages
local knit = require(ReplicatedStorage.src.Packages.knit)

-- Utility Modules
local Targets = require(ReplicatedStorage.src.utility.tutorialTargets)
local Location = require(ReplicatedStorage.src.utility.tutorialLocation)

-- Config Modules
local Config = require(ReplicatedStorage.src.GameConfiguration.Gameplay.tutorialConfig)

-- Helper Functions
local function near(root, part, distance)
	local frame = Targets.GetCFrame(part)
	if not frame then
		return false
	end
	local offset = frame:PointToObjectSpace(root.Position)
	local half = Targets.GetSize(part) / 2
	local outside = Vector3.new(
		math.max(0, math.abs(offset.X) - half.X),
		math.max(0, math.abs(offset.Y) - half.Y),
		math.max(0, math.abs(offset.Z) - half.Z)
	)
	return outside.Magnitude <= distance
end

-->
local TutorialService = knit.CreateService({
	Name = "TutorialService",
	Client = {}, -- Progress is replicated through DataService; clients cannot complete steps.
	Training = {},
	PlatformTime = {},
	RouteExitTime = {},
})

-- Client Exposed Methods
function TutorialService.Client:GetWaypoints(_player: Player)
	return self.Server:GetWaypoints()
end

function TutorialService.Client:StaminaPanelClosed(player: Player)
	return self.Server:StaminaPanelClosed(player)
end

-- Public Methods
function TutorialService:StaminaPanelClosed(player: Player)
	if not Config.Enabled or not self.DataService:GetProfile(player) then
		return false
	end
	local state = self.DataService:GetValue(player, "Tutorial")
	-- Only dismissal is client-reported; the server still verifies the purchased upgrade.
	if
		not state.Initialized
		or state.Completed
		or state.Step ~= "CloseStamina"
		or self.DataService:GetValue(player, "StaminaLevel") < Config.StaminaTargetLevel
	then
		return false
	end
	self:save(player, state, "Treadmill")
	return true
end

function TutorialService:GetWaypoints()
	local folder = workspace:FindFirstChild(Config.PartsFolder)
	local waypoints = {}
	waypoints.Errors = {}
	if not folder then
		table.insert(waypoints.Errors, `Workspace.{Config.PartsFolder} does not exist on the server.`)
		return waypoints
	end
	for key, name in pairs(Config.Parts) do
		local part = folder:FindFirstChild(name, true)
		waypoints[key] = Targets.GetCFrame(part)
		if not waypoints[key] then
			local detail = part and `found unsupported {part.ClassName}` or "object not found"
			table.insert(waypoints.Errors, `Workspace.{Config.PartsFolder}.{name}: {detail}`)
		end
	end
	return waypoints
end

-- Private Methods
function TutorialService:save(player, state, step)
	self.RouteExitTime[player] = nil
	self.TutorialFunnelService:Track(player, state, step)
	state.Step = step
	state.Completed = step == "Finish"
	self.DataService:GetValueObject(player, "Tutorial"):Set(state)
end

function TutorialService:update(player, deltaTime)
	local profile = self.DataService:GetProfile(player)
	if not profile or not player:FindFirstChild("Synced") then
		return
	end

	local state = self.DataService:GetValue(player, "Tutorial")
	if state.Completed then
		return
	end
	if not state.Initialized then
		state.Initialized = true
		if Config.SkipExistingPlayers and self.DataService:GetValue(player, "JoinedBefore") then
			self:save(player, state, "Finish")
			return
		end
		self:save(player, state, state.Step or "Climb")
	end

	-- Enroll an in-progress profile when analytics is introduced, without replaying
	-- previous steps. Existing funnel flags also survive reconnects.
	if self.TutorialFunnelService:Track(player, state, state.Step) then
		self.DataService:GetValueObject(player, "Tutorial"):Set(state)
	end

	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not root or not humanoid or humanoid.Health <= 0 then
		self.Training[player] = nil
		self.PlatformTime[player] = nil
		self.RouteExitTime[player] = nil
		return
	end
	if character:GetAttribute("GuardStunned") or character:HasTag("Knocked") then
		self.PlatformTime[player] = nil
		self.RouteExitTime[player] = nil
		self.Training[player] = nil
		return
	end

	local step = state.Step
	if step == "HatchReward" then
		if Config.HatchRewardSeconds <= 0 and not self.EggHatchService.PendingHatches[player] then
			self:save(player, state, "Stamina")
			return
		end
		if not state.RewardUntil then
			-- A reconnect may have ended the reveal before its completion callback arrived.
			if not self.EggHatchService.PendingHatches[player] then
				state.RewardUntil = workspace:GetServerTimeNow() + Config.HatchRewardSeconds
				self:save(player, state, "HatchReward")
			end
		elseif workspace:GetServerTimeNow() >= state.RewardUntil then
			self:save(player, state, "Stamina")
		end
		return
	end
	local inventory = self.DataService:GetValue(player, "Inventory")
	local placed = self.DataService:GetValue(player, "PlacedEggs")
	local eggReference = next(placed)
	for reference, item in pairs(inventory) do
		if item.Handler == "Egg" then
			eggReference = eggReference or reference
		end
	end

	-- Recover from dropping/losing an egg or leaving midway through a steal.
	if
		not state.Hatched
		and (step == "Return" or step == "Deposit" or step == "Hatch")
		and not player:GetAttribute("CarryingEgg")
		and not eggReference
	then
		state.Deposited = false
		self:save(player, state, "Climb")
		return
	end
	if not state.Hatched and next(placed) and step ~= "Hatch" then
		state.EggReference = next(placed)
		self:save(player, state, "Hatch")
		return
	end
	if not state.Hatched and eggReference and step ~= "Deposit" and step ~= "Hatch" then
		self:save(player, state, "Deposit")
		return
	end
	if not state.Hatched and player:GetAttribute("CarryingEgg") and step ~= "Return" then
		self:save(player, state, "Return")
		return
	end

	local parts = workspace:FindFirstChild(Config.PartsFolder)
	local climb = parts and parts:FindFirstChild(Config.Parts.Climb, true)
	local climbFrame = Targets.GetCFrame(climb)
	local zone = parts and parts:FindFirstChild(Config.Parts.Zone, true)
	local falling = root.AssemblyLinearVelocity.Y < -Config.FallingSpeed
	local grounded = humanoid.FloorMaterial ~= Enum.Material.Air
	local biome = Location.GetBiome(root.Position)
	local left = parts and parts:FindFirstChild(Config.Parts.Left, true)
	local right = parts and parts:FindFirstChild(Config.Parts.Right, true)
	local nearPlatform = near(root, left, Config.PlatformDistance) or near(root, right, Config.PlatformDistance)

	-- Platform landings are outside the guard Area. Keep that approach valid while
	-- the player walks toward the eggs instead of resetting at the Area boundary.
	if nearPlatform then
		biome = biome or Config.PlatformBiome
	end

	if biome and grounded and not falling then
		self.PlatformTime[player] = (self.PlatformTime[player] or 0) + deltaTime
	else
		self.PlatformTime[player] = nil
	end
	if step == "Climb" or step == "Ascend" or step == "Platform" or step == "Steal" then
		-- Advance in one direction while climbing. Regress only after a confirmed recovery.
		if falling then
			self.RouteExitTime[player] = nil
			return
		end

		-- A grounded landing completes platform guidance immediately; entering the
		-- guard Area is not required. Idle characters also use the Running state.
		if step ~= "Steal" and grounded and nearPlatform then
			local movementState = humanoid:GetState()
			local standing = movementState == Enum.HumanoidStateType.Running
				or movementState == Enum.HumanoidStateType.Landed

			if standing then
				state.Biome = biome
				self:save(player, state, "Steal")
				return
			end

			self.PlatformTime[player] = nil
			return
		end

		if biome then
			self.RouteExitTime[player] = nil
			if (self.PlatformTime[player] or 0) >= Config.PlatformConfirmSeconds then
				if step ~= "Steal" or state.Biome ~= biome then
					state.Biome = biome
					self:save(player, state, "Steal")
				end
			end
			return
		end

		local offset = climbFrame and (root.Position - climbFrame.Position)
		local inColumn = offset and Vector3.new(offset.X, 0, offset.Z).Magnitude <= Config.ClimbColumnRadius
		local resetRoute = grounded
			and (
				step == "Steal"
				or (step == "Ascend" and offset and offset.Y < Config.ClimbHeight)
				or (step == "Platform" and offset and offset.Y < Config.ClimbHeight)
			)
		if resetRoute then
			self.RouteExitTime[player] = (self.RouteExitTime[player] or 0) + deltaTime
			if self.RouteExitTime[player] >= Config.RouteExitConfirmSeconds then
				local nextStep = near(root, zone, Config.ZoneDistance) and "Platform"
					or (offset and offset.Y >= Config.ClimbHeight and inColumn and "Ascend" or "Climb")
				state.Biome = nil
				self:save(player, state, nextStep)
			end
			return
		end
		self.RouteExitTime[player] = nil
		if step == "Climb" or step == "Ascend" then
			if near(root, zone, Config.ZoneDistance) then
				self:save(player, state, "Platform")
			elseif step == "Climb" and offset and offset.Y >= Config.ClimbHeight and inColumn then
				self:save(player, state, "Ascend")
			end
		end
	elseif step == "Stamina" and self.DataService:GetValue(player, "StaminaLevel") >= Config.StaminaTargetLevel then
		self:save(player, state, "CloseStamina")
	elseif
		step == "Treadmill" and self.DataService:GetValue(player, "TreadmillLevel") >= Config.TreadmillTargetLevel
	then
		self:save(player, state, "Train")
	elseif step == "Train" then
		local base = self.BaseService:GetPlayerBase(player)
		local marker = base and base:FindFirstChild("TreadmillCFrame")
		if self.TreadmillService.Connections[player] and near(root, marker, Config.ArrivalDistance) then
			self.Training[player] = (self.Training[player] or 0) + deltaTime
			if self.Training[player] >= Config.TrainingSeconds then
				self:save(player, state, "Finish")
				self.Training[player] = nil
			end
		else
			self.Training[player] = nil
		end
	end
end

-- Public Methods
-- Only trusted gameplay services call this after the real action succeeds.
function TutorialService:Record(player, event: string, reference: string?)
	if not Config.Enabled or not self.DataService:GetProfile(player) then
		return
	end
	local state = self.DataService:GetValue(player, "Tutorial")
	if not state.Initialized or state.Completed then
		return
	end

	if event == "Deposit" and not state.Hatched then
		state.Deposited = true
		state.EggReference = reference
		self:save(player, state, "Hatch")
	elseif event == "Hatch" and not state.Hatched then
		state.Hatched = true
		self:save(player, state, "HatchReward")
	elseif event == "RevealComplete" and state.Step == "HatchReward" then
		state.RewardUntil = workspace:GetServerTimeNow() + Config.HatchRewardSeconds
		self:save(player, state, Config.HatchRewardSeconds > 0 and "HatchReward" or "Stamina")
	end
end

-- LifeCycle
function TutorialService:KnitInit()
	self.TutorialFunnelService = knit.GetService("TutorialFunnelService")
	self.DataService = knit.GetService("DataService")
	self.BaseService = knit.GetService("BaseService")
	self.TreadmillService = knit.GetService("TreadmillService")
	self.EggHatchService = knit.GetService("EggHatchService")
end

function TutorialService:KnitStart()
	local elapsed = 0
	RunService.Heartbeat:Connect(function(deltaTime)
		elapsed += deltaTime
		if elapsed < Config.ServerInterval then
			return
		end
		local interval = elapsed
		elapsed = 0
		if not Config.Enabled then
			return
		end
		for _, player in ipairs(Players:GetPlayers()) do
			self:update(player, math.min(interval, Config.ServerInterval * 2))
		end
	end)
	Players.PlayerRemoving:Connect(function(player)
		self.RouteExitTime[player] = nil
		self.PlatformTime[player] = nil
		self.Training[player] = nil
	end)
end

return TutorialService
