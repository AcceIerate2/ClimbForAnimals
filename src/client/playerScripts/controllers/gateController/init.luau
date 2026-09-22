-- Roblox Services
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

-- Packages
local knit = require(ReplicatedStorage.src.Packages.knit)

-- Constants
local Player = Players.LocalPlayer
local Bases = workspace:WaitForChild("Structures"):WaitForChild("Bases")
local OpenDistance = 5
local OpenAngle = 90
local SwingSpeed = math.deg(6) -- degrees per second, the old hinge's AngularSpeed of 6 rad/s

-- Helper Functions
-- The doors are anchored on the server and swung here by CFrame, so each player only ever sees
-- the gates they open themselves; a physics hinge would replicate from whoever owned the door.
local function newDoor(side: Instance)
	local hinge = side:WaitForChild("Anchor"):WaitForChild("HingeConstraint") :: HingeConstraint
	hinge.Enabled = false
	local pivot = (side:WaitForChild("Anchor"):WaitForChild("Attachment0") :: Attachment).WorldCFrame

	local parts = {}
	local door = side:WaitForChild("Gate") :: BasePart
	door.Anchored = true
	door.CanCollide = false
	table.insert(parts, door)
	for _, part in ipairs(side:WaitForChild("Deco"):GetDescendants()) do
		if part:IsA("BasePart") then
			part.Anchored = true
			part.CanCollide = false
			table.insert(parts, part)
		end
	end

	local offsets = {}
	for index, part in ipairs(parts) do
		offsets[index] = pivot:ToObjectSpace(part.CFrame)
	end

	return {
		Pivot = pivot,
		Axis = pivot.XVector,
		Parts = parts,
		Offsets = offsets,
		Angle = 0,
		Target = 0,
	}
end

local function applyDoor(door, angle: number)
	local rotated = CFrame.new(door.Pivot.Position)
		* CFrame.fromAxisAngle(door.Axis, math.rad(angle))
		* door.Pivot.Rotation
	local cframes = table.create(#door.Parts)
	for index in ipairs(door.Parts) do
		cframes[index] = rotated * door.Offsets[index]
	end
	workspace:BulkMoveTo(door.Parts, cframes, Enum.BulkMoveMode.FireCFrameChanged)
end

-->
local GateController = knit.CreateController({ Name = "GateController", Gates = {} })

-- LifeCycle
function GateController:KnitStart()
	for _, base in ipairs(Bases:GetChildren()) do
		local gate = base:WaitForChild("Gate")
		table.insert(self.Gates, {
			Model = gate,
			Left = newDoor(gate:WaitForChild("Left")),
			Right = newDoor(gate:WaitForChild("Right")),
			Closed = true,
		})
	end

	RunService.RenderStepped:Connect(function(deltaTime: number)
		local character = Player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")

		for _, gate in ipairs(self.Gates) do
			local gateCFrame = gate.Model:GetPivot()
			if root then
				local offset = root.Position - gateCFrame.Position
				local shouldOpen = Vector3.new(offset.X, 0, offset.Z).Magnitude < OpenDistance
				if shouldOpen and gate.Closed then
					-- Swing away from the side the player walks in from, as the hinge did.
					local side = gateCFrame:VectorToObjectSpace(offset).Z > 0
					gate.Left.Target = side and -OpenAngle or OpenAngle
					gate.Right.Target = side and OpenAngle or -OpenAngle
					gate.Closed = false
				elseif not shouldOpen and not gate.Closed then
					gate.Left.Target = 0
					gate.Right.Target = 0
					gate.Closed = true
				end
			end

			for _, door in ipairs({ gate.Left, gate.Right }) do
				if door.Angle ~= door.Target then
					local step = SwingSpeed * deltaTime
					door.Angle = door.Angle + math.clamp(door.Target - door.Angle, -step, step)
					applyDoor(door, door.Angle)
				end
			end
		end
	end)
end

return GateController
