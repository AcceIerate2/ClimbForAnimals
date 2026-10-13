-- Run from the project root: lune run tests/animal-selling.luau
local fs = require("@lune/fs")
local luau = require("@lune/luau")

local player = { UserId = 1 }
local stranger = { UserId = 2 }
local profiles = {
	[player] = { Inventory = {}, EquippedAnimals = {}, Cash = 0, CashMultiplier = 3, AllTimeCashMultiplier = 2 },
	[stranger] = { Inventory = {}, EquippedAnimals = {}, Cash = 0, CashMultiplier = 1, AllTimeCashMultiplier = 1 },
}
local deps = {
	EggConfig = { Variants = { { Name = "Normal" }, { Name = "Golden" }, { Name = "Diamond" }, { Name = "Ruby" } } },
	knit = {
		CreateService = function(value)
			return value
		end,
		CreateSignal = function()
			return { Fire = function() end }
		end,
	},
	EarningCurve = {
		GetCashPerSecond = function(name, scale, variant)
			local base = ({ Dog = 10, Cat = 20 })[name] or 0
			return base * (scale or 1) * (variant == "Golden" and 1.5 or 1)
		end,
	},
	RebirthConfig = {
		ForSource = function(value)
			return value or 1
		end,
	},
	NumberShortner = tostring,
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
local function load(path)
	local source = fs.readFile(path)
	luau.compile(source)
	source = source:gsub("local ([%w_]+) = require%([^\n]+%)", "local %1 = Dependencies.%1")
	return luau.load(
		source,
		{
			environment = {
				Dependencies = deps,
				game = {
					GetService = function()
						return {}
					end,
				},
				warn = function() end,
			},
		}
	)()
end
local data = {}
function data:GetProfile(who)
	return profiles[who]
end
function data:GetValue(who, key)
	return profiles[who][key]
end
function data:GetValueObject(who, key)
	return {
		Get = function()
			return profiles[who][key]
		end,
		Set = function(_, value)
			profiles[who][key] = value
		end,
	}
end
local cash = load("src/shared/serverStorage/services/cashService/init.luau")
cash.DataService = data
deps.SellConfig = load("src/shared/replicatedStorage/GameConfiguration/Economy/animalSellConfig.luau")
deps.FuseConfig = load("src/shared/replicatedStorage/GameConfiguration/Gameplay/fuseConfig.luau")
local selling = load("src/shared/serverStorage/services/animalSellService/init.luau")
selling.DataService = data
selling.CashService = cash
local active = true
selling.ProfileStoreService = {
	getProfile = function()
		return {
			IsActive = function()
				return active
			end,
		}
	end,
}
local revealing = {}
selling.EggHatchService = {
	IsRevealing = function(_, _, id)
		return revealing[id] == true
	end,
}
local removed, income = {}, {}
selling.AnimalService = {
	Profiles = { [player] = true, [stranger] = true },
	RemoveAnimal = function(_, who, id)
		assert(profiles[who].Inventory[id].Handler == "Animal", "Never remove eggs")
		profiles[who].Inventory[id] = nil
		profiles[who].EquippedAnimals[id] = nil
		income[id] = nil
		table.insert(removed, id)
	end,
}
local function request(who, action, id)
	selling.LastRequest[who] = nil
	return selling:Request(who, action, id)
end
local dog = { Name = "Dog", Handler = "Animal", CustomData = { AssetScale = 2, Variant = "Golden" } }
local cat = { Name = "Cat", Handler = "Animal", CustomData = {} }
local egg = { Name = "Dog", Handler = "Egg" }
profiles[player].Inventory = { dog = dog, cat = cat, egg = egg }
profiles[player].EquippedAnimals.dog = true
income.dog = true
assert(deps.SellConfig.GetQuote(egg, 3, 2) == nil)
assert(deps.SellConfig.GetQuote(dog, 3, 2).Income == 180)
assert(deps.SellConfig.GetQuote(dog, 3, 2).Price == 1800)
assert(not request(player, "Sell", "egg").Status)
assert(not request(stranger, "Sell", "dog").Status)
assert(not request(player, "Sell", {}).Status)
assert(not request(player, "Invalid").Status)
assert(#removed == 0 and profiles[player].Cash == 0)

revealing.dog = true
assert(not request(player, "SellAll").Status)
assert(#removed == 0, "Validate the entire batch before any removal")
revealing.dog = nil
active = false
assert(not request(player, "Sell", "dog").Status)
active = true
local result = request(player, "Sell", "dog")
assert(result.Status and result.Amount == 1800 and result.Name == "Dog")
assert(profiles[player].Cash == 1800, "Sale price must not receive multipliers twice")
assert(not profiles[player].Inventory.dog and not profiles[player].EquippedAnimals.dog and not income.dog)
assert(not request(player, "Sell", "dog").Status)
assert(profiles[player].Cash == 1800)
profiles[player].Inventory.dog = dog
profiles[player].EquippedAnimals.dog = true
income.dog = true
result = request(player, "SellAll")
assert(result.Status and result.Count == 2 and result.Amount == 3000)
assert(profiles[player].Cash == 4800 and profiles[player].Inventory.egg == egg)
assert(next(profiles[player].EquippedAnimals) == nil and next(income) == nil)
assert(not request(player, "SellAll").Status)
assert(profiles[player].Cash == 4800)

-- The panel's total and row order use exactly the same quotes as the server.
deps.Row = {
	Create = function()
		return { Frame = {} }
	end,
	Update = function(row, item, plot, quote, pending)
		row.Item, row.Plot, row.Quote, row.Pending = item, plot, quote, pending
	end,
	Destroy = function(row)
		row.Destroyed = true
	end,
}
local panel = load("src/client/playerScripts/userInterface/setup/panels/sellAnimalsPanel/init.luau")
panel.Ready = true
panel.Frame = { Visible = true }
panel.Controller = { Pending = false }
panel.Header, panel.SellAll = {}, {}
panel.Data = {
	Inventory = { dog = dog, cat = cat, egg = egg },
	EquippedAnimals = { dog = true },
	CashMultiplier = 3,
	AllTimeCashMultiplier = 2,
}
panel:update()
assert(panel.Header.Text == "SELL ALL ANIMALS FOR $3000")
assert(
	panel.Rows.dog.Frame.LayoutOrder == 1
		and panel.Rows.cat.Frame.LayoutOrder == 2
		and panel.Rows.egg.Frame.LayoutOrder == 3
)
assert(panel.Rows.dog.Plot and not panel.Rows.cat.Plot and panel.Rows.egg.Quote == nil)
panel.Data.Inventory.dog = nil
panel:update()
assert(panel.Header.Text == "SELL ALL ANIMALS FOR $1200" and not panel.Rows.dog)
panel.Controller.Pending = true
panel:update()
assert(not panel.SellAll.Interactable and panel.Rows.cat.Pending)

-- Reserved fusion inputs are excluded from individual sales, Sell All, and UI totals.
profiles[player].Inventory = { dog = dog, cat = cat }
profiles[player].Fuse = { Slots = { ["1"] = "dog" } }
assert(not request(player, "Sell", "dog").Status)
result = request(player, "SellAll")
assert(result.Status and result.Count == 1 and result.Amount == 1200)
assert(profiles[player].Inventory.dog and not profiles[player].Inventory.cat)
panel.Data.Inventory = { dog = dog, cat = cat }
panel.Data.Fuse = profiles[player].Fuse
panel:update()
assert(panel.Rows.dog.Quote == nil and panel.Header.Text == "SELL ALL ANIMALS FOR $1200")

print(
	"Animal sale ownership, egg rejection, price multipliers, duplicate protection, sell-all and UI totals/order passed."
)
