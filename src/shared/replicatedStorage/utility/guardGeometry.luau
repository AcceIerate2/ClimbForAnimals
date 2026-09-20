-- Roblox Services
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Config Modules
local eggConfig = require(ReplicatedStorage.src.GameConfiguration.Gameplay.eggConfig)

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

-- Horizontal containment comes from `area`, inset by the guard's radius so its body stays inside.
-- The height comes from the top of `groundArea` when one is given: a patrol area can be a thin
-- marker part floating above the floor (SpawnEggs sits ~1 stud above it), and taking the height
-- from it would leave the guard walking in the air.
function Geometry.Clamp(
	area: BasePart,
	position: Vector3,
	radius: number,
	pivotHeight: number,
	groundArea: BasePart?
): Vector3
	local point = area.CFrame:PointToObjectSpace(position)
	local halfX = math.max(0, area.Size.X / 2 - radius)
	local halfZ = math.max(0, area.Size.Z / 2 - radius)
	local horizontal = area.CFrame:PointToWorldSpace(
		Vector3.new(math.clamp(point.X, -halfX, halfX), 0, math.clamp(point.Z, -halfZ, halfZ))
	)
	local ground = groundArea or area

	return Vector3.new(horizontal.X, ground.Position.Y + ground.Size.Y / 2 + pivotHeight, horizontal.Z)
end

function Geometry.GetPatrolArea(island: Instance, template: Model): BasePart?
	local reference = template:FindFirstChild("PatrolZone")
	if reference and reference:IsA("ObjectValue") then
		reference = reference.Value
	end

	-- An authored PatrolZone always wins. Otherwise the guard patrols the egg spawn area, which is
	-- what it is there to protect; the island Area is only the last resort.
	local area = reference
		or template.Parent:FindFirstChild("PatrolZone")
		or island:FindFirstChild("PatrolZone")
		or island:FindFirstChild(eggConfig.SpawnAreaName)
		or island:FindFirstChild("Area")

	return area and area:IsA("BasePart") and area or nil
end

-- radius = how far the guard's BODY reaches sideways, used to keep it inside its patrol zone.
-- bottom/top = vertical extent of what is VISIBLE: the bottom has to touch the ground and the top
-- is where the alert billboard hangs.
function Geometry.GetRigBounds(model: Model): (number, number, number)
	local pivot = model:GetPivot()
	local radius, bottom, top = 0, math.huge, -math.huge
	local function eachCorner(bounds: CFrame, size: Vector3, visit: (Vector3) -> ())
		for _, x in ipairs({ -1, 1 }) do
			for _, y in ipairs({ -1, 1 }) do
				for _, z in ipairs({ -1, 1 }) do
					visit(bounds:PointToWorldSpace(size * Vector3.new(x, y, z) / 2) - pivot.Position)
				end
			end
		end
	end

	local function include(bounds: CFrame, size: Vector3)
		eachCorner(bounds, size, function(corner)
			radius = math.max(radius, Vector2.new(corner.X, corner.Z).Magnitude)
			bottom = math.min(bottom, corner.Y)
			top = math.max(top, corner.Y)
		end)
	end

	for _, part in ipairs(model:GetDescendants()) do
		if part:IsA("BasePart") and part.Name ~= "Hitbox" and part.Name ~= "PatrolZone" and part.Transparency < 1 then
			include(part.CFrame, part.Size)
		end
	end

	if bottom == math.huge then
		include(model:GetBoundingBox())
	end

	-- An authored Hitbox is the body's real footprint, so it owns the horizontal answer. Measuring
	-- the visible mesh made a winged guard's radius its wingspan (39.6 studs on the FirePhoenix),
	-- which shrank its patrol zone to a line. Wings are allowed to overhang the zone, the same way
	-- an egg's spikes overhang the rim of its nest.
	local hitbox = model:FindFirstChild("Hitbox", true)
	if hitbox and hitbox:IsA("BasePart") then
		radius = 0
		eachCorner(hitbox.CFrame, hitbox.Size, function(corner)
			radius = math.max(radius, Vector2.new(corner.X, corner.Z).Magnitude)
		end)
	end

	return radius, -bottom, top
end

return Geometry
