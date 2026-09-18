-- Roblox Services
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Utility Modules
local Geometry = require(ReplicatedStorage.src.utility.guardGeometry)

-- Config Modules
local Config = require(ReplicatedStorage.src.GameConfiguration.Gameplay.guardConfig)

-- Helper Functions
local function loadAnimations(model: Model)
	local controller = model:FindFirstChildOfClass("AnimationController") or model:FindFirstChildOfClass("Humanoid")
	if not controller then
		controller = Instance.new("AnimationController")
		controller.Parent = model
	end

	local animator = controller:FindFirstChildOfClass("Animator") or Instance.new("Animator")
	animator.Parent = controller
	local tracks = {}
	for _, name in ipairs({ "Walk", "Idle" }) do
		local animation = model:FindFirstChild(name, true)
		if animation and animation:IsA("Animation") and animation.AnimationId ~= "" then
			local success, track = pcall(function()
				return animator:LoadAnimation(animation)
			end)

			if success then
				track.Looped = true
				track.Priority = name == "Walk" and Enum.AnimationPriority.Movement or Enum.AnimationPriority.Idle
				tracks[name] = track
			else
				warn(track)
			end
		end
	end

	return tracks
end

local function createAlert(model: Model, root: BasePart, top: number, alertTemplate: Instance)
	local alert = alertTemplate:Clone()
	local alertAttachment = alert:IsA("Attachment") and alert or Instance.new("Attachment")
	alertAttachment.Name = "GuardAlertAttachment"
	alertAttachment.CFrame = CFrame.new(
		root.CFrame:PointToObjectSpace(model:GetPivot().Position + Vector3.new(0, top + Config.AlertHeightOffset, 0))
	)
	alertAttachment.Parent = root
	if alert ~= alertAttachment then
		alert.Parent = alertAttachment
	end

	local function setupGui(gui)
		gui.Adornee = alertAttachment
		gui.StudsOffset = Vector3.zero
		gui.StudsOffsetWorldSpace = Vector3.zero
		gui.ExtentsOffset = Vector3.zero
		gui.ExtentsOffsetWorldSpace = Vector3.zero
	end

	for _, gui in ipairs(alert:GetDescendants()) do
		if gui:IsA("BillboardGui") then
			setupGui(gui)
		end
	end

	if alert:IsA("BillboardGui") then
		setupGui(alert)
	end

	return alert
end

-->
local Rig = {}

-- Public Methods
function Rig.Stop(data)
	if data.Tween then
		data.Tween:Cancel()
		data.Tween:Destroy()
		data.Tween = nil
	end

	data.FacingPosition = nil
end

function Rig.Animate(data, mode: string)
	if data.Animation == mode then
		return
	end

	data.Animation = mode
	for name, track in pairs(data.Tracks) do
		if name == mode then
			track:Play(0.15)
		else
			track:Stop(0.15)
		end
	end
end

function Rig.Move(data, destination: Vector3, duration: number)
	Rig.Stop(data)
	local current = data.Model:GetPivot()
	local direction = Vector3.new(destination.X - current.X, 0, destination.Z - current.Z)
	data.FacingPosition = destination

	data.Pose.Value = current.Position
	data.Tween = TweenService:Create(
		data.Pose,
		TweenInfo.new(math.max(duration, 0.05), Enum.EasingStyle.Linear),
		{ Value = destination }
	)
	data.Tween:Play()
	Rig.Animate(data, direction.Magnitude > 0.05 and "Walk" or "Idle")
end

function Rig.Update(data, deltaTime: number, chaseTarget: BasePart?)
	local position = data.Pose.Value
	local target = data.State == "Chase" and chaseTarget and chaseTarget.Position or data.FacingPosition

	if target then
		local direction = Vector3.new(target.X - position.X, 0, target.Z - position.Z)
		if direction.Magnitude > 0.01 then
			local rotation = CFrame.lookAt(position, position + direction).Rotation
			local alpha = 1 - math.exp(-Config.TurnSpeed * deltaTime)
			data.Rotation = data.Rotation:Lerp(rotation, alpha)
		end
	end

	data.Model:PivotTo(CFrame.new(position) * data.Rotation)
