-- Run with: lune run tests/tutorial.luau
local fs = require("@lune/fs")
local luau = require("@lune/luau")
local roblox = require("@lune/roblox")
local V, C = roblox.Vector3, roblox.CFrame
local config = luau.load(fs.readFile("src/shared/replicatedStorage/GameConfiguration/Gameplay/tutorialConfig.luau"))()
local now = 100
local deps = {
	Location = {
		GetBiome = function(position)
			return math.abs(position.X) >= 25
					and math.abs(position.X) <= 80
					and math.abs(position.Y - 100) <= 10
					and "Forest"
				or nil
		end,
	},
	Targets = luau.load(fs.readFile("src/shared/replicatedStorage/utility/tutorialTargets.luau"), {
		environment = { Vector3 = V },
	})(),
	Config = config,
	TutorialConfig = config,
	NumberShortner = tostring,
	knit = {
		CreateService = function(value)
			return value
		end,
	},
}
local function part(x, y)
	return {
		Position = V.new(x, y, 0),
		CFrame = C.new(x, y, 0),
		Size = V.one,
		AssemblyLinearVelocity = V.zero,
		IsA = function(_, class)
			return class == "BasePart"
		end,
	}
end
local parts = { Climb = part(0, 0), Zone = part(0, 100), PlatformLeft = part(-40, 100), PlatformRight = part(40, 100) }
local root = part(0, 0)
local humanoid = { Health = 100, FloorMaterial = roblox.Enum.Material.Grass }
local movementState = roblox.Enum.HumanoidStateType.Running
function humanoid:GetState()
	return movementState
end
local player = { Carrying = nil }
function player:FindFirstChild(name)
	return name == "Synced"
end
function player:GetAttribute(name)
	return name == "CarryingEgg" and self.Carrying or nil
end
player.Character = {
	GetAttribute = function(_, name)
		return name == "GuardStunned" and player.Stunned or nil
	end,
	HasTag = function()
		return false
	end,
	FindFirstChild = function()
		return root
	end,
	FindFirstChildOfClass = function()
		return humanoid
	end,
}
local function load(path)
	local source = fs.readFile(path)
	luau.compile(source)
	source = source:gsub("local ([%w_]+) = require%([^\n]+%)", "local %1 = Dependencies.%1")
	return luau.load(source, {
		environment = {
			Dependencies = deps,
			Enum = roblox.Enum,
			Vector3 = V,
			game = {
				GetService = function()
					return {}
				end,
			},
			workspace = {
				GetServerTimeNow = function()
					return now
				end,
				FindFirstChild = function()
					return {
						FindFirstChild = function(_, key)
							return parts[key]
						end,
					}
				end,
			},
		},
	})()
end
local values
local data = {
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
			Update = function(_, callback)
				callback(values[key])
			end,
		}
	end,
}
local function service()
	local result = load("src/shared/serverStorage/services/tutorialService/init.luau")
	result.DataService = data
	result.TutorialFunnelService = {
		Track = function()
			return false
		end,
	}
	result.EggHatchService = { PendingHatches = {} }
	result.TreadmillService = { Connections = {} }
	result.BaseService = {
		GetPlayerBase = function()
			return {
				FindFirstChild = function()
					return part(0, 0)
				end,
			}
		end,
	}
	return result
end
local tutorial = service()
local waypoints = tutorial:GetWaypoints()
assert(waypoints.Climb == parts.Climb.CFrame and waypoints.Zone == parts.Zone.CFrame)
assert(waypoints.Left == parts.PlatformLeft.CFrame and waypoints.Right == parts.PlatformRight.CFrame)
-- Run the progression with actual CFrameValue markers, not just physical Parts.
for name, marker in pairs(parts) do
	local value = roblox.Instance.new("CFrameValue")
	value.Name = name
	value.Value = marker.CFrame
	parts[name] = value
