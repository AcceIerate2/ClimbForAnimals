-- Canvas height for a list-driven ScrollingFrame.
--
-- Scale inside a ScrollingFrame is measured against the CANVAS, and the canvas here is derived
-- from the content, so a scale-sized row or padding feeds back into itself: with rows at 0.375
-- and padding at 0.04, three rows already make the content 1.21x the canvas and every update
-- grows both. The authored proportions are kept, but resolved against the visible window and
-- written as offsets, which breaks the loop and makes the canvas grow linearly with the rows.
local ScrollingCanvas = {}

local function scaleOf(udim: UDim): number
	return udim.Scale
end

function ScrollingCanvas.Connect(frame: ScrollingFrame): { RBXScriptConnection }
	local layout = frame:WaitForChild("UIListLayout") :: UIListLayout
	local padding = frame:FindFirstChildOfClass("UIPadding")
	frame.AutomaticCanvasSize = Enum.AutomaticSize.None

	-- Authored proportions, read once before anything is converted to offsets.
	local paddingScale = scaleOf(layout.Padding)
	local insetScales = padding
			and {
				Top = scaleOf(padding.PaddingTop),
				Bottom = scaleOf(padding.PaddingBottom),
				Left = scaleOf(padding.PaddingLeft),
				Right = scaleOf(padding.PaddingRight),
			}
		or nil

	local rowScale = 0
	local relativeYYSize
	for _, child in ipairs(frame:GetChildren()) do
		if child:IsA("GuiObject") and child.SizeConstraint == Enum.SizeConstraint.RelativeYY then
			relativeYYSize = relativeYYSize or child.Size
		end
		if child:IsA("GuiObject") and child.Size.Y.Scale > rowScale then
			rowScale = child.Size.Y.Scale
		end
	end

	local function resolveScales()
		local window = frame.AbsoluteSize
		if window.Y <= 0 then
			return
		end

		if paddingScale > 0 then
			layout.Padding = UDim.new(0, math.round(paddingScale * window.Y))
		end

		if padding and insetScales then
			padding.PaddingTop = UDim.new(0, math.round(insetScales.Top * window.Y))
			padding.PaddingBottom = UDim.new(0, math.round(insetScales.Bottom * window.Y))
			padding.PaddingLeft = UDim.new(0, math.round(insetScales.Left * window.X))
			padding.PaddingRight = UDim.new(0, math.round(insetScales.Right * window.X))
		end

		if rowScale <= 0 then
			return
		end

		-- Every child of this frame is a row cloned from the same template, so they all take the
		-- template's height. Only the height is touched; the width keeps whatever was authored.
		local height = math.round(rowScale * window.Y)
		for _, child in ipairs(frame:GetChildren()) do
			if child:IsA("GuiObject") then
				-- RelativeYY cards derive BOTH dimensions from height. Leaving X scaled
				-- makes their width grow with CanvasSize as more cards are added.
				if relativeYYSize and child.SizeConstraint == Enum.SizeConstraint.RelativeYY then
					local resolved = UDim2.fromOffset(
						math.round(relativeYYSize.X.Scale * window.Y + relativeYYSize.X.Offset),
						math.round(relativeYYSize.Y.Scale * window.Y + relativeYYSize.Y.Offset)
					)
					child.Size = resolved
					-- The button animation must restore the resolved size, not an old
					-- scaled DefaultSize inherited from the template.
					child:SetAttribute("DefaultSize", resolved)
					continue
				end
				local size = child.Size
				if size.Y.Scale ~= 0 or size.Y.Offset ~= height then
					child.Size = UDim2.new(size.X.Scale, size.X.Offset, 0, height)
				end
			end
		end
	end

	local function update()
		local frameHeight = frame.AbsoluteSize.Y
		if frameHeight <= 0 then
			return
		end

		local height = layout.AbsoluteContentSize.Y
		if padding and height > 0 then
			height += padding.PaddingTop.Offset + padding.PaddingBottom.Offset
		end

		local size = UDim2.fromScale(0, height / frameHeight)
		if frame.CanvasSize ~= size then
			frame.CanvasSize = size
		end
	end

	local function refresh()
		resolveScales()
		update()
	end

	local connections = {
		layout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(update),
		frame:GetPropertyChangedSignal("AbsoluteSize"):Connect(refresh),
		frame.ChildAdded:Connect(function(child: Instance)
			if child:IsA("GuiObject") then
				refresh()
			end
		end),
	}

	refresh()
	return connections
end

return ScrollingCanvas
