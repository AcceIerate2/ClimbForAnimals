-- Roblox Services
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Packages
local Signal = require(ReplicatedStorage.src.Packages.Signal)
local knit = require(ReplicatedStorage.src.Packages.knit)

-- Utility
local TypeCheck = require(ReplicatedStorage.src.utility.TypeCheck)
local InstanceCreator = require(ReplicatedStorage.src.utility.InstanceCreator)
local CollisionHandler = require(ReplicatedStorage.src.utility.CollisionHandler)

-->
local PlayerService = knit.CreateService({
	Name = "PlayerService",
	Client = {},
	DisconnectFunctions = {},
	CharacterReset = Signal.new(),
})

function PlayerService:load(player: Player)
	self.DisconnectFunctions[player] = {}
	local playerDisconnectFunctions = self.DisconnectFunctions[player]

	-- ProfileStoreService
	local profile, profileStoreDisconnectFunction = self.ProfileStoreService:newSession(player)
	playerDisconnectFunctions.profileStoreDisconnectFunction = profileStoreDisconnectFunction

	-- DataService
	playerDisconnectFunctions.dataServiceDisconnectFunction = self.DataService:ConnectProfile(player, profile.Data)

	-- InventoryService
	self.InventoryService:ConnectTools(player)

	-- BaseService
	playerDisconnectFunctions.baseServiceDisconnectFunction = self.BaseService:Connect(player)

	-- EggPlacementService
	self.EggPlacementService:LoadEggs(player)

	-- Gamepasses
	self.MonetizationService:loadGamepasses(player)

	-- BadgeService
	self.BadgeService:awardWelcomeBadges(player)

	-- CharacterAdded Connection
	local function characterAdded(Character: Model)
		CollisionHandler.ToggleCollisionProperties(Character, {
			CollisionGroup = "PlayerCollisions",
		}, {})

		self.CharacterReset:Fire(player, Character)
	end

	if player.Character then
		characterAdded(player.Character)
	end
	player.CharacterAdded:Connect(characterAdded)

	-- Signal Player is ready
	InstanceCreator("BoolValue", "Synced", player)
end

function PlayerService:unload(player: Player)
	self.TreadmillService:DeactivateTreadmill(player)

	local playerDisconnectFunctions = self.DisconnectFunctions[player]
	if not TypeCheck.table(playerDisconnectFunctions) then
		return
	end

	for disconnectFunctionName: string, data in pairs(playerDisconnectFunctions) do
		local functionToCall = data["Function"]
		assert(typeof(functionToCall) == "function", `{disconnectFunctionName} does not have a function to call`)

		local args = data["Args"]
		assert(TypeCheck.table(args), "Args must be a table")

		functionToCall(table.unpack(data["Args"]))
	end
end

-- starts all connections
function PlayerService:KnitInit()
	self.ProfileStoreService = knit.GetService("ProfileStoreService")
	self.DataService = knit.GetService("DataService")
	self.MonetizationService = knit.GetService("MonetizationService")
	self.BadgeService = knit.GetService("BadgeService")
	self.BaseService = knit.GetService("BaseService")
	self.TreadmillService = knit.GetService("TreadmillService")
	self.InventoryService = knit.GetService("InventoryService")
	self.EggPlacementService = knit.GetService("EggPlacementService")

	-- Player Connections
	Players.PlayerAdded:Connect(function(player: Player)
		self:load(player)
	end)

	Players.PlayerRemoving:Connect(function(player: Player)
		self:unload(player)
	end)

	-- if the server shuts down
	game:BindToClose(function()
		local playersInServer = Players:GetPlayers()
		for _, player in pairs(playersInServer) do
			self:unload(player)
		end
	end)
end

return PlayerService
