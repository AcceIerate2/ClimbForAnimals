local TreadmillConfig = {}

TreadmillConfig.MultiplierCooldownDuration = 4
TreadmillConfig.MultiplierDuration = 1
TreadmillConfig.MultiplierBoost = 2

TreadmillConfig.BaseSpeedPerStep = 5
TreadmillConfig.BaseLevel = 0
TreadmillConfig.MaxLevel = 5

TreadmillConfig.LevelConfig = require(script.treadmillLevels)
return TreadmillConfig
