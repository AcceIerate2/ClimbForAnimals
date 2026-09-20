-- Roblox Services
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Packages
local knit = require(ReplicatedStorage.src.Packages.knit)

-- Utility Modules
local NumberShortner = require(ReplicatedStorage.src.utility.NumberShortner)

-- Config Modules
local Config = require(ReplicatedStorage.src.GameConfiguration.Economy.rebirthConfig)
local ProductIds = require(script.Parent.monetizationService.productIds)
local BaseConfig = require(ReplicatedStorage.src.GameConfiguration.Economy.baseUpgradeConfig)
local TreadmillConfig = require(ReplicatedStorage.src.GameConfiguration.Economy.treadmillConfig)

-- Constants
local ResetKeys = {
	Speed = true,
	Cash = true,
	TreadmillLevel = true,
	StaminaConsumptionRate = true,
	StaminaLevel = true,
	BaseLevel = true,
	PendingOfflineCash = true,
}

-- Helper Functions
local function finite(value)
	return typeof(value) == "number" and value == value and value >= 0 and value < math.huge
end

-->
local RebirthService = knit.CreateService({
	Name = "RebirthService",
	Client = {},

	NextRequest = {},
})

-- Client Exposed Methods
function RebirthService.Client:GetState(player: Player)
	return self.Server:GetState(player)
end

function RebirthService.Client:Request(player: Player, skip: boolean?)
	return self.Server:Request(player, skip)
end

-- Private Methods
function RebirthService:apply(player: Player, skipped: boolean)
	local state = self:GetState(player)

	if not state.Status then
		return state
	end

	if not state.Available then
		if not Config.Enabled then
			return { Status = false, Reason = "Rebirth is currently disabled." }
		end

		if Config.MaxRebirths > 0 and state.Count >= Config.MaxRebirths then
			return { Status = false, Reason = "You've reached the maximum rebirth level!" }
		end

		return { Status = false, Reason = "Rebirth is currently unavailable." }
	end

	if not skipped and not state.Ready then
		local missing = {}

		for key, required in pairs(state.Requirements) do
			local current = self.DataService:GetValue(player, key)
			local difference = math.ceil(required - current)

			if difference > 0 then
				table.insert(missing, `{NumberShortner(difference)} more {key}`)
			end
		end

		table.sort(missing)

		return { Status = false, Reason = `You need {table.concat(missing, " and ")} to rebirth!` }
	end

	if next(self.EggHatchService.PendingHatches[player] or {}) then
		return { Status = false, Reason = "Finish hatching your eggs first." }
	end

	local reset = not skipped or Config.Skip.ApplyResets

	if skipped and self.DataService:GetValue(player, "RebirthPurchases").Credits <= 0 then
		return { Status = false, Reason = "No skip credit is available." }
	end

	if reset then
		-- Validate all settings before changing the profile.
		for key, value in pairs(Config.Reset) do
			if value ~= false then
				assert(ResetKeys[key], `Unsupported rebirth reset: {key}`)
				assert(finite(value), `Invalid rebirth reset: {key}`)
				assert(self.DataService:GetProfile(player)[key], `Unknown rebirth reset: {key}`)
			end
		end

		assert(Config.Reset.BaseLevel == false or BaseConfig.Levels[Config.Reset.BaseLevel], "Invalid reset plot level")
		assert(
			Config.Reset.TreadmillLevel == false
				or Config.Reset.TreadmillLevel == TreadmillConfig.BaseLevel
				or TreadmillConfig.LevelConfig[Config.Reset.TreadmillLevel],
			"Invalid reset treadmill level"
		)
	end

	-- These mutations do not yield: credit, progression and receipt live in the same profile.
	self.CashFlowService:updateIncome(workspace:GetServerTimeNow())

	if reset then
		-- Speed can reset while training continues. Only stop when replacing the treadmill level.
		if Config.Reset.TreadmillLevel ~= false then
			self.TreadmillService:DeactivateTreadmill(player, true)
		end

		self.EggSpawnService:ReturnCarriedEgg(player)

		local inventory = table.clone(self.DataService:GetValue(player, "Inventory"))

		for reference, item in pairs(inventory) do
			if item.Handler == "Animal" and Config.RemoveAnimals then
				self.AnimalService:RemoveAnimal(player, reference)
			elseif item.Handler == "Egg" and Config.RemoveEggs then
				self.InventoryService:RemoveItem(player, reference)
			end
		end

		if Config.RemoveEggs then
			local base = self.BaseService:GetPlayerBase(player)
			local eggs = base and base:FindFirstChild("PlacedEggs")

			for reference in pairs(self.DataService:GetValue(player, "PlacedEggs")) do
				self.EggGrowService:DisconnectEgg(player, reference)

				local model = eggs and eggs:FindFirstChild(reference)

				if model then
					model:Destroy()
				end
			end

			self.DataService:GetValueObject(player, "PlacedEggs"):Set({})
		end

		if Config.UnequipAnimals then
			for reference in pairs(table.clone(self.DataService:GetValue(player, "EquippedAnimals"))) do
				self.AnimalService:UnEquipAnimal(player, reference)
			end
		end

		for key, value in pairs(Config.Reset) do
			if value ~= false then
				self.DataService:GetValueObject(player, key):Set(value)
			end
		end

		-- Recompute the drain interval whenever rebirth resets the upgrade level.
		if Config.Reset.StaminaLevel then
			self.StaminaUpgradeService:SetLevel(player, Config.Reset.StaminaLevel)
		elseif Config.Reset.StaminaConsumptionRate then
			self.DataService:GetValueObject(player, "StaminaLevel"):Set(0)
			self.StaminaUpgradeService:Initialize(player)
		end

		if Config.Reset.BaseLevel ~= false then
			self.BaseService:ToggleBaseModel(player, Config.Reset.BaseLevel)
			self.AnimalService:Connect(player)
		end
	end

	self.DataService:GetValueObject(player, "Rebirths"):Set(state.Count + 1)
	self:Initialize(player)

	if skipped then
		self.DataService:GetValueObject(player, "RebirthPurchases"):Update(function(data)
			data.Credits -= 1
		end)
	end

	return { Status = true }
