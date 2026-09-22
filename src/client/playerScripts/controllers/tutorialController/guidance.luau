-- Each arrow owns its attachments so two platform arrows never destroy each other.
local Guidance = {}
Guidance.__index = Guidance

function Guidance.new(template: Beam, settings)
	return setmetatable({ Template = template, Settings = settings or {}, Arrows = {} }, Guidance)
end

function Guidance:Clear()
	for _, arrow in ipairs(self.Arrows) do
		arrow.Source:Destroy()
		arrow.Target:Destroy()
		arrow.Beam:Destroy()
	end
	table.clear(self.Arrows)
	self.Root = nil
end

function Guidance:Update(root: BasePart?, targets: { CFrame })
	if self.Root ~= root or #self.Arrows ~= #targets then
		self:Clear()
	end
	if not root then
		return
	end
	self.Root = root

	for index, target in ipairs(targets) do
		local arrow = self.Arrows[index]
		if not arrow then
			local part = Instance.new("Part")
			part.Name = "TutorialDestination"
			part.Size = Vector3.one
			part.Anchored = true
			part.Transparency = 1
			part.CanCollide, part.CanTouch, part.CanQuery = false, false, false
			part.Parent = workspace
			local source = Instance.new("Attachment")
			source.Name = "TutorialSource"
			source.Parent = root
			local destination = Instance.new("Attachment")
			destination.Parent = part
			local beam = self.Template:Clone()
			-- Authored attachment rotations/curves can turn the ribbon edge-on or bend it backward.
			-- Keep the template texture, but normalize geometry and outward scrolling for every arrow.
			local settings = self.Settings
			beam.FaceCamera = true
			beam.CurveSize0, beam.CurveSize1 = 0, 0
			beam.Width0, beam.Width1 = settings.Width or 2, settings.Width or 2
			beam.TextureMode = Enum.TextureMode.Wrap
			beam.TextureLength = settings.TextureLength or 4
			beam.TextureSpeed = math.abs(settings.TextureSpeed or 1)
			beam.Transparency = NumberSequence.new(settings.Transparency or 0)
			beam.LightInfluence = 0
			-- Character is the first attachment; the destination is the second.
			beam.Attachment0, beam.Attachment1 = source, destination
			beam.Enabled = true
			beam.Parent = source
			arrow = { Source = source, Target = part, Beam = beam }
			self.Arrows[index] = arrow
		end
		arrow.Target.CFrame = target
	end
end

return Guidance
