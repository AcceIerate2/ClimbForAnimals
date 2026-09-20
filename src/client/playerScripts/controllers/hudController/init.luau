-- Roblox Services
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Packages
local Signal = require(ReplicatedStorage.src.Packages.Signal)
local knit = require(ReplicatedStorage.src.Packages.knit)

-->
local HudController = knit.CreateController({
	Name = "HudController",
	HeightBarVisible = false,
	RightButtonsVisible = true,
	Signals = {
		ToggleRightButtonsVisibility = Signal.new(),
	},
})

-- Public Methods
function HudController:ToggleRightButtonsVisibility(visible: boolean?)
	self.RightButtonsVisible = if visible == nil then not self.RightButtonsVisible else visible
	self.Signals.ToggleRightButtonsVisibility:Fire(self:AreRightButtonsVisible())
end

function HudController:AreRightButtonsVisible(): boolean
	return self.RightButtonsVisible and not self.HeightBarVisible
end

function HudController:SetHeightBarVisible(visible: boolean)
	if self.HeightBarVisible == visible then
		return
	end

	self.HeightBarVisible = visible
	self.Signals.ToggleRightButtonsVisibility:Fire(self:AreRightButtonsVisible())
end

-- LifeCycle
function HudController:KnitInit() end

return HudController
