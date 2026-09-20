-- Roblox Services
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Utility Modules
local InstanceCreator = require(ReplicatedStorage.src.utility.InstanceCreator)

-- Config
local IconAssetId = `rbxassetid://{12348119032}`

-->
return function(parent)
	local screenGui = InstanceCreator("ScreenGui", "PaymentProcessingOverlay", parent, {
		ScreenInsets = Enum.ScreenInsets.None,
		ResetOnSpawn = false,
		DisplayOrder = 100,
		SafeAreaCompatibility = Enum.SafeAreaCompatibility.None,
	})

	local container = InstanceCreator("CanvasGroup", "Container", screenGui, {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(1, 1),

		BackgroundTransparency = 0.25,
		BackgroundColor3 = Color3.fromRGB(0, 0, 0),

		GroupTransparency = 1,
	})

	InstanceCreator("ImageLabel", "spinningIcon", container, {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(0.075, 0.075),
		SizeConstraint = Enum.SizeConstraint.RelativeYY,
		BackgroundTransparency = 1,
		Image = IconAssetId,
	})

	return screenGui
end
