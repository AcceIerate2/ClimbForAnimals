-- Roblox Services
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Packages
local knit = require(ReplicatedStorage.src.Packages.knit)

-->
local TreadmillStopButton = {}

-- LifeCycle
function TreadmillStopButton:Init(player: Player)
	self.Button = player.PlayerGui:WaitForChild("General"):WaitForChild("StopButton"):WaitForChild("Button")
	self.Button:AddTag("GuiButton")
	self.Button:SetAttribute("Type", "Action")
	self.Button:SetAttribute("Action", "DeactivateTreadmill")
	self.Button.Visible = false

	self.TreadmillController = knit.GetController("TreadmillController")
	self.TreadmillController.Signals.ToggleStopBtnVisibility:Connect(function(toggle: boolean)
		self.Button.Visible = toggle
	end)
end

return TreadmillStopButton
