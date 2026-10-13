-- Run with: lune run tests/fusing.luau
local fs = require("@lune/fs")
local luau = require("@lune/luau")
local now = 1000
local events = {}
local deps = {
	EggConfig = { Variants = { { Name = "Normal" }, { Name = "Golden" }, { Name = "Diamond" }, { Name = "Ruby" } } },
	knit = {
		CreateService = function(value)
			return value
		end,
		CreateSignal = function()
			return {
				Fire = function(_, ...)
					table.insert(events, { ... })
				end,
			}
		end,
	},
	EggHandler = {
		GetAnimalTemplate = function()
			return true
		end,
	},
}
local guid = 0
local function load(path)
	local source = fs.readFile(path)
	luau.compile(source)
	source = source:gsub("local ([%w_]+) = require%([^\n]+%)", "local %1 = Dependencies.%1")
	return luau.load(
		source,
		{
			environment = {
				Dependencies = deps,
				os = {
					time = function()
						return now
					end,
					clock = function()
						return now
					end,
				},
				game = {
					GetService = function(_, name)
						return name == "HttpService"
								and {
									GenerateGUID = function()
										guid += 1
										return tostring(guid)
									end,
								}
							or {}
					end,
				},
			},
		}
	)()
end
deps.Config = load("src/shared/replicatedStorage/GameConfiguration/Gameplay/fuseConfig.luau")
local config = deps.Config
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
local function animal(name, variant, scale)
	return {
		Name = name or "Dog",
		Handler = "Animal",
		CustomData = { Variant = variant or "Normal", AssetScale = scale or 1 },
	}
end
local player = {
	FindFirstChild = function()
		return {}
	end,
}
local values
local tools
local revealing = {}
local data = {
	GetProfile = function()
		return values
	end,
	GetValue = function(_, _, key)
		return copy(values[key])
	end,
	GetValueObject = function(_, _, key)
		return {
			Set = function(_, value)
				values[key] = copy(value)
			end,
		}
	end,
}
local function service()
	local result = load("src/shared/serverStorage/services/fuseService/init.luau")
	result.DataService = data
	result.ProfileStoreService = {
		getProfile = function()
			return {
				IsActive = function()
					return true
				end,
			}
		end,
	}
	result.AnimalService = {
		Profiles = { [player] = true },
		UnEquipAnimal = function(_, _, reference)
			values.EquippedAnimals[reference] = nil
			return { Status = true }
		end,
	}
	result.InventoryService = {
		RemoveTool = function(_, _, reference)
			tools[reference] = nil
		end,
		StoreInBackpack = function(_, _, reference)
			tools[reference] = true
		end,
	}
	result.EggHatchService = {
		IsRevealing = function(_, _, reference)
			return revealing[reference]
		end,
	}
	result.IndexService = { Discover = function() end }
	return result
end
local function reset()
	values = {
		Inventory = {
			a = animal(nil, nil, 1),
			b = animal(nil, nil, 2),
			c = animal(nil, nil, 3),
			cat = animal("Cat"),
			golden = animal(nil, "Golden"),
			ruby = animal(nil, "Ruby"),
			egg = { Handler = "Egg" },
		},
		Fuse = { Slots = {} },
		EquippedAnimals = { a = true },
	}
	tools = { a = true, b = true, c = true }
	return service()