end
local valueWaypoints = tutorial:GetWaypoints()
assert(#valueWaypoints.Errors == 0 and valueWaypoints.Climb == C.new(0, 0, 0))
assert(valueWaypoints.Left == C.new(-40, 100, 0) and valueWaypoints.Right == C.new(40, 100, 0))
values = {
	Tutorial = { Initialized = false, Step = "Climb", FreeStaminaUsed = false },
	JoinedBefore = false,
	Inventory = {},
	PlacedEggs = {},
	StaminaLevel = 1,
	TreadmillLevel = 0,
	Cash = 0,
}
tutorial:update(player, 0.5)
assert(values.Tutorial.Initialized and values.Tutorial.Step == "Climb")
root.Position = V.new(0, 30, 0)
tutorial:update(player, 0.5)
assert(values.Tutorial.Step == "Ascend")
-- Both platform approaches work outside the Zone and biome, while airborne or
-- climbing characters cannot trigger the new grounded shortcut.
for _, x in { -23, 23 } do
	root.Position = V.new(x, 100, 0)
	values.Tutorial.Step = "Ascend"
	movementState = roblox.Enum.HumanoidStateType.Climbing
	tutorial:update(player, 0.5)
	assert(values.Tutorial.Step == "Ascend")
	movementState = roblox.Enum.HumanoidStateType.Running
	humanoid.FloorMaterial = roblox.Enum.Material.Air
	tutorial:update(player, 0.5)
	assert(values.Tutorial.Step == "Ascend")
	humanoid.FloorMaterial = roblox.Enum.Material.Grass
	player.Stunned = true
	tutorial:update(player, 0.5)
	assert(values.Tutorial.Step == "Ascend")
	player.Stunned = false
	tutorial:update(player, 0.5)
	assert(values.Tutorial.Step == "Steal", "Landing outside the guard Area should immediately guide to an egg")
	assert(values.Tutorial.Biome == config.PlatformBiome)
	for _ = 1, 6 do
		tutorial:update(player, 0.5)
		assert(values.Tutorial.Step == "Steal", "Waiting on the landing must not reset egg guidance")
	end
end
values.Tutorial.Step = "Ascend"
root.Position = V.new(0, 100, 0)
tutorial:update(player, 0.5)
assert(values.Tutorial.Step == "Platform")
for _ = 1, 4 do
	root.Position = V.new(0, 79, 0)
	tutorial:update(player, 0.5)
	assert(values.Tutorial.Step == "Platform", "Leaving the zone marker briefly must not reverse progress")
	root.Position = V.new(0, 100, 0)
	tutorial:update(player, 0.5)
	assert(values.Tutorial.Step == "Platform")
end
root.Position = V.new(40, 100, 0)
player.Stunned = true
-- Small drops on the climb must keep platform guidance even beyond the exit timer.
root.Position = V.new(0, 60, 0)
for _ = 1, 6 do
	tutorial:update(player, 0.5)
end
assert(values.Tutorial.Step == "Platform")
player.Stunned = false
for _ = 1, 6 do
	tutorial:update(player, 0.5)
end
assert(values.Tutorial.Step == "Platform", "Climbing lower is not returning to the lobby")
root.Position = V.new(40, 100, 0)
player.Stunned = true
tutorial:update(player, 0.5)
assert(values.Tutorial.Step == "Platform", "A stun must not complete platform arrival")
player.Stunned = false
root.AssemblyLinearVelocity = V.new(0, -50, 0)
tutorial:update(player, 0.5)
assert(values.Tutorial.Step == "Platform", "Falling through an island must not count as landing")
root.AssemblyLinearVelocity = V.zero
tutorial:update(player, 0.5)
assert(values.Tutorial.Step == "Steal", "Platform should complete on landing, without waiting for the Area timer")
tutorial:update(player, 0.5)
assert(values.Tutorial.Step == "Steal")
assert(values.Tutorial.Biome == "Forest")
for _ = 1, 4 do
	root.Position = V.new(24, 100, 0)
	tutorial:update(player, 0.5)
	assert(values.Tutorial.Step == "Steal", "An island edge crossing must not flicker the instruction")
	root.Position = V.new(40, 100, 0)
	tutorial:update(player, 0.5)
end
root.Position = V.new(200, 100, 0)
for _ = 1, 2 do
	tutorial:update(player, 0.5)
end
assert(values.Tutorial.Step == "Steal", "Wait for a confirmed exit before resetting")
tutorial:update(player, 0.5)
assert(values.Tutorial.Step == "Climb", "Matching biome height outside the island must not keep Steal active")
root.Position = V.new(40, 100, 0)
tutorial:update(player, 0.5)
tutorial:update(player, 0.5)
assert(values.Tutorial.Step == "Steal")
player.Carrying = "worldEgg"
tutorial:update(player, 0.5)
assert(values.Tutorial.Step == "Return")
player.Carrying = nil
root.Position = V.zero
tutorial:update(player, 0.5)
assert(values.Tutorial.Step == "Climb", "Lost carried eggs must not strand the tutorial")
values.Inventory.egg = { Handler = "Egg" }
tutorial:update(player, 0.5)
assert(values.Tutorial.Step == "Deposit")
values.Inventory.egg = nil
values.PlacedEggs.egg = { CanHatch = false }
tutorial:Record(player, "Deposit", "egg")
assert(values.Tutorial.Step == "Hatch")
values.JoinedBefore = true
tutorial = service() -- New server, same saved profile.
tutorial:update(player, 0.5)
assert(values.Tutorial.Step == "Hatch", "Returning players must resume initialized tutorials")
values.PlacedEggs.egg = nil
tutorial:Record(player, "Hatch", "egg")
assert(values.Tutorial.Step == "HatchReward" and values.Tutorial.Hatched)
tutorial:Record(player, "RevealComplete", "egg")
assert(values.Tutorial.Step == "Stamina", "Continue immediately after the reveal without an extra pause")
assert(config.IsFreeStamina(values.Tutorial, 1, 1))
config.FreeFirstStaminaPurchase = false
assert(not config.IsFreeStamina(values.Tutorial, 1, 1))
config.FreeFirstStaminaPurchase = true

-- Exercise the real purchase service using isolated economy rules.
deps.Config = {
	BaseLevel = 1,
	Enabled = true,
	RequestCooldown = 0.4,
	NormalizeLevel = function(level)
		return level
	end,
	GetPrice = function()
		return 100
	end,
	GetDrainInterval = function(level)
		return level
	end,
}
local stamina = load("src/shared/serverStorage/services/staminaUpgradeService/init.luau")
stamina.DataService = data
stamina.ProfileStoreService = {
	getProfile = function()
		return {
			IsActive = function()
				return true
			end,
		}
	end,
}
stamina.CashService = {
	ManipulatePlayerCash = function(_, _, amount)
		values.Cash += amount
	end,
}
local response = stamina:Purchase(player, 1)
assert(response.Status and response.Price == 0 and values.Cash == 0)
assert(values.Tutorial.FreeStaminaUsed and values.StaminaLevel == 2)
stamina.LastRequest[player] = nil
values.StaminaLevel = 1 -- Even a reset cannot reclaim the offer.
assert(not stamina:Purchase(player, 1).Status and values.Cash == 0)
values.StaminaLevel = 2
deps.Config = config
assert(not tutorial:StaminaPanelClosed(player), "Cannot skip the purchase/close step")
tutorial:update(player, 0.5)
assert(values.Tutorial.Step == "CloseStamina")
tutorial:update(player, 0.5)
assert(values.Tutorial.Step == "CloseStamina", "Must wait for the panel to close")
values.StaminaLevel = 1
assert(not tutorial:StaminaPanelClosed(player), "Dismissal cannot bypass upgrade validation")
values.StaminaLevel = 2
assert(tutorial:StaminaPanelClosed(player))
assert(values.Tutorial.Step == "Treadmill")
assert(not tutorial:StaminaPanelClosed(player), "Duplicate acknowledgements do not advance further")
values.TreadmillLevel = 1
tutorial:update(player, 0.5)
assert(values.Tutorial.Step == "Train")
tutorial:update(player, 10)
assert(not values.Tutorial.Completed, "Standing near a treadmill is insufficient")
tutorial.TreadmillService.Connections[player] = {}
for _ = 1, 6 do
	tutorial:update(player, 0.5)
end
assert(values.Tutorial.Completed and values.Tutorial.Step == "Finish")
tutorial:Record(player, "Hatch", "another")
assert(values.Tutorial.Completed)
values.Tutorial = { Initialized = false, Step = "Climb" }
tutorial:update(player, 0.5)
assert(values.Tutorial.Completed, "Old profiles are excluded by the configured migration policy")

for _, path in
	{
		"src/shared/replicatedStorage/utility/tutorialLocation.luau",
		"src/client/playerScripts/controllers/tutorialController/init.luau",
		"src/client/playerScripts/controllers/tutorialController/guidance.luau",
		"src/client/playerScripts/userInterface/setup/panels/staminaPanel/init.luau",
		"src/shared/serverStorage/services/eggPlacementService/init.luau",
		"src/shared/serverStorage/services/EggHatchService/init.luau",
		"src/shared/serverStorage/services/profileStoreService/config.luau",
		"src/client/playerScripts/controllers/uiHighlighterController/init.luau",
		"src/client/playerScripts/userInterface/setup/general/uiHighlighter/init.luau",
		"src/client/playerScripts/userInterface/setup/general/uiHighlighter/highlighterUI.luau",
	}
do
	luau.compile(fs.readFile(path))
end
-- Both platform arrows must have independent attachments originating on the character.
local guidanceSource = fs.readFile("src/client/playerScripts/controllers/tutorialController/guidance.luau")
local world = roblox.Instance.new("Folder")
local guidanceModule = luau.load(guidanceSource, {
	environment = {
		Instance = roblox.Instance,
		Enum = roblox.Enum,
		NumberSequence = roblox.NumberSequence,
		Vector3 = V,
		workspace = world,
	},
})()
local template = roblox.Instance.new("Beam")
template.FaceCamera = false
template.CurveSize0, template.CurveSize1 = 20, -20
template.TextureSpeed = -2
template.Width0, template.Width1 = 0, 0
local characterRoot = roblox.Instance.new("Part")
local guidance = guidanceModule.new(template)
guidance:Update(characterRoot, { C.new(-40, 100, 0), C.new(40, 100, 0) })
assert(#guidance.Arrows == 2)
assert(guidance.Arrows[1].Source ~= guidance.Arrows[2].Source)
for _, arrow in ipairs(guidance.Arrows) do
	assert(arrow.Beam.Attachment0.Parent == characterRoot)
	assert(arrow.Beam.Attachment1.Parent == arrow.Target)
	assert(arrow.Beam.FaceCamera and arrow.Beam.TextureSpeed < 0)
	assert(arrow.Beam.CurveSize0 == 0 and arrow.Beam.CurveSize1 == 0)
	assert(arrow.Beam.Width0 > 0 and arrow.Beam.Width1 > 0)
end
guidance:Update(characterRoot, { C.new(0, 200, 0) })
assert(#guidance.Arrows == 1 and #characterRoot:GetChildren() == 1)
guidance:Clear()
assert(#characterRoot:GetChildren() == 0 and #world:GetChildren() == 0)
local worldSource = fs.readFile("src/client/playerScripts/controllers/tutorialController/worldHighlighter.luau")
luau.compile(worldSource)
local worldModule = luau.load(worldSource, {
	environment = {
		Vector2 = roblox.Vector2,
		Vector3 = V,
		game = {
			GetService = function()
				return {}
			end,
		},
	},
})()
local projector = worldModule.new({}, 8)
local camera = {
	ViewportSize = roblox.Vector2.new(800, 600),
	WorldToViewportPoint = function(_, position)
		return V.new(400 + position.X, 300 - position.Y, position.Z)
	end,
}
local screenPosition, screenSize = projector:GetRectangle(camera, C.new(0, 0, 20), V.new(20, 10, 2))
assert(screenPosition == roblox.Vector2.new(390, 295) and screenSize == roblox.Vector2.new(20, 10))
assert(projector:GetRectangle(camera, C.new(0, 0, -20), V.new(20, 10, 2)) == nil)
assert(projector:GetRectangle(camera, C.new(1000, 0, 20), V.new(20, 10, 2)) == nil)

-- Button and overlay positions share Core UI coordinates; subtract the overlay origin once.
local uiSource = fs.readFile("src/client/playerScripts/userInterface/setup/general/uiHighlighter/init.luau")
uiSource = uiSource:gsub("local ([%w_]+) = require%([^\n]+%)", "local %1 = Dependencies.%1")
uiSource = uiSource:gsub("require%(script.highlighterUI%)", "nil")
local uiModule = luau.load(uiSource, {
	environment = {
		Dependencies = {},
		Enum = roblox.Enum,
		Vector2 = roblox.Vector2,
		UDim2 = roblox.UDim2,
		game = {
			GetService = function(_, name)
				if name == "GuiService" then
					return {
						GetInsetArea = function(_, inset)
							assert(inset == roblox.Enum.ScreenInsets.DeviceSafeInsets)
							return { Min = roblox.Vector2.new(0, -58) }
						end,
					}
				end
				return {}
			end,
		},
	},
})()
local frames = { Placeholder = {}, Left = {}, Right = {}, Top = {}, Bottom = {} }
local overlay = {
	AbsolutePosition = roblox.Vector2.new(-20, -58),
	AbsoluteSize = roblox.Vector2.new(800, 600),
	FindFirstChild = function(_, name)
		return frames[name]
	end,
}
local button = { AbsolutePosition = roblox.Vector2.new(120, 100), AbsoluteSize = roblox.Vector2.new(80, 30) }
uiModule:calculateProportions(overlay, { Target = button, Padding = 8 })
assert(frames.Placeholder.Position == roblox.UDim2.fromOffset(132, 150))
assert(frames.Placeholder.Size == roblox.UDim2.fromOffset(96, 46))
button.AbsolutePosition = roblox.Vector2.new(140, 120)
uiModule:calculateProportions(overlay, { Target = button, Padding = 8 })
assert(frames.Placeholder.Position == roblox.UDim2.fromOffset(152, 170))

-- The camera's device-safe origin excludes a landscape phone's notch; the mask does not.
local projected = { ViewportPosition = roblox.Vector2.new(100, 120), AbsoluteSize = roblox.Vector2.new(80, 30), Padding = 8 }
overlay.AbsolutePosition = roblox.Vector2.new(-59, -58)
uiModule:calculateProportions(overlay, projected)
assert(frames.Placeholder.Position == roblox.UDim2.fromOffset(151, 112))
assert(frames.Placeholder.Size == roblox.UDim2.fromOffset(96, 46))
-- Recalculate after the safe-area origin changes (rotation or a desktop display).
overlay.AbsolutePosition = roblox.Vector2.new(0, -58)
uiModule:calculateProportions(overlay, projected)
assert(frames.Placeholder.Position == roblox.UDim2.fromOffset(92, 112))
-- Clip the original rectangle rather than moving an offscreen portion back onscreen.
uiModule:calculateProportions(overlay, { ViewportPosition = roblox.Vector2.new(-20, 120), AbsoluteSize = roblox.Vector2.new(80, 30) })
assert(frames.Placeholder.Position == roblox.UDim2.fromOffset(0, 120))
assert(frames.Placeholder.Size == roblox.UDim2.fromOffset(60, 30))

print(
	"Tutorial progression, resume, lost eggs, free stamina, offer reuse, training validation, migration and simultaneous beams passed; integration files compiled."
)
