-- Run with: lune run tests/treadmill-prompts.luau
local fs = require("@lune/fs")
local luau = require("@lune/luau")
local roblox = require("@lune/roblox")
local controllerPath = "src/client/playerScripts/controllers/treadmillController/init.luau"
local uiPath = "src/client/playerScripts/userInterface/setup/general/treadmillMultiplier/init.luau"
local source = fs.readFile(controllerPath)
local method = assert(source:match("function TreadmillController:IsCurrentTreadmillSession.-\nend"))
local controller = luau.load("local TreadmillController = {}\n" .. method .. "\nreturn TreadmillController")()
controller.OnTreadmill = true
controller.TreadmillSession = "ride1"
local callbacks = {}
local function signal(name)
	return {
		Connect = function(_, callback)
			callbacks[name] = callback
		end,
	}
end
controller.Signals = { TreadmillDeactivated = signal("stop"), ShowMultiplierButton = signal("show") }
local clones = {}
local linked = {}
local duringLink
local buttons = {
	Link = function(_, button)
		linked[button] = true
		if duringLink then
			duringLink()
		end
	end,
	Unlink = function(_, button)
		linked[button] = nil
	end,
}
local template = {
	Size = roblox.UDim2.fromScale(1, 1),
	Clone = function()
		local button = { AddTag = function() end, SetAttribute = function() end }
		local frame = {
			WaitForChild = function()
				return button
			end,
			FindFirstChildOfClass = function()
				return button
			end,
			Destroy = function(self)
				self.Destroyed = true
				self.Parent = nil
			end,
		}
		table.insert(clones, frame)
		return frame
	end,
}
local container = {
	WaitForChild = function()
		return template
	end,
}
local player = { PlayerGui = {
	WaitForChild = function()
		return container
	end,
} }
local deps = {
	knit = {
		GetController = function(name)
			return name == "ButtonsController" and buttons or controller
		end,
	},
	Spring = { target = function() end },
	PlayTween = function() end,
}
local uiSource = fs.readFile(uiPath):gsub("local ([%w_]+) = require%([^\n]+%)", "local %1 = Dependencies.%1")
local ui = luau.load(
	uiSource,
	{
		environment = {
			Dependencies = deps,
			game = {
				GetService = function()
					return {}
				end,
			},
			UDim2 = roblox.UDim2,
			Enum = roblox.Enum,
			TweenInfo = {
				new = function()
					return {}
				end,
			},
		},
	}
)()
ui:Init(player)
callbacks.show("bonus1", "ride1")
assert(#ui.BonusFrames == 1 and clones[1].Parent == container)
controller.OnTreadmill = false
controller.TreadmillSession = nil
callbacks.stop()
assert(clones[1].Destroyed and #ui.BonusFrames == 0 and next(linked) == nil)
callbacks.show("late", "ride1")
assert(#clones == 1, "Prompt arriving after cleanup must not create a button")
controller.OnTreadmill = true
controller.TreadmillSession = "ride2"
callbacks.show("old", "ride1")
assert(#clones == 1, "Old ride prompt must not enter a new ride")
duringLink = function()
	controller.OnTreadmill = false
	controller.TreadmillSession = nil
	callbacks.stop()
end
callbacks.show("interrupted", "ride2")
assert(
	clones[2].Destroyed and clones[2].Parent == nil and #ui.BonusFrames == 0 and next(linked) == nil,
	"Leaving during button setup must dispose of the unpublished button"
)
for _, path in { controllerPath, uiPath, "src/shared/serverStorage/services/treadmillService/init.luau" } do
	luau.compile(fs.readFile(path))
end
print("Treadmill prompt race checks passed")
