-- Roblox Services
local RunService = game:GetService("RunService")

-- Projects a world sign into the existing dimmed-screen UI. The hole tracks camera movement.
local WorldHighlighter = {}
WorldHighlighter.__index = WorldHighlighter

function WorldHighlighter.new(uiHighlighter, padding: number)
	return setmetatable({ UI = uiHighlighter, Padding = padding }, WorldHighlighter)
end

function WorldHighlighter:GetRectangle(camera, frame: CFrame, size: Vector3)
	local minimum = Vector2.new(math.huge, math.huge)
	local maximum = Vector2.new(-math.huge, -math.huge)
	for _, x in ipairs({ -1, 1 }) do
		for _, y in ipairs({ -1, 1 }) do
			for _, z in ipairs({ -1, 1 }) do
				local corner = frame:PointToWorldSpace(size * Vector3.new(x, y, z) / 2)
				local projected = camera:WorldToViewportPoint(corner)
				-- Avoid a screen-sized mask as the camera passes through/behind the sign.
				if projected.Z <= 0 then
					return nil
				end
				minimum = Vector2.new(math.min(minimum.X, projected.X), math.min(minimum.Y, projected.Y))
				maximum = Vector2.new(math.max(maximum.X, projected.X), math.max(maximum.Y, projected.Y))
			end
		end
	end
	local viewport = camera.ViewportSize
	if maximum.X < 0 or maximum.Y < 0 or minimum.X > viewport.X or minimum.Y > viewport.Y then
		return nil
	end
	return minimum, maximum - minimum
end

function WorldHighlighter:update()
	local target, camera = self.Target, workspace.CurrentCamera
	local position, size
	if target and target.Parent and camera then
		local frame, bounds
		if target:IsA("Model") then
			frame, bounds = target:GetBoundingBox()
		elseif target:IsA("BasePart") then
			frame, bounds = target.CFrame, target.Size
		end
		if frame then
			position, size = self:GetRectangle(camera, frame, bounds)
		end
	end
	if position then
		self.UI:Draw({ ViewportPosition = position, AbsoluteSize = size, Padding = self.Padding })
		self.Drawn = true
	elseif self.Drawn then
		self.UI:Destroy()
		self.Drawn = false
	end
end

function WorldHighlighter:Show(target)
	if self.Target == target then
		return
	end
	self:Clear()
	self.Target = target
	if not target then
		return
	end
	self.Connection = RunService.RenderStepped:Connect(function()
		self:update()
	end)
	self:update()
end

function WorldHighlighter:Clear()
	if self.Connection then
		self.Connection:Disconnect()
	end
	self.Connection = nil
	self.Target = nil
	if self.Drawn then
		self.UI:Destroy()
	end
	self.Drawn = false
end

return WorldHighlighter
