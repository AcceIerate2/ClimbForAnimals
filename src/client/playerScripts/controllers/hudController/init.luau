-- Roblox Services
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Packages
local Signal = require(ReplicatedStorage.src.Packages.Signal)
local knit = require(ReplicatedStorage.src.Packages.knit)

-->
local HudController = knit.CreateController({
	Name = "HudController",
	Signals = {
		ToggleRightButtonsVisibility = Signal.new(),
	},
})

-- Public Methods
function HudController:ToggleRightButtonsVisibility()
	self.Signals.ToggleRightButtonsVisibility:Fire()
end

-- LifeCycle
function HudController:KnitInit() end

return HudController
