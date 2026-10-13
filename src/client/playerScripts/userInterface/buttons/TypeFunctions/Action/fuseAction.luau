-- Roblox Services
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Packages
local knit = require(ReplicatedStorage.src.Packages.knit)

return function(button)
	local controller = knit.GetController("FuseController")
	if button:GetAttribute("FuseReturn") then
		controller:CancelSelection()
		return
	end

	local slot = button:GetAttribute("FuseSlot")
	if slot then
		controller:ClickSlot(slot)
	else
		controller:SelectAnimal(button:GetAttribute("ReferenceName"))
	end
end