end

-- Public Methods
function RebirthService:GetProductId()
	for id, product in pairs(ProductIds) do
		if typeof(id) == "number" and id > 0 and typeof(product) == "table" and product.Action == "SkipRebirth" then
			return id
		end
	end
	return
end

function RebirthService:GetState(player: Player)
	if not self.DataService:GetProfile(player) or not self.AnimalService.Profiles[player] then
		return { Status = false, Reason = "Your plot is still loading." }
	end

	local count = self.DataService:GetValue(player, "Rebirths")

	if not finite(count) or count % 1 ~= 0 then
		return { Status = false, Reason = "Invalid rebirth data." }
	end

	local nextMultiplier = Config.GetMultiplier(count + 1)
	local requirements = Config.GetRequirements(count)
	local capped = Config.MaxRebirths > 0 and count >= Config.MaxRebirths
	local ready = Config.Enabled and not capped
	local valid = finite(nextMultiplier) and nextMultiplier > 0 and count + 1 < 2 ^ 53

	for key, amount in pairs(requirements) do
		local current = self.DataService:GetValue(player, key)
		valid = valid and finite(amount) and finite(current)
		if not finite(amount) or not finite(current) or current < amount then
			ready = false
		end
	end

	return {
		Status = true,
		Count = count,
		Requirements = requirements,
		Multiplier = self.DataService:GetValue(player, "CashMultiplier"),
		NextMultiplier = nextMultiplier,
		Ready = ready and valid,
		Available = Config.Enabled and not capped and valid,
		ProductId = Config.Skip.Enabled and self:GetProductId() or nil,
		Credits = self.DataService:GetValue(player, "RebirthPurchases").Credits,
	}
end

function RebirthService:Initialize(player: Player)
	local count = self.DataService:GetValue(player, "Rebirths")
	local multiplier = Config.GetMultiplier(count)
	assert(finite(multiplier) and multiplier > 0, "Invalid rebirth multiplier configuration")
	self.DataService:GetValueObject(player, "CashMultiplier"):Set(multiplier)
	player:SetAttribute("CashMultiplier", multiplier) -- Visible to other clients' animal billboards.
end

function RebirthService:Request(player: Player, skip: boolean?)
	if self.NextRequest[player] and os.clock() < self.NextRequest[player] then
		return { Status = false, Silent = true }
	end

	self.NextRequest[player] = os.clock() + Config.RequestCooldown
	local state = self:GetState(player)

	if not state.Status then
		return state
	end

	if skip == true then
		if not Config.Skip.Enabled or not state.Available then
			return { Status = false, Reason = "Skip rebirth is unavailable." }
		end

		if state.Credits > 0 then
			return self:apply(player, true)
		end

		if not state.ProductId then
			return { Status = false, Reason = "Skip rebirth hasn't been configured yet." }
		end

		return { Status = true, ProductId = state.ProductId }
	end

	return self:apply(player, false)
end

function RebirthService:ProcessReceipt(player: Player, receipt)
	local profile = self.ProfileStoreService:getProfile(player)

	if not profile or not profile:IsActive() or not self.DataService:GetProfile(player) then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end

	local product = ProductIds[receipt.ProductId]

	if not product or product.Action ~= "SkipRebirth" then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end

	local purchases = self.DataService:GetValueObject(player, "RebirthPurchases")
	local id = receipt.PurchaseId

	if not purchases:Get().Receipts[id] then
		purchases:Update(function(data)
			data.Receipts[id] = true
			data.Credits += 1
		end)

		-- If a cap/loading/reveal blocks the reset, retain the paid credit for the Skip button.
		self:apply(player, true)
	end

	profile:Save()
	local deadline = os.clock() + 20

	while profile:IsActive() and os.clock() < deadline do
		local saved = profile.LastSavedData.RebirthPurchases

		if saved and saved.Receipts[id] then
			return Enum.ProductPurchaseDecision.PurchaseGranted
		end

		task.wait(0.2)
	end

	return Enum.ProductPurchaseDecision.NotProcessedYet
end

-- LifeCycle
function RebirthService:KnitInit()
	self.StaminaUpgradeService = knit.GetService("StaminaUpgradeService")
	self.DataService = knit.GetService("DataService")
	self.AnimalService = knit.GetService("AnimalService")
	self.CashFlowService = knit.GetService("CashFlowService")
	self.TreadmillService = knit.GetService("TreadmillService")
	self.EggSpawnService = knit.GetService("EggSpawnService")
	self.EggHatchService = knit.GetService("EggHatchService")
	self.EggGrowService = knit.GetService("EggGrowService")
	self.InventoryService = knit.GetService("InventoryService")
	self.BaseService = knit.GetService("BaseService")
	self.ProfileStoreService = knit.GetService("ProfileStoreService")
end

function RebirthService:KnitStart()
	Players.PlayerRemoving:Connect(function(player)
		self.NextRequest[player] = nil
	end)
end

return RebirthService
