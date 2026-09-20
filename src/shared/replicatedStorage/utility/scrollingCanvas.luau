local ScrollingCanvas = {}

function ScrollingCanvas.Connect(frame: ScrollingFrame): { RBXScriptConnection }
	local layout = frame:WaitForChild("UIListLayout") :: UIListLayout
	local padding = frame:FindFirstChildOfClass("UIPadding")
	frame.AutomaticCanvasSize = Enum.AutomaticSize.None

	local function update()
		local frameHeight = frame.AbsoluteSize.Y
		if frameHeight <= 0 then
			return
		end

		local height = layout.AbsoluteContentSize.Y
		if padding and height > 0 then
			local top, bottom = padding.PaddingTop, padding.PaddingBottom
			height += top.Offset + bottom.Offset + (top.Scale + bottom.Scale) * frameHeight
		end

		local size = UDim2.fromScale(0, height / frameHeight)
		if frame.CanvasSize ~= size then
			frame.CanvasSize = size
		end
	end

	local connections = {
		layout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(update),
		frame:GetPropertyChangedSignal("AbsoluteSize"):Connect(update),
	}
	if padding then
		table.insert(connections, padding:GetPropertyChangedSignal("PaddingTop"):Connect(update))
		table.insert(connections, padding:GetPropertyChangedSignal("PaddingBottom"):Connect(update))
	end

	update()
	return connections
end

return ScrollingCanvas
