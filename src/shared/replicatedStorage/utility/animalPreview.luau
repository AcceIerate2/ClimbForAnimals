-- Animal in a ViewportFrame with its Idle animation, framed from its resting bounds. Shared by the Index and Daily Rewards panels.
-- Roblox Services
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Utility Modules
local EggHandler = require(ReplicatedStorage.src.utility.eggHandler)
local ViewportHandler = require(ReplicatedStorage.src.utility.viewportHandler)

-- Constants
local CardPadding = 1.12 -- Space for idle motion around the visible model.
local DetailPadding = 1.08
local PreviewYaw = 155 -- Slightly off-center to show the front and side.

local Preview = {}

-- Cache the resting visible bounds so idle motion never makes the camera wobble.
local function setupFraming(handle, padding: number)
	local model = handle.Clone
	local minimum, maximum = EggHandler.GetVisibleBounds(model, CFrame.identity)
	if minimum.X == math.huge or maximum.X == -math.huge then
		return
	end

	local center = (minimum + maximum) / 2
	model:PivotTo(CFrame.new(-center) * model:GetPivot())
	minimum -= center
	maximum -= center

	local yaw = math.rad(PreviewYaw)
	local direction = Vector3.new(math.sin(yaw), 0, math.cos(yaw))
	local rotation = CFrame.Angles(0, yaw, 0)
	local corners = {}
	for _, x in ipairs({ minimum.X, maximum.X }) do
		for _, y in ipairs({ minimum.Y, maximum.Y }) do
			for _, z in ipairs({ minimum.Z, maximum.Z }) do
				table.insert(corners, rotation:PointToObjectSpace(Vector3.new(x, y, z)))
			end
		end
	end

	function handle:Refit()
		local size = self.Viewport.AbsoluteSize
		if not self.Clone or size.X <= 0 or size.Y <= 0 then
			return
		end
		local tanY = math.tan(math.rad(self.Camera.FieldOfView) / 2)
		local tanX = tanY * size.X / size.Y
		local distance = 0.05
		for _, corner in ipairs(corners) do
			distance = math.max(
				distance,
				corner.Z + math.abs(corner.X) * padding / tanX,
				corner.Z + math.abs(corner.Y) * padding / tanY
			)
		end
		self.Camera.CFrame = CFrame.new(direction * distance) * rotation
	end
	handle:Refit()
end

local function addIdle(handle, name: string)
	local model = handle.Clone
	local animation = model and model:FindFirstChild("Idle")
	if
		not model
		or not model:IsA("Model")
		or not animation
		or not animation:IsA("Animation")
		or animation.AnimationId == ""
	then
		return
	end

	local world = Instance.new("WorldModel")
	world.Name = "AnimatedPreview"
	world.Parent = handle.Viewport
	model.Parent = world

	local root = model.PrimaryPart or model:FindFirstChildWhichIsA("BasePart", true)
	for _, part in ipairs(model:GetDescendants()) do
		if part:IsA("BasePart") then
			part.Anchored = part == root
			part.CanCollide = false
			part.CanTouch = false
			part.CanQuery = false
		end
	end

	local controller = model:FindFirstChildWhichIsA("AnimationController", true)
	if not controller then
		controller = Instance.new("AnimationController")
		controller.Parent = model
	end
	local animator = controller:FindFirstChildOfClass("Animator")
	if not animator then
		animator = Instance.new("Animator")
		animator.Parent = controller
	end

	local success, track = pcall(function()
		return animator:LoadAnimation(animation)
	end)
	if success then
		track.Looped = true
		track.Priority = Enum.AnimationPriority.Idle
		handle.IdleTrack = track
	else
		warn(`Couldn't load {name} index idle animation: {track}`)
	end

	local destroy = handle.Destroy
	function handle:Destroy()
		if self.IdleTrack then
			self.IdleTrack:Stop(0)
			self.IdleTrack:Destroy()
			self.IdleTrack = nil
		end
		destroy(self)
		world:Destroy()
	end
end

function Preview.SetActive(handle, active: boolean)
	local track = handle and handle.IdleTrack
	if not track then
		return
	end
	if active and not track.IsPlaying then
		track:Play(0.15)
	elseif not active and track.IsPlaying then
		track:Stop(0)
	end
end

-- padding overrides the card/detail framing (bigger = smaller animal in the frame).
function Preview.Create(viewport: ViewportFrame, name: string, animateIdle: boolean?, detailed: boolean?, padding: number?)
	padding = padding or (detailed and DetailPadding or CardPadding)
	viewport.Ambient = Color3.fromRGB(255, 255, 255)
	viewport.LightColor = Color3.fromRGB(255, 255, 255)

	local asset = EggHandler.GetAnimalTemplate(name, "Normal")
	if not asset then
		return nil
	end
	viewport.BackgroundTransparency = 1
	local handle = ViewportHandler.Setup(viewport, asset, {
		Padding = padding,
		NormalizeRotation = true,
		Yaw = PreviewYaw,
		Pitch = 0,
		ClearOnSetup = false,
	})
	setupFraming(handle, padding)
	if animateIdle then
		addIdle(handle, name)
	end
	return handle
end

function Preview.SetDiscovered(viewport: ViewportFrame, discovered: boolean)
	viewport.ImageColor3 = discovered and Color3.new(1, 1, 1) or Color3.new(0, 0, 0)
end

return Preview
