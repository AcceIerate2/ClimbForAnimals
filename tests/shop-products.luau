-- Run from the project root: lune run tests/shop-products.luau
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

local values = {
	Cash = 0,
	CashMultiplier = 3,
	AllTimeCashMultiplier = 1,
	HatchSpeedMultiplier = 1,
	PurchaseHistory = {},
	PlacedEggs = {},
}
local player = { Name = "Test", UserId = 1, Parent = true, Attributes = {} }
function player:SetAttribute(key, value)
	self.Attributes[key] = value
end
local data = {}
function data:GetProfile()
	return values
end
function data:GetValue(_, key)
	return values[key]
end
function data:GetValueObject(_, key)
	return {
		Get = function()
			return values[key]
		end,
		Set = function(_, value)
			values[key] = value
		end,
		Update = function(_, fn)
			local saved = copy(values[key])
			fn(saved)
			values[key] = saved
		end,
	}
end

local services = {}
local config = luau.load(fs.readFile("src/shared/replicatedStorage/GameConfiguration/Economy/rebirthConfig.luau"))()
local deps = {
	knit = {
		CreateService = function(def)
			return def
		end,
		GetService = function(name)
			return services[name]
		end,
		CreateSignal = function()
			return { Fire = function() end }
		end,
	},
	RebirthConfig = config,
	TypeCheck = {
		Instance = function()
			return true
		end,
		string = function(v)
			return type(v) == "string"
		end,
		number = function(v)
			return type(v) == "number"
		end,
	},
	SafeFunctionCaller = pcall,
	EggHandler = {
		GetHatchDuration = function()
			return 100
		end,
	},
	eggConfig = { Eggs = { Egg = {} } },
}
local now = 1000
local profile = { LastSavedData = {} }
function profile:IsActive()
	return true
end
function profile:Save()
	self.LastSavedData = copy(values)
end
local function load(path, replacements)
	local source = fs.readFile(path)
	luau.compile(source)
	source = source:gsub("local ([%w_]+) = require%([^\n]+%)", "local %1 = Dependencies.%1")
	for before, after in pairs(replacements or {}) do
		source = source:gsub(before, after)
	end
	return luau.load(source, {
		environment = {
			Dependencies = deps,
			game = {
				GetService = function(_, name)
					if name == "Players" then
						return {
							GetPlayerByUserId = function()
								return player
							end,
						}
					end
					return {}
				end,
			},
			os = {
				time = function()
					return now
				end,
				clock = os.clock,
			},
			workspace = {
				GetServerTimeNow = function()
					return now
				end,
			},
			Enum = { ProductPurchaseDecision = { PurchaseGranted = "Granted", NotProcessedYet = "Retry" } },
		},
	})()
end

local cash = load("src/shared/serverStorage/services/cashService/init.luau")
cash.DataService = data
services.CashService = cash
services.DataService = data

local grow = load("src/shared/serverStorage/services/eggGrowService/init.luau")
grow.DataService = data
grow.getPlayerBase = function()
	return true
end
grow.getEggAsset = function()
	return {}
end
local delays = {}
grow.connectTimer = function(_, _, seconds)
	table.insert(delays, seconds)
	local timer = { cancel = function() end }
	timer.andThen = function(self)
		return self
	end
	timer.catch = function(self)
		return self
	end
	return timer
end
services.EggGrowService = grow
local passes = load("src/shared/serverStorage/services/monetizationService/passIds.luau")
passes[3713831694].Grant(player)
passes[3713831694].Grant(player)
assert(values.AllTimeCashMultiplier == 2 and values.CashMultiplier == 3)
assert(player.Attributes.AllTimeCashMultiplier == 2)

values.PlacedEggs.Egg_a = { PlaceDate = 980, CanHatch = false }
grow:ConnectEgg(player, "Egg_a")
assert(delays[#delays] == 80)
passes[3713831619].Grant(player)
assert(delays[#delays] == 40 and values.PlacedEggs.Egg_a.HatchDuration == 50)
local deadline = values.PlacedEggs.Egg_a.HatchDate
passes[3713831619].Grant(player)
assert(values.PlacedEggs.Egg_a.HatchDate == deadline) -- ownership checks do not compound
now += 10
grow:ConnectEgg(player, "Egg_a")
assert(delays[#delays] == 30) -- persisted deadline survives reconnection
values.PlacedEggs.Egg_b = { PlaceDate = now, CanHatch = false }
grow:ConnectEgg(player, "Egg_b")
assert(delays[#delays] == 50)

deps.products = load("src/shared/serverStorage/services/monetizationService/productIds.luau")
deps.passes = passes
local monetization = load("src/shared/serverStorage/services/monetizationService/init.luau", {
	["require%(script.productIds%)"] = "Dependencies.products",
	["require%(script.passIds%)"] = "Dependencies.passes",
})
monetization.DataService = data
monetization.CashService = cash
monetization.ProfileStoreService = {
	getProfile = function()
		return profile
	end,
}
services.MonetizationService = monetization
local notices = 0
monetization.Client.UserPurchased.Fire = function()
	notices += 1
end
local ids = { 3713831826, 3713831881, 3713831956, 3713831998, 3713832029 }
local amounts = { 3000, 40000, 250000, 1500000, 5000000 }
config.CashSources.OtherRewards = true
for index, id in ipairs(ids) do
	local receipt = { ProductId = id, PurchaseId = tostring(id), PlayerId = 1 }
	local before = values.Cash
	assert(monetization:processReceipt(receipt) == "Granted")
	assert(values.Cash == before + amounts[index]) -- packs bypass both multipliers
	assert(profile.LastSavedData.Cash == values.Cash)
	assert(monetization:processReceipt(receipt) == "Granted")
	assert(values.Cash == before + amounts[index])
end
assert(notices == 5)
local before = values.Cash
cash:ManipulatePlayerCash(player, 100, "Addition")
assert(values.Cash == before + 600)
cash:ManipulatePlayerCash(player, -100, "Addition")
assert(values.Cash == before + 500)
cash:ManipulatePlayerCash(player, 600, "Addition", nil, "SettledIncome")
assert(values.Cash == before + 1100)
print(
	"Pass idempotency, hatch progress/deadlines, all five cash receipts, duplicate prevention, notifications and multiplier exclusions passed."
)

-- The shop catalog publishes only display data, and ownership updates follow grants.
local ownedNotice
monetization.Client.PassOwned.Fire = function(_, buyer, id)
	assert(buyer == player)
	ownedNotice = id
end
monetization:gamepassPurchaseHandler(player, 3713831694, false)
assert(ownedNotice == 3713831694)
monetization:gamepassPurchaseHandler(player, 3713831619, true)
local catalog = monetization:GetShopCatalog(player)
assert(#catalog == 7)
local byKey = {}
for _, item in ipairs(catalog) do
	byKey[item.Key] = item
	for _, value in pairs(item) do
		assert(type(value) ~= "function")
	end
end
assert(byKey.Cash2x.Owned and byKey.Hatch2x.Owned)
assert(byKey.Cash2x.PurchaseType == "GamePass")
for index, id in ipairs(ids) do
	local item = byKey["cashProduct" .. index]
	assert(item.Id == id and item.CashAmount == amounts[index])
	assert(item.PurchaseType == "Product" and not item.Owned)
end
print("Shop catalog IDs, amounts, ownership and live grant notifications passed.")
