-- Roblox Services
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")

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
	local sfxDebounce = false

	self.Speed = self.DataController:GetValue("Speed")
	self.DataController:GetValueChangedSignal("Speed"):Connect(function(newValue)
		local change = newValue - self.Speed
		self.Speed = newValue

		-- Decreases, including rebirth resets, must update the HUD too.
		self.Signals.UpdateSpeedText:Fire(newValue)

		if change > 0 then
			self.Signals.PopupEffect:Fire(change)

			if sfxDebounce then
				return
			end

			sfxDebounce = true
			task.delay(0.85, function()
				sfxDebounce = false
			end)

			self.AudioController:PlaySfx("Popup", {
				PlayOver = true,
				Parent = SoundService,
			})
		end
	end)
end

-- LifeCycle
function SpeedController:KnitInit()
	self.DataController = knit.GetController("DataController")
	self.AudioController = knit.GetController("AudioController")
end

function SpeedController:KnitStart()
	self:listenToValueChanges()
end

return SpeedController
