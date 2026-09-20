local DayCycleConfig = {}

DayCycleConfig.PeriodDuration = 300
DayCycleConfig.NightDuration = 10
DayCycleConfig.PollInterval = 0.25

DayCycleConfig.DayIcon = "rbxassetid://140477830194574"
DayCycleConfig.NightIcon = "rbxassetid://104117589236722"

DayCycleConfig.NightAmbient = Color3.fromRGB(255, 255, 255)
DayCycleConfig.NightBrightness = 0.1
DayCycleConfig.NightColorCorrection = -0.1

DayCycleConfig.RestockLeadSeconds = 1
DayCycleConfig.NightWarningSeconds = 5
DayCycleConfig.TickSeconds = 3
DayCycleConfig.TickVolume = 0.45
DayCycleConfig.WallFadeDuration = 0.3
DayCycleConfig.WallSolidGraceSeconds = 0.25
DayCycleConfig.WallDropDuration = 1.1

DayCycleConfig.NightNotification = {
	Message = "Night Time! Restocking Starting...",
	Color = Color3.fromRGB(0, 255, 255),
}

DayCycleConfig.ResetNotification = {
	Message = "All Eggs Have Reset!",
	Color = Color3.fromRGB(0, 255, 0),
	Sound = "Accept",
}

DayCycleConfig.NightWarningNotification = {
	Message = "Night Time Starting in %d",
	Color = Color3.fromRGB(255, 200, 0),
}

DayCycleConfig.CaughtNotification = {
	Message = "Dropped Egg! you got caught at night",
	Color = Color3.fromRGB(255, 70, 70),
	Sound = "Decline",
}

return DayCycleConfig
