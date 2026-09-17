-- Roblox Services
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Packages
local knit = require(ReplicatedStorage.src.Packages.knit)
local promise = require(ReplicatedStorage.src.Packages.promise)

-- Config Modules
local eggConfig = require(ReplicatedStorage.src.GameConfiguration.Gameplay.eggConfig)

-->
local EggGrowService = knit.CreateService({
	Name = "EggGrowService",
	Client = {
		ConnectGui = knit.CreateSignal(),
	},
	Promises = {},
})

-- Private Methods
function EggGrowService:getPlayerBase(player: Player)
	return self.BaseService:GetPlayerBase(player)
end

function EggGrowService:getValueObject(player: Player)
	return self.DataService:GetValueObject(player, "PlacedEggs")
end

function EggGrowService:getEggAsset(player: Player, referenceName: string)
	return self.BaseService:GetPlayerBase(player).PlacedEggs:FindFirstChild(referenceName)
end

function EggGrowService:connectTimer(eggAsset, secondsLeft: number)
	return promise.delay(secondsLeft)
end

-- Public Methods
function EggGrowService:ConnectEgg(player: Player, referenceName: string)
	self:DisconnectEgg(player, referenceName)

	if not self.Promises[player] then
		self.Promises[player] = {}
	end
	local playerPromises = self.Promises[player]

	local valueObject = self:getValueObject(player)
	local data = valueObject:Get()[referenceName]

	local eggName = referenceName:split("_")[1]
	local eggData = eggConfig.Eggs[eggName]
	if not data or not eggData then
		-- An egg saved under a name that no longer exists in eggConfig (e.g. renamed models)
		-- must not break the rest of the player's load chain.
		warn(`[EggGrowService] Skipping unknown egg "{eggName}" ({referenceName}) for {player.Name}`)
		return
	end

	local placeDate = data.PlaceDate :: number
	local hatchDate = placeDate + eggData.HatchDuration
	local secondsLeft = hatchDate - os.time()

	local eggAsset = self:getEggAsset(player, referenceName)
	self.Client.ConnectGui:Fire(player, referenceName, secondsLeft)

	self.Promises[player][referenceName] = self:connectTimer(eggAsset, secondsLeft)
		:andThen(function(timerCompleted: boolean)
			if not timerCompleted or self.Promises[player] ~= playerPromises then
				return
			end

			valueObject:Update(function(mutator)
				if mutator[referenceName] then
					mutator[referenceName].CanHatch = true
				end
			end)

			self:DisconnectEgg(player, referenceName)
		end)
		:catch(warn)
end

function EggGrowService:DisconnectEgg(player: Player, referenceName: string)
	local promise = self.Promises[player] and self.Promises[player][referenceName]
	if not promise then
		return
	end

	promise:cancel()
	self.Promises[player][referenceName] = nil
end

function EggGrowService:ClearPlayerReferences(player: Player)
	local playerPromises = self.Promises[player]
	self.Promises[player] = nil

	for _, promise in pairs(playerPromises or {}) do
		promise:cancel()
	end
end

-- LifeCycle
function EggGrowService:KnitInit()
	self.DataService = knit.GetService("DataService")
	self.BaseService = knit.GetService("BaseService")
	self.EggHatchService = knit.GetService("EggHatchService")
end

return EggGrowService
