-- Image alerts use the authored Alert sibling of Detection; no badges are created.
local Alerts = {}

-- Private Methods
function Alerts:getImage(button)
	if not button then
		return nil
	end

	local image = button:FindFirstChild("Alert") or (button.Parent and button.Parent:FindFirstChild("Alert"))
	return image and image:IsA("GuiObject") and image or nil
end

-- Public Methods
function Alerts:manipulate(button, _increment: number?)
	local image = self:getImage(button)
	if image then
		image.Visible = true
	end
end

function Alerts:clear(button)
	local image = self:getImage(button)
	if image then
		image.Visible = false
	end
end

return Alerts
