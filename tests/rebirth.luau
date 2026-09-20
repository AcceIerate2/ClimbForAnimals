-- Run from the project root: lune run tests/rebirth.luau
local fs = require("@lune/fs")
local luau = require("@lune/luau")
local function copy(value)
	if type(value) ~= "table" then
		return value
	end
	local result = {}
	for key, child in pairs(value) do
		result[key] = copy(child)
	end
	return result
end
local configPath = "src/shared/replicatedStorage/GameConfiguration/Economy/rebirthConfig.luau"
local Config = luau.load(fs.readFile(configPath))()
assert(Config.GetRequirements(0).Speed == 10000)
assert(Config.GetRequirements(2).Speed == 40000)
assert(Config.GetMultiplier(2) == 2)
Config.Multiplier.Mode = "Multiplicative"
assert(Config.GetMultiplier(2) == 2.25)
Config.Multiplier.Mode = "Additive"
Config.Overrides[2] = { Requirements = { Speed = 17, Cash = 500 }, CashMultiplier = 4 }
assert(Config.GetRequirements(1).Cash == 500 and Config.GetMultiplier(2) == 4)
Config.Overrides = {}
assert(Config.ForSource(0, "AnimalIncome") == 1)
assert(Config.ForSource(2, "IndexRewards") == 1)

local products = { [42] = { Action = "SkipRebirth" } }
local deps = {
	NumberShortner = luau.load(fs.readFile("src/shared/replicatedStorage/utility/NumberShortner.luau"))(),
	Config = Config,
	RebirthConfig = Config,
	ProductIds = products,
	BaseConfig = { Levels = { { MaxAnimals = 7 }, { MaxAnimals = 9 } } },
	TreadmillConfig = { LevelConfig = { [0] = {}, [1] = {} } },
	knit = {
		CreateService = function(def)
			return def
		end,
		CreateSignal = function()
			return { Fire = function() end }
		end,
	},
	EarningCurve = {
		GetCashPerSecond = function()
			return 100
		end,
	},
	TypeCheck = {
		Instance = function()
			return true
		end,
		number = function(v)
			return type(v) == "number"
		end,
		string = function(v)
			return type(v) == "string"
		end,
	},
}
local now = 200000
local env = {
	Dependencies = deps,
	game = {
		GetService = function()
			return {}
		end,
	},
	workspace = {
		GetServerTimeNow = function()
			return 100
		end,
	},
	os = {
		time = function()
			return now
		end,
		clock = os.clock,
	},
	Enum = { ProductPurchaseDecision = { PurchaseGranted = "Granted", NotProcessedYet = "Retry" } },
}
local function load(path)
	local source = fs.readFile(path)
	luau.compile(source)
	source = source:gsub("local ([%w_]+) = require%([^\n]+%)", "local %1 = Dependencies.%1")
	return luau.load(source, { environment = env })()
end
local values
local player = {}
local attributes = {}
player.SetAttribute = function(_, key, value)
	attributes[key] = value
end
local data = {
	GetProfile = function()
		return values
	end,
	GetValue = function(_, _, key)
		return values[key]
	end,
	GetValueObject = function(_, _, key)
		return {
			Get = function()
				return values[key]
			end,
			Set = function(_, value)
				values[key] = value
			end,
			Update = function(_, fn)
				local value = copy(values[key])
				fn(value)
				values[key] = value
			end,
		}
	end,
}
local service = load("src/shared/serverStorage/services/rebirthService/init.luau")
service.DataService = data
service.AnimalService = { Profiles = { [player] = true } }
service.EggHatchService = { PendingHatches = {} }
service.CashFlowService = { updateIncome = function() end }
local training = true
local stoppedOnClient = false
service.TreadmillService = {
	DeactivateTreadmill = function(_, _, notifyClient)
		training = false
		stoppedOnClient = notifyClient == true
	end,
}
service.EggSpawnService = { ReturnCarriedEgg = function() end }
local profile = {
	IsActive = function()
		return true
	end,
}
profile.Save = function()
	profile.LastSavedData = copy(values)
