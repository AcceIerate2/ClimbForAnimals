local Hitbox = {}

-- Public Methods
function Hitbox.Check(data, character: Model): boolean
	if data.LastCharacter ~= character then
		data.LastCharacter = character
		data.Overlap = OverlapParams.new()
		data.Overlap.FilterType = Enum.RaycastFilterType.Include
		data.Overlap.FilterDescendantsInstances = { character }
		data.Overlap.MaxParts = 1
		data.Overlap.RespectCanCollide = false
	end

	return #workspace:GetPartsInPart(data.Hitbox, data.Overlap) > 0
end

return Hitbox
