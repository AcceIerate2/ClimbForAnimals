-- Roblox Services
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Packages
local knit = require(ReplicatedStorage.src.Packages.knit)

-- Utility Modules
local NumberShortner = require(ReplicatedStorage.src.utility.NumberShortner)

-- Config Modules
local Config = require(ReplicatedStorage.src.GameConfiguration.Economy.staminaUpgradeConfig)

-- Helper Functions
local function finite(value): boolean
	return type(value) == "number" and value == value and math.abs(value) < math.huge
end

-->
local StaminaUpgradeService = knit.CreateService({
	Name = "StaminaUpgradeService",
	Client = {},
	LastRequest = {},
})

-- Client Exposed Methods
function StaminaUpgradeService.Client:Purchase(player: Player, expectedLevel: number)
	return self.Server:Purchase(player, expectedLevel)
end

-- Public Methods
function StaminaUpgradeService:SetLevel(player: Player, level: number)
	level = Config.NormalizeLevel(level)
	local interval = Config.GetDrainInterval(level)
	assert(finite(interval) and interval > 0, "Stamina drain interval must be positive and finite")

	self.DataService:GetValueObject(player, "StaminaLevel"):Set(level)
	self.DataService:GetValueObject(player, "StaminaConsumptionRate"):Set(interval)
end

function StaminaUpgradeService:Initialize(player: Player)
	local level = self.DataService:GetValue(player, "StaminaLevel")
	if level == 0 then
		level = Config.LevelFromInterval(self.DataService:GetValue(player, "StaminaConsumptionRate"))
	end

	self:SetLevel(player, level)
end

function StaminaUpgradeService:Purchase(player: Player, expectedLevel: number)
	local now = os.clock()
	if now - (self.LastRequest[player] or -math.huge) < Config.RequestCooldown then
		return { Status = false, Silent = true }
	end

	self.LastRequest[player] = now

	local profile = self.ProfileStoreService:getProfile(player)
	if not profile or not profile:IsActive() or not self.DataService:GetProfile(player) then
		return { Status = false, Reason = "Your data is still loading. Please try again." }
	end

	if not Config.Enabled then
		return { Status = false, Reason = "Stamina upgrades are currently unavailable." }
	end

	local level = Config.NormalizeLevel(self.DataService:GetValue(player, "StaminaLevel"))
	if expectedLevel ~= level then
		return { Status = false, Reason = "Your stamina level changed. Please try again." }
	end

	local price = Config.GetPrice(level)
	if price == nil then
		return { Status = false, Reason = "Your stamina is already at the maximum level!" }
	end

	local interval = Config.GetDrainInterval(level + 1)
	if not finite(price) or price < 0 or not finite(interval) or interval <= 0 then
		return { Status = false, Reason = "This stamina upgrade isn't configured correctly." }
	end

	local cash = self.DataService:GetValue(player, "Cash")
	if not finite(cash) then
		return { Status = false, Reason = "Your cash couldn't be loaded." }
	end

	if cash < price then
		return { Status = false, Reason = `You need ${NumberShortner(price - cash)} more to upgrade stamina!` }
	end

	-- No yield between validation, payment and upgrade. A repeated level cannot charge twice.
	self.CashService:ManipulatePlayerCash(player, -price, "Addition")
	self:SetLevel(player, level + 1)

	return { Status = true, Level = level + 1, Price = price }
end

-- LifeCycle
function StaminaUpgradeService:KnitInit()
	self.DataService = knit.GetService("DataService")
	self.ProfileStoreService = knit.GetService("ProfileStoreService")
	self.CashService = knit.GetService("CashService")
end

function StaminaUpgradeService:KnitStart()
	Players.PlayerRemoving:Connect(function(player)
		self.LastRequest[player] = nil
	end)
end

return StaminaUpgradeService