end
local fuse = reset()
assert(config.GetNextVariant("Normal") == "Golden" and config.GetNextVariant("Golden") == "Diamond")
assert(config.GetNextVariant("Diamond") == "Ruby" and config.GetNextVariant("Ruby") == nil)
assert(not fuse:setSlot(player, 0 / 0, "a").Status)
assert(not fuse:setSlot(player, 4, "a").Status)
assert(not fuse:setSlot(player, 1, "not-owned").Status)
assert(not fuse:setSlot(player, 1, "egg").Status)
assert(not fuse:setSlot(player, 1, "ruby").Status)
revealing.a = true
assert(not fuse:setSlot(player, 1, "a").Status)
revealing.a = nil
assert(fuse:setSlot(player, 1, "a").Status)
assert(not values.EquippedAnimals.a and not tools.a and values.Inventory.a)
assert(not fuse:setSlot(player, 2, "a").Status)
assert(not fuse:setSlot(player, 2, "cat").Status)
assert(not fuse:setSlot(player, 2, "golden").Status)
assert(fuse:setSlot(player, 2, "b").Status)
assert(not values.Fuse.FinishAt)
assert(fuse:setSlot(player, 3, "c").Status)
assert(values.Fuse.FinishAt == now + 600)
local result = config.GetResult(values.Fuse, values.Inventory)
assert(math.abs(result.CustomData.AssetScale ^ 3 - 12) < 0.0001, "Average actual weight, not linear scale")
now += 100
assert(fuse:setSlot(player, 2, nil).Status)
assert(not values.Fuse.FinishAt and tools.b)
assert(fuse:setSlot(player, 2, "b").Status)
assert(values.Fuse.FinishAt == now + 600, "Removal must reset the entire timer")
assert(not fuse:complete(player, copy(values.Fuse)))
-- Rejoin another server after the deadline, keeping the saved profile state.
now += 650
fuse = service()
assert(fuse:complete(player, copy(values.Fuse)))
assert(not values.Inventory.a and not values.Inventory.b and not values.Inventory.c)
assert(next(values.Fuse.Slots) == nil and values.Inventory.Dog_1.CustomData.Variant == "Golden")
assert(tools.Dog_1 and #events == 1)
assert(not fuse:complete(player, copy(values.Fuse)) and #events == 1, "Only one reward per job")
-- Optional pause mode preserves remaining time, but emptying all slots clears it.
fuse = reset()
for index, reference in { "a", "b", "c" } do
	assert(fuse:setSlot(player, index, reference).Status)
end
config.ResetOnRemoval = false
now += 100
fuse:setSlot(player, 1, nil)
assert(values.Fuse.Remaining == 500)
now += 100
fuse:setSlot(player, 1, "a")
assert(values.Fuse.FinishAt == now + 500)
for index = 1, 3 do
	fuse:setSlot(player, index, nil)
end
assert(values.Fuse.Remaining == nil)
config.ResetOnRemoval = true
-- A reset/removal elsewhere must never produce a free fused animal.
fuse = reset()
for index, reference in { "a", "b", "c" } do
	fuse:setSlot(player, index, reference)
end
values.Inventory.b = nil
now += 601
assert(not fuse:complete(player, copy(values.Fuse)))
assert(values.Inventory.a and values.Inventory.c and not values.Fuse.FinishAt)
-- Malformed input scales cannot grant a non-finite output.
values.Inventory.b = animal(nil, nil, math.huge)
values.Fuse.Slots["2"] = "b"
assert(not config.GetResult(values.Fuse, values.Inventory))
for _, path in
	{
		"src/client/playerScripts/controllers/fuseController/init.luau",
		"src/client/playerScripts/userInterface/setup/panels/fusePanel/init.luau",
		"src/client/playerScripts/userInterface/setup/panels/fusePanel/row.luau",
		"src/client/playerScripts/userInterface/buttons/TypeFunctions/Action/fuseAction.luau",
		"src/client/playerScripts/userInterface/buttons/TypeFunctions/Action/init.luau",
		"src/shared/serverStorage/services/animalService/init.luau",
		"src/shared/serverStorage/services/inventoryService/init.luau",
		"src/shared/serverStorage/services/animalSellService/init.luau",
		"src/client/playerScripts/userInterface/setup/panels/sellAnimalsPanel/init.luau",
		"src/shared/serverStorage/services/profileStoreService/config.luau",
	}
do
	luau.compile(fs.readFile(path))
end
print("Fusion validation, reservation, reset/pause, offline completion, and duplicate-reward checks passed")
