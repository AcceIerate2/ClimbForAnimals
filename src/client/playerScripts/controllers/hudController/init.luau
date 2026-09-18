-- Roblox Services
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Packages
local knit = require(ReplicatedStorage.src.Packages.knit)

-->
local HudController = knit.CreateController({
	Name = "HudController",
})

-- Public Methods
function HudController:ToggleVisibility() end

function HudController:ToggleRightButtonsVisibility() end

-- LifeCycle
function HudController:KnitInit() end

return HudController