end
service.ProfileStoreService = {
	getProfile = function()
		return profile
	end,
}
local function reset()
	values = {
		Rebirths = 0,
		CashMultiplier = 0,
		Speed = 9999,
		TreadmillLevel = 1,
		Cash = 500,
		Inventory = {},
		EquippedAnimals = {},
		PlacedEggs = {},
		RebirthPurchases = { Credits = 0, Receipts = {} },
	}
	service.NextRequest = {}
	service:Initialize(player)
end
reset()
assert(values.CashMultiplier == 1 and attributes.CashMultiplier == 1)
assert(not service:apply(player, false).Status and values.Speed == 9999)
assert(service:apply(player, false).Reason == "You need 1 more Speed to rebirth!")
values.Speed = 10000
assert(service:apply(player, false).Status)
assert(values.Speed == 250 and values.Rebirths == 1 and values.CashMultiplier == 1.5 and values.Cash == 500)
assert(training, "Normal rebirth must preserve active treadmill training")
values.Speed += 6 -- The existing training connection can award the next step after the reset.
assert(values.Speed == 256)
assert(not service:apply(player, true).Status) -- no credit
reset()
assert(service:Request(player, true).ProductId == 42 and values.Rebirths == 0)
assert(service:Request(player, true).Silent) -- throttle
products[42] = nil
service.NextRequest = {}
assert(not service:Request(player, true).Status)
products[42] = { Action = "SkipRebirth" }
assert(service:ProcessReceipt(player, { ProductId = 42, PurchaseId = "a" }) == "Granted")
assert(values.Rebirths == 1 and values.RebirthPurchases.Credits == 0)
assert(service:ProcessReceipt(player, { ProductId = 42, PurchaseId = "a" }) == "Granted")
assert(values.Rebirths == 1)
Config.MaxRebirths = 1
assert(service:ProcessReceipt(player, { ProductId = 42, PurchaseId = "b" }) == "Granted")
assert(values.RebirthPurchases.Credits == 1 and values.Rebirths == 1)
Config.MaxRebirths = 0
Config.Skip.ApplyResets = false
values.Speed = 1234
assert(service:apply(player, true).Status and values.Speed == 1234 and values.Rebirths == 2)
Config.Skip.ApplyResets = true
reset()
service.EggHatchService.PendingHatches[player] = { animal = {} }
assert(service:ProcessReceipt(player, { ProductId = 42, PurchaseId = "c" }) == "Granted")
assert(values.Rebirths == 0 and values.RebirthPurchases.Credits == 1)
service.EggHatchService.PendingHatches[player] = nil
assert(service:apply(player, true).Status)

-- Optional destructive reset policies use the existing item/world cleanup paths.
reset()
values.Speed = 10000
values.Inventory = { animal = { Handler = "Animal" }, egg = { Handler = "Egg" } }
values.EquippedAnimals = { animal = true }
values.PlacedEggs = { placed = {} } -- placed eggs no longer exist in Inventory
local removed, disconnected, destroyed = {}, {}, {}
service.AnimalService.RemoveAnimal = function(_, _, ref)
	removed[ref] = true
	values.Inventory[ref] = nil
end
service.InventoryService = {
	RemoveItem = function(_, _, ref)
		removed[ref] = true
		values.Inventory[ref] = nil
	end,
}
service.EggGrowService = {
	DisconnectEgg = function(_, _, ref)
		disconnected[ref] = true
	end,
}
local eggFolder = {
	FindFirstChild = function(_, ref)
		return {
			Destroy = function()
				destroyed[ref] = true
			end,
		}
	end,
}
service.BaseService = {
	GetPlayerBase = function()
		return {
			FindFirstChild = function(_, name)
				assert(name == "PlacedEggs")
				return eggFolder
			end,
		}
	end,
}
Config.RemoveAnimals, Config.RemoveEggs = true, true
Config.Reset.Cash = 0
assert(service:apply(player, false).Status)
assert(removed.animal and removed.egg and disconnected.placed and destroyed.placed)
assert(next(values.PlacedEggs) == nil and values.Cash == 0)
Config.RemoveAnimals, Config.RemoveEggs = false, false
Config.Reset.Cash = false
reset()
values.Speed = 10000
Config.Reset.BaseLevel = 99
assert(not pcall(function()
	service:apply(player, false)
end))
assert(values.Rebirths == 0 and values.Speed == 10000)
Config.Reset.BaseLevel = false

