local Geometry = {}

-- Return a pivot-relative box so capture checks do not depend on weld simulation.
function Geometry.GetHitboxBounds(model: Model, minimumSize: Vector3): (CFrame, Vector3)
	local pivot = model:GetPivot()
	local authored = model:FindFirstChild("Hitbox", true)
	if authored and authored:IsA("BasePart") then
		return pivot:ToObjectSpace(authored.CFrame), authored.Size
	end

	local minimum = Vector3.new(math.huge, math.huge, math.huge)
	local maximum = -minimum
	local found = false

	for _, part in ipairs(model:GetDescendants()) do
		if part:IsA("BasePart") and part.Transparency < 1 and part.Name ~= "PatrolZone" then
			found = true
			for _, x in ipairs({ -1, 1 }) do
				for _, y in ipairs({ -1, 1 }) do
					for _, z in ipairs({ -1, 1 }) do
						local corner = pivot:PointToObjectSpace(
							part.CFrame:PointToWorldSpace(part.Size * Vector3.new(x, y, z) / 2)
						)
						minimum = minimum:Min(corner)
						maximum = maximum:Max(corner)
					end
				end
			end
		end
	end

	if not found then
		return CFrame.identity, minimumSize
	end

	return CFrame.new((minimum + maximum) / 2), (maximum - minimum):Max(minimumSize)
end

function Geometry.IsFiniteVector(value): boolean
	return typeof(value) == "Vector3"
		and value.X == value.X
		and value.Y == value.Y
		and value.Z == value.Z
		and math.abs(value.X) < 1e7
		and math.abs(value.Y) < 1e7
		and math.abs(value.Z) < 1e7
end

function Geometry.Contains(area: BasePart, position: Vector3, height: number, padding: number?): boolean
	local point = area.CFrame:PointToObjectSpace(position)
	local half = area.Size / 2
	local margin = padding or 0

	return math.abs(point.X) <= half.X + margin
		and math.abs(point.Z) <= half.Z + margin
		and point.Y >= -half.Y - margin
		and point.Y <= half.Y + height + margin
end

function Geometry.Clamp(area: BasePart, position: Vector3, radius: number, pivotHeight: number): Vector3
	local point = area.CFrame:PointToObjectSpace(position)
	local halfX = math.max(0, area.Size.X / 2 - radius)
	local halfZ = math.max(0, area.Size.Z / 2 - radius)

	return area.CFrame:PointToWorldSpace(
		Vector3.new(
			math.clamp(point.X, -halfX, halfX),
			area.Size.Y / 2 + pivotHeight,
			math.clamp(point.Z, -halfZ, halfZ)
		)
	)
end

function Geometry.GetPatrolArea(island: Instance, template: Model): BasePart?
	local reference = template:FindFirstChild("PatrolZone")
	if reference and reference:IsA("ObjectValue") then
		reference = reference.Value
	end

	local area = reference
		or template.Parent:FindFirstChild("PatrolZone")
		or island:FindFirstChild("PatrolZone")
		or island:FindFirstChild("Area")

	return area and area:IsA("BasePart") and area or nil
end

function Geometry.GetRigBounds(model: Model): (number, number, number)
	local pivot = model:GetPivot()
	local radius, bottom, top = 0, math.huge, -math.huge
	local function include(bounds: CFrame, size: Vector3)
		for _, x in ipairs({ -1, 1 }) do
			for _, y in ipairs({ -1, 1 }) do
				for _, z in ipairs({ -1, 1 }) do
					local corner = bounds:PointToWorldSpace(size * Vector3.new(x, y, z) / 2) - pivot.Position
					radius = math.max(radius, Vector2.new(corner.X, corner.Z).Magnitude)
					bottom = math.min(bottom, corner.Y)
					top = math.max(top, corner.Y)
				end
			end
		end
	end

	for _, part in ipairs(model:GetDescendants()) do
		if part:IsA("BasePart") and part.Name ~= "Hitbox" and part.Name ~= "PatrolZone" and part.Transparency < 1 then
			include(part.CFrame, part.Size)
		end
	end

	if bottom == math.huge then
		include(model:GetBoundingBox())
	end

	return radius, -bottom, top
end

return Geometry
