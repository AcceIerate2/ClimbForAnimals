-- Roblox Services
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Packages
local knit = require(ReplicatedStorage.src.Packages.knit)

-->
local GateController = knit.CreateController({ Name = "GateController" })

-- LifeCycle
function GateController:KnitInit() end

return GateController
