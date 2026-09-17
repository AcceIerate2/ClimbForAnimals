-- Constants
local HeightOffset = 1

-->
local Popup = {}

function Popup.GetPositions(asset: Model, root: BasePart): (Vector3, Vector3)
	local frame, size = asset:GetBoundingBox()
	local halfHeight = (
		math.abs(frame.RightVector.Y) * size.X
		+ math.abs(frame.UpVector.Y) * size.Y
		+ math.abs(frame.LookVector.Y) * size.Z
	) / 2

	local center = frame.Position
	local top = center + Vector3.new(0, halfHeight + HeightOffset, 0)

	return root.CFrame:PointToObjectSpace(center), root.CFrame:PointToObjectSpace(top)
end

return Popup
