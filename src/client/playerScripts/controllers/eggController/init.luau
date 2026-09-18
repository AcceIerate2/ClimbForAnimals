-- Roblox Services
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Packages
local Signal = require(ReplicatedStorage.src.Packages.Signal)
local knit = require(ReplicatedStorage.src.Packages.knit)

-->
local EggController = knit.CreateController({
	Name = "EggController",
	Signals = {
		ToggleVisibility = Signal.new(),
	},

	Visible = false,
})

-- Public Methods
function EggController:ToggleVisibility()
	self.HudController:ToggleRightButtonsVisibility()
	self.Signals.ToggleVisibility:Fire(not self.Visible)
	self.Visible = not self.Visible
end

-- LifeCycle
function EggController:KnitInit()
	self.HudController = knit.GetController("HudController")
end

function EggController:KnitStart()
	self.Signals.ToggleVisibility:Fire(false)
end

return EggController
