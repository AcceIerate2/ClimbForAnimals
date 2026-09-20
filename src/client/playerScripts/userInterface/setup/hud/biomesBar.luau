-- Roblox Services
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

-- Packages
local knit = require(ReplicatedStorage.src.Packages.knit)

-- Utility Modules
local AvatarHeadshot = require(ReplicatedStorage.src.utility.AvatarHeadshot)
local PlayTween = require(ReplicatedStorage.src.utility.PlayTween)
local WaitForUiDesc = require(ReplicatedStorage.src.utility.WaitForUiDesc)

-- Config Modules
local zoneConfig = require(ReplicatedStorage.src.GameConfiguration.Gameplay.zoneConfig)

-- Constants
local LocalPlayer = Players.LocalPlayer
local _TweenInfo = TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local HiddenOffset = UDim2.fromScale(1, 0)
local ZIndexes = {
	LocalPlayer = 3,
	Others = 2,
}

-- Helper Functions
local function getDefaultPosition(frame: GuiObject): UDim2
	local attr = frame:GetAttribute("DefaultPosition")
	if typeof(attr) == "UDim2" then
		return attr
	end

	local position = frame.Position
	frame:SetAttribute("DefaultPosition", position)
	return position
end

-->
local BiomesBar = {
	Entries = {}, -- [Player]: Frame
	Segments = {},
	ActiveTweens = {},
	IsOpen = false,
}

-- Private Methods
function BiomesBar:toggleFrame(frame: GuiObject, visible: boolean)
	local defaultPosition = getDefaultPosition(frame)

	if self.ActiveTweens[frame] then
		self.ActiveTweens[frame]:Cancel()
		self.ActiveTweens[frame] = nil
	end

	frame.Visible = true

	local tween
	tween = PlayTween(frame, _TweenInfo, {
		Position = visible and defaultPosition or defaultPosition + HiddenOffset,
	}, function()
		if self.ActiveTweens[frame] ~= tween then
			return
		end

		self.ActiveTweens[frame] = nil
		frame.Visible = visible
	end)
	self.ActiveTweens[frame] = tween
end

function BiomesBar:toggleBar(open: boolean)
	if self.IsOpen == open then
		return
	end

	self.IsOpen = open
	self.HudController:SetHeightBarVisible(open)
	if open then
		self.EggController:SetVisible(false)
		knit.GetController("AnimalLoadoutController"):SetVisible(false)
	end

	self:toggleFrame(self.Container, open)
end

function BiomesBar:buildSegments()
	local zones = {}
	for zoneName: string, config: { Height: number } in pairs(zoneConfig) do
		local zoneFrame = self.Container:FindFirstChild(zoneName)
		if not zoneFrame then
			continue
		end

		table.insert(zones, {
			Frame = zoneFrame,
			Height = config.Height,
		})
	end

	table.sort(zones, function(a, b)
		return a.Height < b.Height
	end)

	-- Each biome frame covers its own zone: from its height up to the next zone's height
	-- The bar is rotated: each frame goes from its bottom edge (X + Width) to its top edge (X)
	local climbStartHeight = self.ZoneController:GetClimbStartHeight()
	for index, zone in ipairs(zones) do
		local nextZone = zones[index + 1]
		table.insert(self.Segments, {
			LowerHeight = math.max(zone.Height, climbStartHeight),
			UpperHeight = nextZone and nextZone.Height or zone.Height,
			BottomX = zone.Frame.Position.X.Scale + zone.Frame.Size.X.Scale,
			TopX = zone.Frame.Position.X.Scale,
		})
	end
end

function BiomesBar:getBarPosition(height: number): number
	for _, segment in ipairs(self.Segments) do
		if height <= segment.UpperHeight then
			local range = segment.UpperHeight - segment.LowerHeight
			if range <= 0 then
				return segment.TopX
			end

			local alpha = math.clamp((height - segment.LowerHeight) / range, 0, 1)
			return segment.BottomX + (segment.TopX - segment.BottomX) * alpha
		end
	end

	return self.Segments[#self.Segments].TopX
end

function BiomesBar:getClimbHeight(player: Player): number?
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local rootPart = humanoid and humanoid.RootPart
	if not rootPart or humanoid.Health <= 0 then
		return nil
	end

	local position = rootPart.Position
	if not self.ZoneController:IsInClimbZone(position) then
		return nil
	end

	return position.Y
end

function BiomesBar:addPlayer(player: Player)
	if self.Entries[player] then
		return
	end

	local isLocalPlayer = player == LocalPlayer
	local playerFrame = self.Template:Clone()
	playerFrame.Name = tostring(player.UserId)
	playerFrame.Visible = false
	playerFrame.ZIndex = isLocalPlayer and ZIndexes.LocalPlayer or ZIndexes.Others
	playerFrame.You.Visible = isLocalPlayer
	playerFrame.PlayerIcon.Image = ""
	playerFrame.Parent = self.Container
	self.Entries[player] = playerFrame

	task.spawn(function()
		local image = AvatarHeadshot(player.UserId)
		if self.Entries[player] ~= playerFrame then
			return
		end
		playerFrame.PlayerIcon.Image = image or ""
	end)
end

function BiomesBar:removePlayer(player: Player)
	local playerFrame = self.Entries[player]
	if not playerFrame then
		return
	end

	self.Entries[player] = nil
	playerFrame:Destroy()
end

function BiomesBar:update()
	local templateY = self.Template.Position.Y

	for player: Player, playerFrame: Frame in pairs(self.Entries) do
		local height = self:getClimbHeight(player)
		local inClimbZone = height ~= nil

		playerFrame.Visible = inClimbZone
		if inClimbZone then
			playerFrame.Position = UDim2.new(self:getBarPosition(height), 0, templateY.Scale, templateY.Offset)
		end

		if player == LocalPlayer then
			self:toggleBar(inClimbZone)
		end
	end
end

-- LifeCycle
function BiomesBar:Init(player: Player)
	local rightMain = WaitForUiDesc(player.PlayerGui:WaitForChild("Hud"), "Frame", {
		Name = "RightMain",
	})

	self.Container = rightMain:WaitForChild("BiomesBar")
	self.Template = self.Container:WaitForChild("Player")
	self.Template.Parent = nil

	-- Starts closed
	self.Container.Position = getDefaultPosition(self.Container) + HiddenOffset
	self.Container.Visible = false

	self.ZoneController = knit.GetController("ZoneController")
	self.HudController = knit.GetController("HudController")
	self.EggController = knit.GetController("EggController")
	self:buildSegments()

	for _, otherPlayer: Player in ipairs(Players:GetPlayers()) do
		self:addPlayer(otherPlayer)
	end

	Players.PlayerAdded:Connect(function(otherPlayer: Player)
		self:addPlayer(otherPlayer)
	end)

	Players.PlayerRemoving:Connect(function(otherPlayer: Player)
		self:removePlayer(otherPlayer)
	end)

	RunService.RenderStepped:Connect(function()
		self:update()
	end)
end

return BiomesBar
