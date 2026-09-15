local TreadmillConfig = {}

TreadmillConfig.MultiplierCooldownDuration = 4
TreadmillConfig.MultiplierDuration = 1
TreadmillConfig.MultiplierBoost = 2

TreadmillConfig.BaseSpeedPerStep = 1
TreadmillConfig.BaseLevel = 0

TreadmillConfig.LevelConfig = require(script.treadmillLevels)
TreadmillConfig.MaxLevel = #TreadmillConfig.LevelConfig

return TreadmillConfig
