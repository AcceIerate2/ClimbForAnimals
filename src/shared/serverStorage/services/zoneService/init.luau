-- Roblox Services
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Packages
local knit = require(ReplicatedStorage.src.Packages.knit)

-->
local ZoneService = knit.CreateService({
	Name = "ZoneService",
	Client = {},
})

-- LifeCycle
function ZoneService:KnitInit() end

function ZoneService:KnitStart() end

return ZoneService
