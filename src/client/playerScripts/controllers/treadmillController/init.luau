-- Roblox Services
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Packages
local knit = require(ReplicatedStorage.src.Packages.knit)

-->
local TreadmillController = {}

function TreadmillController:KnitInit()
	self.DataController = knit.GetController("DataController")
	self.BaseController = knit.GetController("BaseController")
end

function TreadmillController:KnitStart() end

return TreadmillController
