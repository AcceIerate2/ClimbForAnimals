-- Roblox Services
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Packages
local knit = require(ReplicatedStorage.src.Packages.knit)

-- Utility Modules
local DayCycle = require(ReplicatedStorage.src.utility.dayCycle)
local Zones = require(ReplicatedStorage.src.utility.zones)
local PlayTween = require(ReplicatedStorage.src.utility.PlayTween)

-- Config Modules
local dayCycleConfig = require(ReplicatedStorage.src.GameConfiguration.Gameplay.dayCycleConfig)

-- Constants
local TimeCycleAssets = ReplicatedStorage:WaitForChild("Assets"):WaitForChild("TimeCycle")
local NightWall = TimeCycleAssets:WaitForChild("NightWall")
local TpLobby = TimeCycleAssets:WaitForChild("TpLobby") :: BasePart
local Wall = NightWall:WaitForChild("Wall") :: BasePart
local WallHome = NightWall.Parent
local DropMargin = 5 -- the drop ends this far under the floor, never flush with it
local WallClearance = 4 -- studs of character kept out of the wall's volume
local LobbyDropOffset = CFrame.new(0, 5, 0) -- clearance above the TpLobby pad, as the plot teleport uses
local FadeTweenInfo = TweenInfo.new(dayCycleConfig.WallFadeDuration, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local DropTweenInfo = TweenInfo.new(dayCycleConfig.WallDropDuration, Enum.EasingStyle.Quad, Enum.EasingDirection.In)

-->
local DayCycleService = knit.CreateService({
	Name = "DayCycleService",
	Client = {
		CaughtAtNight = knit.CreateSignal(), -- (droppedEgg: boolean)
	},
	IsNight = false,
	WallGeneration = 0,
})

-- Private Methods
-- The wall is a real barrier, so the server owns where it is, whether it collides and whether it
-- is in the world at all. Only the presentation on it is the client's.
function DayCycleService:stopWallTween()
	if self.WallTween then
		self.WallTween:Cancel()
		self.WallTween = nil
	end

	self.WallGeneration += 1
end

-- Only the parent changes here. Restoring the wall's position in the same frame it leaves the
-- world raced with replication: parent and properties travel in one batch, so the client could
-- apply the raised CFrame before removing the part and flash a whole wall for a frame. raiseWall
-- sets all three properties anyway, so there is nothing to restore.
function DayCycleService:storeWall()
	NightWall.Parent = WallHome
end

-- The wall must never turn solid in the same replication batch as a teleport out of it: parent
-- and properties travel together, so the client can apply the collision first, fling the
-- character and only then place it. The fade is the grace window, and whoever walked in while it
-- was still passable is evicted with another window to spare before it hardens.
function DayCycleService:solidifyWall(generation: number)
	if self.WallGeneration ~= generation then
		return
	end

	if not self:evictFromWall() then
		Wall.CanCollide = true
		return
	end

	task.delay(dayCycleConfig.WallSolidGraceSeconds, function()
		if self.WallGeneration == generation then
			Wall.CanCollide = true
		end
	end)
end

function DayCycleService:raiseWall()
	self:stopWallTween()

	Wall.CFrame = self.RaisedCFrame
	Wall.Transparency = 1
	Wall.CanCollide = false
	NightWall.Parent = workspace

	local generation = self.WallGeneration
	self.WallTween = PlayTween(Wall, FadeTweenInfo, { Transparency = 0 }, function()
		self:solidifyWall(generation)
	end)
end

function DayCycleService:dropWall()
	self:stopWallTween()
	Wall.CanCollide = false

	local generation = self.WallGeneration
	self.WallTween = PlayTween(Wall, DropTweenInfo, { CFrame = self.LoweredCFrame }, function()
		if self.WallGeneration == generation then
			self:storeWall()
		end
	end)
end

-- The wall is 16 studs thick and lands on the climb entrance, so somebody standing there when it
-- becomes solid would be trapped inside it.
function DayCycleService:isInsideWall(position: Vector3): boolean
	local localPosition = self.RaisedCFrame:PointToObjectSpace(position)
	local halfSize = Wall.Size / 2 + Vector3.one * WallClearance
	return math.abs(localPosition.X) <= halfSize.X
		and math.abs(localPosition.Y) <= halfSize.Y
		and math.abs(localPosition.Z) <= halfSize.Z
end

-- Everybody the night sends back lands on the TpLobby pad, facing wherever it is rotated.
function DayCycleService:teleportToLobby(player: Player)
	self.BaseService:TeleportCharacter(player, TpLobby.CFrame * LobbyDropOffset)
end

-- Being in the wall's way is not getting caught: the player only moves out of it, egg included.
function DayCycleService:evictFromWall(): boolean
	local evicted = false

	for _, player in ipairs(Players:GetPlayers()) do
		local character = player.Character
		local rootPart = character and character:FindFirstChild("HumanoidRootPart")
		if rootPart and self:isInsideWall(rootPart.Position) then
			self:teleportToLobby(player)
			evicted = true
		end
	end

	return evicted
end

-- Night falls everywhere at once, so anybody still above the lobby is caught. The egg goes back
-- to its nest first, while the carry welds still exist, and only then the player is moved.
function DayCycleService:catchPlayers()
	for _, player in ipairs(Players:GetPlayers()) do
		local character = player.Character
		local rootPart = character and character:FindFirstChild("HumanoidRootPart")
		if rootPart and Zones.IsInClimbZone(rootPart.Position) then
			local droppedEgg = self.EggSpawnService:ReturnCarriedEgg(player, true)
			self:teleportToLobby(player)
			self.Client.CaughtAtNight:Fire(player, droppedEgg)
		end
	end

	self:evictFromWall()
end

function DayCycleService:setNight(isNight: boolean)
	if self.IsNight == isNight then
		return
	end

	self.IsNight = isNight

	if isNight then
		self:catchPlayers()
		self:raiseWall()
	else
		self:dropWall()
	end
end

function DayCycleService:restock(period: number?)
	self.RestockedPeriod = period
	self.EggSpawnService:Restock()
end

-- LifeCycle
function DayCycleService:KnitInit()
	self.EggSpawnService = knit.GetService("EggSpawnService")
	self.BaseService = knit.GetService("BaseService")
	self.RaisedCFrame = Wall.CFrame
	self.LoweredCFrame = Wall.CFrame - Vector3.new(0, Wall.Size.Y + DropMargin, 0)
end

function DayCycleService:KnitStart()
	local now = workspace:GetServerTimeNow()

	self.IsNight = DayCycle.IsNight(now)
	if self.IsNight then
		self:raiseWall()
	else
		self:storeWall()
	end

	self:restock(DayCycle.IsRestockWindow(now) and DayCycle.GetPeriodIndex(now) or nil)

	task.spawn(function()
		while true do
			local currentTime = workspace:GetServerTimeNow()
			self:setNight(DayCycle.IsNight(currentTime))

			local period = DayCycle.GetPeriodIndex(currentTime)
			if DayCycle.IsRestockWindow(currentTime) and self.RestockedPeriod ~= period then
				self:restock(period)
			end

			local remaining = DayCycle.GetNextBoundaryAt(currentTime) - workspace:GetServerTimeNow()
			task.wait(math.clamp(remaining, 0.05, dayCycleConfig.PollInterval))
		end
	end)
end

return DayCycleService
