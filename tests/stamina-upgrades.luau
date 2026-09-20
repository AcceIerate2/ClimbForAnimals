-- Run from the project root: lune run tests/stamina-upgrades.luau
local fs = require("@lune/fs")
local luau = require("@lune/luau")
local deps = {
	knit = {
		CreateService = function(value)
			return value
		end,
	},
	NumberShortner = tostring,
}
local function load(path)
	local source = fs.readFile(path)
	luau.compile(source)
	source = source:gsub("local ([%w_]+) = require%([^\n]+%)", "local %1 = Dependencies.%1")
	return luau.load(
		source,
		{ environment = {
			Dependencies = deps,
			game = {
				GetService = function()
					return {}
				end,
			},
		} }
	)()
end
local config = load("src/shared/replicatedStorage/GameConfiguration/Economy/staminaUpgradeConfig.luau")
deps.Config = config
local service = load("src/shared/serverStorage/services/staminaUpgradeService/init.luau")
local values = { StaminaLevel = 0, StaminaConsumptionRate = 1, Cash = 1000000 }
local active = true
local player = {}
service.DataService = {
	GetProfile = function()
		return values
	end,
	GetValue = function(_, _, key)
		return values[key]
	end,
	GetValueObject = function(_, _, key)
		return {
			Set = function(_, value)
				values[key] = value
			end,
		}
	end,
}
service.ProfileStoreService = {
	getProfile = function()
		return {
			IsActive = function()
				return active
			end,
		}
	end,
}
local charges = 0
service.CashService = {
	ManipulatePlayerCash = function(_, _, amount, operation)
		assert(operation == "Addition" and amount <= 0)
		charges += 1
		values.Cash += amount
	end,
}
local function purchase(level)
	service.LastRequest[player] = nil
	return service:Purchase(player, level)
end
service:Initialize(player)
assert(values.StaminaLevel == 1 and values.StaminaConsumptionRate == 1)
assert(purchase(1).Status and values.Cash == 0)
assert(values.StaminaLevel == 2 and values.StaminaConsumptionRate == 2 and charges == 1)
assert(service:Purchase(player, 2).Silent)
assert(not purchase(1).Status and charges == 1, "Stale requests must not charge twice")
assert(not purchase(2).Status and charges == 1, "Insufficient cash must not change level")
values.Cash = 100000000
assert(purchase(2).Status and values.Cash == 98000000)
service:Initialize(player)
assert(values.StaminaLevel == 3 and values.StaminaConsumptionRate == 3, "Saved levels survive initialization")
values.StaminaLevel, values.StaminaConsumptionRate = 0, 4
service:Initialize(player)
assert(values.StaminaLevel == 4, "Legacy drain upgrades migrate")
config.Overrides[5] = { Price = 123, DrainInterval = 6 }
assert(purchase(4).Status and values.StaminaConsumptionRate == 6)
config.Overrides[6] = { Price = -1, DrainInterval = 7 }
local cashBefore = values.Cash
assert(not purchase(5).Status and values.Cash == cashBefore)
config.Overrides[6] = { Price = 1, DrainInterval = 0 }
assert(not purchase(5).Status and values.Cash == cashBefore)
config.Enabled = false
assert(not purchase(5).Status)
config.Enabled = true
active = false
assert(not purchase(5).Status)
active = true
service:SetLevel(player, config.MaxLevel)
assert(not purchase(config.MaxLevel).Status and values.Cash == cashBefore)
print(
	"Stamina purchase, duplicate requests, insufficient cash, migration, persistence, overrides, invalid config, session and cap checks passed."
)