end

function Rig.Alert(data, visible: boolean)
	if visible and not data.Highlight then
		local highlight = Instance.new("Highlight")
		highlight.Name = "GuardHighlight"
		highlight.Adornee = data.Model
		highlight.FillColor = Color3.fromRGB(255, 0, 0)
		highlight.OutlineColor = Color3.fromRGB(255, 0, 0)
		highlight.FillTransparency = 0.5
		highlight.OutlineTransparency = 0
		highlight.Parent = data.Model
		data.Highlight = highlight
	elseif not visible and data.Highlight then
		data.Highlight:Destroy()
		data.Highlight = nil
	end

	for _, gui in ipairs(data.Alert:GetDescendants()) do
		if gui:IsA("BillboardGui") then
			gui.Enabled = visible
		end
	end

	if data.Alert:IsA("BillboardGui") then
		data.Alert.Enabled = visible
	end
end

function Rig.Create(template: Model, area: BasePart, parent: Instance, alertTemplate: Instance)
	local model = template:Clone()
	for _, object in ipairs(model:GetDescendants()) do
		if object:IsA("BaseScript") or object:IsA("ProximityPrompt") or object.Name == "PatrolZone" then
			object:Destroy()
		end
	end

	local root = model.PrimaryPart
		or model:FindFirstChild("HumanoidRootPart", true)
		or model:FindFirstChildWhichIsA("BasePart", true)
	if not root then
		model:Destroy()

		return nil
	end

	model.PrimaryPart = root
	local radius, pivotHeight, top = Geometry.GetRigBounds(model)
	local hitboxOffset, hitboxSize = Geometry.GetHitboxBounds(model, Config.FallbackHitboxSize)
	local hitbox = model:FindFirstChild("Hitbox", true)
	if hitbox and not hitbox:IsA("BasePart") then
		hitbox = nil
	end

	if not hitbox then
		hitbox = Instance.new("Part")
		hitbox.Name = "Hitbox"
		hitbox.Size = hitboxSize
		hitbox.CFrame = model:GetPivot() * hitboxOffset
		hitbox.Parent = model
	end

	if radius * 2 > math.min(area.Size.X, area.Size.Z) then
		warn(`Guard {template:GetFullName()} is too large for its PatrolZone`)
		model:Destroy()

		return nil
	end

	local weld = Instance.new("WeldConstraint")
	weld.Part0, weld.Part1 = root, hitbox
	if root ~= hitbox then
		weld.Parent = hitbox
	else
		weld:Destroy()
	end

	for _, part in ipairs(model:GetDescendants()) do
		if part:IsA("BasePart") then
			part.Anchored = part == root
			part.CanCollide = false
			part.CanTouch = false
			part.CanQuery = false
			part.Massless = true
		end
	end

	hitbox.Transparency = 1
	local position = Geometry.Clamp(area, model:GetPivot().Position, radius, pivotHeight)
	model:PivotTo(CFrame.new(position) * model:GetPivot().Rotation)
	model.Parent = parent

	local tracks = loadAnimations(model)
	local alert = createAlert(model, root, top, alertTemplate)

	local pose = Instance.new("Vector3Value")
	pose.Value = model:GetPivot().Position

	local data = {
		Model = model,
		Root = root,
		Hitbox = hitbox,
		Area = area,
		Radius = radius,
		PivotHeight = pivotHeight,
		Tracks = tracks,
		Pose = pose,
		Rotation = model:GetPivot().Rotation,
		Alert = alert,
		State = "Idle",
		NextAction = 0,
		NextRepath = 0,
	}

	Rig.Alert(data, false)
	Rig.Animate(data, "Idle")

	return data
end

function Rig.Destroy(data)
	Rig.Stop(data)
	for _, track in pairs(data.Tracks) do
		track:Stop()
		track:Destroy()
	end

	data.Pose:Destroy()
	data.Model:Destroy()
end

return Rig
