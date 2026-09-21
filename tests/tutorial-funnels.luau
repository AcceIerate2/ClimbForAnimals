-- Run with: lune run tests/tutorial-funnels.luau
local fs = require("@lune/fs")
local luau = require("@lune/luau")
local roblox = require("@lune/roblox")
local folder = "src/shared/serverStorage/services/tutorialFunnelService/"
local config = luau.load(fs.readFile(folder .. "config.luau"))()
local source = fs.readFile(folder .. "init.luau")
source = source:gsub("local knit = require%([^\n]+%)", "local knit = Dependencies.knit")
source = source:gsub("local Config = require%([^\n]+%)", "local Config = Dependencies.Config")
local calls = {}
local fail = false
local studio = false
local warnings = 0
local services = {
	RunService = {
		IsStudio = function()
			return studio
		end,
	},
	AnalyticsService = {
		LogFunnelStepEvent = function(_, _, funnel, session, index, name, fields)
			if fail then
				error("Simulated analytics failure")
			end
			table.insert(
				calls,
				{ Funnel = funnel, Session = session, Index = index, Name = name, Fields = table.clone(fields) }
			)
		end,
	},
}
local function loadService()
	return luau.load(
		source,
		{
			environment = {
				Dependencies = { Config = config, knit = {
					CreateService = function(value)
						return value
					end,
				} },
				game = {
					GetService = function(_, name)
						return services[name] or {}
					end,
				},
				Enum = roblox.Enum,
				warn = function()
					warnings += 1
				end,
			},
		}
	)()
end
local service = loadService()
local player = { UserId = 42, Name = "Test" }
local state = {}
assert(not service:Track(player, {}, "Finish"), "Migrated profiles must not count as completed")
assert(service:Track(player, state, "Climb"))
assert(#calls == 2)
assert(not service:Track(player, state, "Climb"))
service:Track(player, state, "Ascend")
assert(#calls == 5)
assert(calls[3].Index == 2 and calls[3].Fields.CustomField01 == "Start climbing")
service:Track(player, state, "Climb")
assert(#calls == 5, "Backtracking must not record a completion")
service:Track(player, state, "Ascend")
assert(#calls == 5, "Retrying must not duplicate events")
service = loadService()
assert(not service:Track(player, state, "Ascend"), "Rejoining must retain deduplication")
for index = 3, #config.Steps do
	service:Track(player, state, config.Steps[index].Key)
end
service:Track(player, state, "Finish")
assert(#calls == #config.Steps * 3 + 1)
assert(calls[#calls].Name == "Tutorial complete")
assert(state.Funnels.Completed.Train)
assert(not service:Track(player, state, "Finish"))
local resumed = {}
local before = #calls
service:Track(player, resumed, "Hatch")
assert(#calls == before + 2 and not resumed.Funnels.Started.Climb, "Do not invent individual steps on migration")
fail = true
assert(service:Track(player, {}, "Climb"), "Analytics failure must not break progression")
assert(warnings == 2)
fail = false
studio = true
before = #calls
service:Track(player, {}, "Climb")
assert(#calls == before, "Studio must not call Roblox analytics")
config.Enabled = false
assert(not service:Track(player, {}, "Climb"))
print("Tutorial funnel checks passed")
