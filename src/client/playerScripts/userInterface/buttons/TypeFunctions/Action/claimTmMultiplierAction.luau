-- Roblox Services
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Packages
local knit = require(ReplicatedStorage.src.Packages.knit)

-- Utility Modules
local PlayTween = require(ReplicatedStorage.src.utility.PlayTween)

-- Constants
local tweenConfig = TweenInfo.new(0.15)

-->
return function(button)
	local id = button:GetAttribute("Id")
	knit.GetController("TreadmillController"):ClaimMultiplier(id)

	PlayTween(button, tweenConfig, {
		ImageTransparency = 1,
	})

	local parent = button.Parent
	PlayTween(parent, tweenConfig, {
		Size = UDim2.fromScale(parent.Size.X.Scale * 1.5, parent.Size.Y.Scale * 1.5),
	}, function()
		knit.GetController("ButtonsController"):Unlink(button)

		if button and button.Parent then
			button.Parent:Destroy()
		end
	end)
end
