-- Roblox Services
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Packages
local Signal = require(ReplicatedStorage.src.Packages.Signal)
local knit = require(ReplicatedStorage.src.Packages.knit)

-->
local SpeedController = knit.CreateController({
	Name = "SpeedController",
	Speed = 0,
	Signals = {
		PopupEffect = Signal.new(),
		UpdateSpeedText = Signal.new(),
	},
})

-- Private Methods
function SpeedController:listenToValueChanges()
	self.Speed = self.DataController:GetValue("Speed")
	self.DataController:GetValueChangedSignal("Speed"):Connect(function(newValue)
		local change = newValue - self.Speed
		self.Speed = newValue
		if change > 0 then
			self.Signals.PopupEffect:Fire(change)
			self.Signals.UpdateSpeedText:Fire(newValue)
		end
	end)
end

-- LifeCycle
function SpeedController:KnitInit()
	self.DataController = knit.GetController("DataController")
end

function SpeedController:KnitStart()
	self:listenToValueChanges()
end

return SpeedController
