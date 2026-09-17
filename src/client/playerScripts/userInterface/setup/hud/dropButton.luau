-- Roblox Services
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Packages
local knit = require(ReplicatedStorage.src.Packages.knit)

-->
local DropButton = {}

-- LifeCycle
function DropButton:Init(player: Player)
	self.Container = player.PlayerGui:WaitForChild("General"):WaitForChild("DropButton")
	self.Container.Visible = false

	self.Button = self.Container:WaitForChild("Button")
	self.Button:AddTag("GuiButton")
	self.Button:SetAttribute("Type", "Action")
	self.Button:SetAttribute("Action", "DropEgg")
	self.Button.Visible = true

	self.EggCarryController = knit.GetController("EggCarryController")
	self.EggCarryController.Signals.ToggleDropButton:Connect(function(visible: boolean)
		self.Container.Visible = visible
	end)
end

return DropButton
