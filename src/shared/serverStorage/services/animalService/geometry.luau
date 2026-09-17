-->
local Geometry = {}

function Geometry.IsFiniteNumber(value: any): boolean
	return typeof(value) == "number" and value == value and math.abs(value) < math.huge
end

function Geometry.IsValidCFrame(value: any): boolean
	if typeof(value) ~= "CFrame" then
		return false
	end

	for _, component in { value:GetComponents() } do
		if not Geometry.IsFiniteNumber(component) then
			return false
		end
	end

	return true
end

-- Rectangular enclosure in the fence model's local axes, inset for fence
-- thickness and the animal's full turning radius (including an offset pivot).
-- Usable area inside the fences for an animal of this radius.
-- minFraction keeps a usable strip in the middle for rigs bigger than the plot, so a huge
-- animal can still be placed (overhanging the fences) instead of being rejected forever.
-- Both the placement check and the walk target use it, so a giant shuffles around that
-- central strip (overhanging the fences) instead of standing frozen.
function Geometry.GetBounds(base: Model?, radius: number, minFraction: number?)
	local fences = base and base:FindFirstChild("Fences")
	if not fences or not fences:IsA("Model") or not fences:FindFirstChildWhichIsA("BasePart", true) then
		return
	end

	local frame, size = fences:GetBoundingBox()
	local halfX = size.X / 2 - 3 - radius
	local halfZ = size.Z / 2 - 3 - radius

	if minFraction then
		halfX = math.max(halfX, size.X * minFraction)
		halfZ = math.max(halfZ, size.Z * minFraction)
	end

	if halfX <= 0 or halfZ <= 0 then
		return
	end

	return frame, halfX, halfZ
end

function Geometry.GetGroundCFrame(point: Vector3, height: number, rotation: CFrame?): CFrame?
	local ground = workspace:FindFirstChild("Ground")
	if not ground then
		return
	end

	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = { ground }
	local hit = workspace:Raycast(Vector3.new(point.X, 10000, point.Z), Vector3.new(0, -20000, 0), params)
	if not hit then
		return
	end

	return CFrame.new(hit.Position + Vector3.new(0, height, 0)) * (rotation or CFrame.identity)
end

function Geometry.GetRigDimensions(asset: Model): (number, number)
	local box, size = asset:GetBoundingBox()
	local pivot = asset:GetPivot()
	local radius, bottom = 0, math.huge

	for _, x in { -1, 1 } do
		for _, y in { -1, 1 } do
			for _, z in { -1, 1 } do
				local corner = pivot:PointToObjectSpace(box:PointToWorldSpace(size * Vector3.new(x, y, z) / 2))
				radius = math.max(radius, Vector2.new(corner.X, corner.Z).Magnitude)
				bottom = math.min(bottom, corner.Y)
			end
		end
	end

	return radius, -bottom
end

function Geometry.GetPlacementPoint(
	frame: CFrame,
	halfX: number,
	halfZ: number,
	requested: CFrame?,
	saved: any
): Vector3?
	if requested then
		local point = frame:PointToObjectSpace(requested.Position)
		if math.abs(point.X) > halfX or math.abs(point.Z) > halfZ then
			return
		end

		return point
	end

	if typeof(saved) == "table" and Geometry.IsFiniteNumber(saved.X) and Geometry.IsFiniteNumber(saved.Z) then
		return Vector3.new(math.clamp(saved.X, -halfX, halfX), 0, math.clamp(saved.Z, -halfZ, halfZ))
	end

	return Vector3.zero
end

function Geometry.GetRandomPoint(frame: CFrame, halfX: number, halfZ: number, random: Random): Vector3
	local point = Vector3.new(random:NextNumber(-halfX, halfX), 0, random:NextNumber(-halfZ, halfZ))

	return frame:PointToWorldSpace(point)
end

function Geometry.GetFacingCFrame(cFrame: CFrame, targetPosition: Vector3): CFrame
	local direction = Vector3.new(targetPosition.X - cFrame.X, 0, targetPosition.Z - cFrame.Z)
	if direction.Magnitude < 0.001 then
		return cFrame
	end

	return CFrame.lookAt(cFrame.Position, cFrame.Position + direction)
end

function Geometry.GetMovement(start: CFrame, target: CFrame, speed: number): (CFrame?, number?)
	local delta = target.Position - start.Position
	local horizontal = Vector3.new(delta.X, 0, delta.Z)
	if horizontal.Magnitude < 0.5 then
		return
	end

	local destination = CFrame.lookAt(target.Position, target.Position + horizontal)
	local duration = delta.Magnitude / math.max(1, speed)

	return destination, duration
end

return Geometry
