-- Roblox Services
local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

-- Packages
local knit = require(ReplicatedStorage.src.Packages.knit)

-- Utility Modules
local NumberShortner = require(ReplicatedStorage.src.utility.NumberShortner)

-- Config Modules
local treadmillConfig = require(ReplicatedStorage.src.GameConfiguration.Economy.treadmillConfig)

-->
local TreadmillService = knit.CreateService({
	Name = "TreadmillService",
	Client = {
		ShowMultiplier = knit.CreateSignal(),
		MultiplierClicked = knit.CreateSignal(),
		ToggleTreadmillVisibility = knit.CreateSignal(),
	},

	Connections = {} :: { [Player]: { RBXScriptConnection } },
	PendingMultipliers = {} :: { [Player]: string },
	ActiveMultipliers = {} :: { [Player]: number },
})

-- Client Exposed Methods
function TreadmillService.Client:ActivateTreadmill(player: Player)
	return self.Server:ActivateTreadmill(player)
end

function TreadmillService.Client:DeactivateTreadmill(player: Player)
	return self.Server:DeactivateTreadmill(player)
end

function TreadmillService.Client:RequestToUpgrade(player: Player)
	return self.Server:UpgradeTreadmill(player)
end

-- Private Methods
function TreadmillService:getLevel(player: Player)
	return self.DataService:GetValue(player, "TreadmillLevel")
end

function TreadmillService:getSpeedPerStep(player: Player)
	local baseSpeed = treadmillConfig.BaseSpeedPerStep
	local multiplier = treadmillConfig.LevelConfig[self:getLevel(player)].TrainingBonus
	return baseSpeed * multiplier
end

function TreadmillService:getCooldown(player: Player): number
	return treadmillConfig.LevelConfig[self:getLevel(player)].Cooldown --/ (self.ActiveMultipliers[player] or 1)
end

-- Public Methods
function TreadmillService:ActivateTreadmill(player: Player)
	self.Connections[player] = {}
	if self:getLevel(player) > 0 then
		self.Client.ToggleTreadmillVisibility:FireAll({
			Visible = true,
			Owner = player,
			Treadmill = treadmillConfig.LevelConfig[self:getLevel(player)].Treadmill,
			Base = self.BaseService:GetPlayerBase(player),
		})
	end

	-- Speed
	local elapsed = 0
	table.insert(
		self.Connections[player],
		RunService.Heartbeat:Connect(function(deltaTime: number)
			elapsed += deltaTime
			if elapsed < self:getCooldown(player) then
				return
			end

			elapsed = 0

			-- Bonuses stack additively: 2x boost + trail x2.5 = x3.5
			local boostMultiplier = self.ActiveMultipliers[player] or 1
			local trailMultiplier = self.TrailsService:GetEquippedMultiplier(player)
			local multiplier = 1 + (boostMultiplier - 1) + (trailMultiplier - 1)

			local speedVO = self.DataService:GetValueObject(player, "Speed")
			speedVO:Set(speedVO:Get() + (self:getSpeedPerStep(player) * multiplier))
		end)
	)

	-- 2X Multiplier
	local multiplierElapsed = 0
	table.insert(
		self.Connections[player],
		RunService.Heartbeat:Connect(function(deltaTime: number)
			multiplierElapsed += deltaTime
			if multiplierElapsed < treadmillConfig.MultiplierCooldownDuration then
				return
			end

			multiplierElapsed = 0
			if self.PendingMultipliers[player] then
				return
			end

			self.PendingMultipliers[player] = HttpService:GenerateGUID(false)
			self.Client.ShowMultiplier:Fire(player, self.PendingMultipliers[player])
		end)
	)

	return {
		Status = true,
	}
end

function TreadmillService:DeactivateTreadmill(player: Player)
	if self:getLevel(player) > 0 then
		self.Client.ToggleTreadmillVisibility:FireAll({
			Visible = false,
			Owner = player,
			Treadmill = treadmillConfig.LevelConfig[self:getLevel(player)].Treadmill,
			Base = self.BaseService:GetPlayerBase(player),
		})
	end

	self.PendingMultipliers[player] = nil
	self.ActiveMultipliers[player] = nil

	for _, connection in pairs(self.Connections[player] or {}) do
		if typeof(connection) == "RBXScriptConnection" then
			connection:Disconnect()
		end
	end

	table.clear(self.Connections[player] or {})
	self.Connections[player] = nil

	return { Status = true }
end

function TreadmillService:UpgradeTreadmill(player: Player)
	local currentLevel = self.DataService:GetValue(player, "TreadmillLevel")
	local nextLevel = currentLevel + 1

	if currentLevel == treadmillConfig.MaxLevel then
		return { Status = false, Reason = "Max Level!" }
	end

	local treadmillData = treadmillConfig.LevelConfig[nextLevel]
	local costToUpgrade = treadmillData.UpgradeCost

	if not self.CashService:CanAfford(player, costToUpgrade) then
		return {
			Status = false,
			Reason = `You need ${NumberShortner(costToUpgrade - self.DataService:GetValue(player, "Cash"))} more!`,
		}
	end

	self.CashService:ManipulatePlayerCash(player, -costToUpgrade, "Addition")
	self.DataService
		:GetValueObject(player, "TreadmillLevel")
		:Set(self.DataService:GetValue(player, "TreadmillLevel") + 1)

	self.Client.ToggleTreadmillVisibility:FireAll({
		Visible = true,
		Owner = player,
		Treadmill = treadmillConfig.LevelConfig[self:getLevel(player)].Treadmill,
		Base = self.BaseService:GetPlayerBase(player),
	})

	return { Status = true }
end

-- LifeCycle
function TreadmillService:KnitInit()
	self.DataService = knit.GetService("DataService")
	self.BaseService = knit.GetService("BaseService")
	self.CashService = knit.GetService("CashService")
	self.PlayerService = knit.GetService("PlayerService")
	self.TrailsService = knit.GetService("TrailsService")
end

function TreadmillService:KnitStart()
	self.PlayerService.CharacterReset:Connect(function(player: Player, _character: any)
		self:DeactivateTreadmill(player)
	end)

	self.Client.MultiplierClicked:Connect(function(player: Player, guid: string)
		if not self.PendingMultipliers[player] then
			return
		end

		self.PendingMultipliers[player] = nil

		self.ActiveMultipliers[player] = treadmillConfig.MultiplierBoost
		task.delay(treadmillConfig.MultiplierDuration, function()
			if self.ActiveMultipliers[player] then
				self.ActiveMultipliers[player] = nil
			end
		end)
	end)
end

return TreadmillService
