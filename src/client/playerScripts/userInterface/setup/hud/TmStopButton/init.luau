-- Roblox Services
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Packages
local knit = require(ReplicatedStorage.src.Packages.knit)

-->
local TreadmillStopButton = {}

-- LifeCycle
function TreadmillStopButton:Init(player: Player)
	self.Container = player.PlayerGui:WaitForChild("General"):WaitForChild("StopButton")
	self.Container.Visible = false

	self.Button = self.Container:WaitForChild("Button")
	self.Button:AddTag("GuiButton")
	self.Button:SetAttribute("Type", "Action")
	self.Button:SetAttribute("Action", "DeactivateTreadmill")
	self.Button.Visible = true

	self.TreadmillController = knit.GetController("TreadmillController")
	self.TreadmillController.Signals.ToggleStopBtnVisibility:Connect(function(toggle: boolean)
		self.Container.Visible = toggle
	end)
end

return TreadmillStopButton