reset()
values.Speed = 10000
Config.Reset.TreadmillLevel = 1
assert(service:apply(player, false).Status)
assert(not training and stoppedOnClient, "Resetting the treadmill level must stop training on both sides")
Config.Reset.TreadmillLevel = false

local cash = load("src/shared/serverStorage/services/cashService/init.luau")
cash.DataService = data
values.Cash = 0
values.CashMultiplier = 2
cash:ManipulatePlayerCash(player, 100, "Addition", nil, "IndexRewards")
assert(values.Cash == 100)
Config.CashSources.IndexRewards = true
cash:ManipulatePlayerCash(player, 100, "Addition", nil, "IndexRewards")
assert(values.Cash == 300)
Config.CashSources.OtherRewards = true
cash:ManipulatePlayerCash(player, -50, "Addition")
assert(values.Cash == 250)
cash:ManipulatePlayerCash(player, 100, "Addition", nil, "SettledIncome")
assert(values.Cash == 350) -- already multiplied; no double boost
Config.CashSources.IndexRewards = false
Config.CashSources.OtherRewards = false
local online = load("src/shared/serverStorage/services/cashFlowService/init.luau")
online.DataService, online.CashService = data, cash
player.Parent = true
online.Profiles[player] = { a = { CashPerSecond = 100, NextPayout = 100 } }
local beforeOnline = values.Cash
online:updateIncome(100)
assert(values.Cash == beforeOnline + 200)
values.CashMultiplier = 3
online:updateIncome(101)
assert(values.Cash == beforeOnline + 500) -- already-active animal uses the new multiplier
values.CashMultiplier = 2
for _, hours in { 2, 5, 10, 12 } do
	local flow = load("src/shared/serverStorage/services/cashFlowService/init.luau")
	flow.DataService = data
	flow.CashService = cash
	values.LastSeen = now - hours * 3600
	values.JoinedBefore = true
	values.PendingOfflineCash = 0
	values.EquippedAnimals = { a = true }
	values.Inventory = { a = { Handler = "Animal", Name = "Test" } }
	local expected = 100 * 2 * 0.1 * math.min(hours, 10) * 3600
	assert(flow:PrepareOfflineCash(player) == expected)
	assert(flow:PrepareOfflineCash(player) == 0)
	local before = values.Cash
	assert(flow:ClaimOfflineCash(player).Status)
	assert(values.Cash == before + expected)
	assert(not flow:ClaimOfflineCash(player).Status)
end
-- Exercise the real stamina service when rebirth keeps or resets progression.
deps.Config = luau.load(fs.readFile("src/shared/replicatedStorage/GameConfiguration/Economy/staminaUpgradeConfig.luau"))()
local stamina = load("src/shared/serverStorage/services/staminaUpgradeService/init.luau")
stamina.DataService = data
service.StaminaUpgradeService = stamina
deps.Config = Config
reset()
values.Speed = 10000
values.StaminaLevel, values.StaminaConsumptionRate = 4, 4
assert(service:apply(player, false).Status)
assert(values.StaminaLevel == 4 and values.StaminaConsumptionRate == 4)
Config.Reset.StaminaLevel = 1
reset()
values.Speed = 10000
values.StaminaLevel, values.StaminaConsumptionRate = 4, 4
assert(service:apply(player, false).Status)
assert(values.StaminaLevel == 1 and values.StaminaConsumptionRate == 1)
Config.Reset.StaminaLevel = false

print(
	"Rebirth formula, migration, eligibility, reset, paid skip, receipt deduplication, retained credit, cash scope and offline income checks passed."
)
