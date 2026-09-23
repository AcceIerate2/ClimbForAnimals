-- Swaps an authored Frame for an ImageButton with the same layout, artwork, attributes, tags and children,
-- so a Frame built in Studio can be linked to the ButtonsController.
local CollectionService = game:GetService("CollectionService")

return function(frame: GuiObject): GuiButton
	if frame:IsA("GuiButton") then
		return frame
	end

	local button = Instance.new("ImageButton")
	button.Image = ""
	button.AutoButtonColor = false
	for _, property in ipairs({
		"Name",
		"AnchorPoint",
		"Position",
		"Size",
		"SizeConstraint",
		"AutomaticSize",
		"LayoutOrder",
		"Rotation",
		"ZIndex",
		"Visible",
		"ClipsDescendants",
		"BackgroundColor3",
		"BackgroundTransparency",
		"BorderColor3",
		"BorderSizePixel",
		"BorderMode",
	}) do
		button[property] = frame[property]
	end
	for name, value in pairs(frame:GetAttributes()) do
		button:SetAttribute(name, value)
	end
	for _, tag in ipairs(CollectionService:GetTags(frame)) do
		CollectionService:AddTag(button, tag)
	end
	for _, child in ipairs(frame:GetChildren()) do
		child.Parent = button
	end
	button.Parent = frame.Parent
	frame:Destroy()
	return button
end
