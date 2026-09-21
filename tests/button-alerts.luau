local fs = require("@lune/fs")
local luau = require("@lune/luau")
local roblox = require("@lune/roblox")

local config = luau.load(fs.readFile("src/shared/replicatedStorage/GameConfiguration/Economy/rebirthConfig.luau"))()
local source = fs.readFile("src/client/playerScripts/controllers/buttonAlertsController/init.luau")
luau.compile(source)
source = source:gsub("local ([%w_]+) = require%([^\n]+%)", "local %1 = Dependencies.%1")
local controller = luau.load(source, {
	environment = {
		Dependencies = {
			knit = {
				CreateController = function(value)
					return value
				end,
			},
			RebirthConfig = config,
		},
		game = {
			GetService = function()
				return {}
			end,
		},
		Color3 = roblox.Color3,
	},
})()
local shown, notifications = {}, {}
controller.ButtonsController = {
	IncrementButtonAlerts = function(_, name)
		shown[name] = true
	end,
	ClearButtonAlerts = function(_, name)
		shown[name] = false
	end,
}
controller.NotificationController = {
	Push = function(_, data)
		table.insert(notifications, data)
	end,
}
for _, name in { "Index", "Shop", "Rebirth", "Animals", "Eggs" } do
	controller.Buttons[name] = name
end

controller:updateInventory({ old = { Handler = "Animal" } }, true)
assert(not shown.Animals, "Existing inventory must not be treated as newly acquired")
controller:updateInventory({ old = { Handler = "Animal" }, a = { Handler = "Animal" }, e = { Handler = "Egg" } })
assert(shown.Animals and shown.Eggs)
controller:acknowledge("Animals")
assert(not shown.Animals and shown.Eggs)
controller:updateInventory({ old = { Handler = "Animal" }, a = { Handler = "Animal" }, e = { Handler = "Egg" } })
assert(not shown.Animals, "Unchanged inventory must not re-alert")
controller.Open.Animals = true
controller:updateInventory({ b = { Handler = "Animal" } })
assert(not shown.Animals and not shown.Eggs)
controller:updateEggs({ e = { CanHatch = false } }, true)
assert(not shown.Eggs)
controller:updateEggs({ e = { CanHatch = true } })
assert(shown.Eggs)
controller:acknowledge("Eggs")
controller:updateEggs({ e = { CanHatch = true } })
assert(not shown.Eggs, "Acknowledged hatch readiness must not re-alert")
controller:updateEggs({ e = { CanHatch = true }, e2 = { CanHatch = true } })
assert(shown.Eggs)
controller:updateEggs({})
assert(not shown.Eggs)
controller:updateEggs({ placed = { CanHatch = false } })
assert(shown.Eggs, "Newly placed eggs should alert before hatch readiness")
controller:updateInventory({})
assert(shown.Eggs, "Moving an egg out of inventory onto the plot must preserve its alert")
controller:acknowledge("Eggs")
controller:updateIndex({ Discovered = { Dog = true, Cat = true }, Claimed = { Dog = true } })
assert(shown.Index)
controller:updateIndex({ Discovered = { Dog = true, Cat = true }, Claimed = { Dog = true, Cat = true } })
assert(not shown.Index)
controller:setAlert("Shop", true)
controller:acknowledge("Shop")
assert(not shown.Shop)

local required = config.GetRequirements(0).Speed
controller.Data = { Rebirths = 0, Speed = required - 1 }
controller:updateRebirth()
assert(not shown.Rebirth and #notifications == 0)
controller.Data.Speed = required
controller:updateRebirth()
assert(shown.Rebirth and #notifications == 1 and notifications[1].Message == "You can rebirth now!")
assert(notifications[1].Color == roblox.Color3.fromRGB(210, 170, 255))
controller:updateRebirth()
assert(#notifications == 1, "Repeated eligible updates must not spam notifications")
controller.Data.Rebirths, controller.Data.Speed = 1, 250
controller:updateRebirth()
assert(not shown.Rebirth)
controller.Data.Speed = config.GetRequirements(1).Speed
controller:updateRebirth()
assert(shown.Rebirth and #notifications == 2)
config.MaxRebirths = 1
controller:updateRebirth()
assert(not shown.Rebirth)
config.MaxRebirths, config.Enabled = 0, false
controller:updateRebirth()
assert(not shown.Rebirth)

local alerts = luau.load(fs.readFile("src/client/playerScripts/userInterface/buttons/alerts/init.luau"))()
local badge = {
	Visible = false,
	IsA = function(_, class)
		return class == "GuiObject"
	end,
}
local frame = {
	FindFirstChild = function(_, name)
		return name == "Alert" and badge or nil
	end,
}
local button = {
	Parent = frame,
	FindFirstChild = function()
		return nil
	end,
}
alerts:manipulate(button, 999)
assert(badge.Visible)
alerts:clear(button)
assert(not badge.Visible)
alerts:clear({
	FindFirstChild = function()
		return nil
	end,
})
luau.compile(fs.readFile("src/client/playerScripts/userInterface/buttons/init.luau"))
print("Image alerts, inventory changes, hatch readiness, claims, shop dismissal and rebirth eligibility checks passed.")
