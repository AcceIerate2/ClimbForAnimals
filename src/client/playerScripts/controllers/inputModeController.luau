-- Roblox Services
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

-- Packages
local Signal = require(ReplicatedStorage.src.Packages.Signal)
local Knit = require(ReplicatedStorage.src.Packages.knit)

-- Local Types
type InputMode = "Keyboard" | "Gamepad" | "Touch"

-->
local InputModeController = Knit.CreateController({
	Name = "InputModeController",

	InputModeChanged = Signal.new(), -- :Fire(InputMode)
	CurrentInputMode = "Keyboard" :: InputMode,
})

-- Private Methods
function InputModeController:syncCurrentInputMode(userInputType: Enum.UserInputType)
	local newInputMode: InputMode
	if userInputType == Enum.UserInputType.Touch then
		newInputMode = "Touch"
	elseif userInputType.Name:find("Gamepad") then
		newInputMode = "Gamepad"
	else
		newInputMode = "Keyboard"
	end

	if self.CurrentInputMode == newInputMode then
		return
	end

	self.CurrentInputMode = newInputMode
	self.InputModeChanged:Fire(newInputMode)
end

-- LifeCycle
function InputModeController:KnitStart()
	self:syncCurrentInputMode(UserInputService:GetLastInputType())
	UserInputService.LastInputTypeChanged:Connect(function(userInputType: Enum.UserInputType)
		self:syncCurrentInputMode(userInputType)
	end)
end

return InputModeController
