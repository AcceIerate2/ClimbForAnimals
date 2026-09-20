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
	if not profile or player.Parent ~= Players or self.DisconnectFunctions[player] ~= playerDisconnectFunctions then
		self:unload(player)
		return
	end

	playerDisconnectFunctions.profileStoreDisconnectFunction = profileStoreDisconnectFunction

	-- DataService
	playerDisconnectFunctions.dataServiceDisconnectFunction = self.DataService:ConnectProfile(player, profile.Data)
	self.RebirthService:Initialize(player)

	-- Restore permanent bonuses before calculating offline income or loading growing eggs.
	self.MonetizationService:loadGamepasses(player)
	if player.Parent ~= Players or self.DisconnectFunctions[player] ~= playerDisconnectFunctions then
		return
	end

	-- CashFlowService uses the saved equipped animals before plot restoration.
	self.CashFlowService:PrepareOfflineCash(player)

	-- InventoryService
	self.InventoryService:ConnectTools(player)

	-- BaseService
	playerDisconnectFunctions.baseServiceDisconnectFunction = self.BaseService:Connect(player)
	if player.Parent ~= Players or self.DisconnectFunctions[player] ~= playerDisconnectFunctions then
		return
	end

	if not self.BaseService:GetPlayerBase(player) then
		self:unload(player)
		return
	end

	-- EggPlacementService
	self.EggPlacementService:LoadEggs(player)

	-- AnimalService
	playerDisconnectFunctions.animalServiceDisconnectFunction = self.AnimalService:Connect(player)

	-- BadgeService
	self.BadgeService:awardWelcomeBadges(player)
	if player.Parent ~= Players or self.DisconnectFunctions[player] ~= playerDisconnectFunctions then
		return
	end

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
	local characterConnection = player.CharacterAdded:Connect(characterAdded)
	playerDisconnectFunctions.characterDisconnectFunction = {
		Function = function()
			characterConnection:Disconnect()
		end,
		Args = {},
	}

	-- Signal Player is ready
	self.LeaderboardService:Connect(player)
	InstanceCreator("BoolValue", "Synced", player)
end

function PlayerService:unload(player: Player)
	local playerDisconnectFunctions = self.DisconnectFunctions[player]
	if not TypeCheck.table(playerDisconnectFunctions) then
		return
	end

	-- Remove the record first so leaving and shutdown cannot clean up twice.
	self.DisconnectFunctions[player] = nil

	local function cleanup(name: string, callback)
		local success, message = xpcall(callback, debug.traceback)
		if not success then
			warn(`Failed to clean up {name} for {player.Name}: {message}`)
		end
	end

	cleanup("CharacterAdded", function()
		local data = playerDisconnectFunctions.characterDisconnectFunction
		if data then
			data.Function(table.unpack(data.Args))
		end
	end)

	-- Stop gameplay before releasing the plot or disposing of profile data.
	cleanup("LeaderboardService", function()
		self.LeaderboardService:Disconnect(player)
	end)
	cleanup("TreadmillService", function()
		self.TreadmillService:DeactivateTreadmill(player)
	end)
	cleanup("EggGrowService", function()
		self.EggGrowService:ClearPlayerReferences(player)
	end)
	cleanup("EggHatchService", function()
		self.EggHatchService:DisconnectPlayer(player)
	end)
	cleanup("AnimalService", function()
		self.AnimalService:Disconnect(player)
	end)
	cleanup("CashFlowService", function()
		self.CashFlowService:DisconnectPlayer(player)
	end)
	cleanup("BaseService", function()
		self.BaseService:Disconnect(player)
	end)
	cleanup("ProfileStoreService", function()
		self.ProfileStoreService:endSession(player)
	end)
	cleanup("DataService", function()
		self.DataService:DisconnectProfile(player)
	end)

	table.clear(playerDisconnectFunctions)
end

-- starts all connections
function PlayerService:KnitInit()
	self.RebirthService = knit.GetService("RebirthService")
	self.ProfileStoreService = knit.GetService("ProfileStoreService")
	self.DataService = knit.GetService("DataService")
	self.MonetizationService = knit.GetService("MonetizationService")
	self.BadgeService = knit.GetService("BadgeService")
	self.BaseService = knit.GetService("BaseService")
	self.TreadmillService = knit.GetService("TreadmillService")
	self.InventoryService = knit.GetService("InventoryService")
	self.EggPlacementService = knit.GetService("EggPlacementService")
	self.AnimalService = knit.GetService("AnimalService")
	self.EggGrowService = knit.GetService("EggGrowService")
	self.EggHatchService = knit.GetService("EggHatchService")
	self.CashFlowService = knit.GetService("CashFlowService")
	self.LeaderboardService = knit.GetService("LeaderboardService")

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
		local remaining = #playersInServer
		for _, player in pairs(playersInServer) do
			task.spawn(function()
				self:unload(player)
				remaining -= 1
			end)
		end
		-- Flush players concurrently so leaderboard writes do not serialize shutdown.
		local deadline = os.clock() + 25
		while remaining > 0 and os.clock() < deadline do
			task.wait(0.1)
		end
	end)
end

return PlayerService
