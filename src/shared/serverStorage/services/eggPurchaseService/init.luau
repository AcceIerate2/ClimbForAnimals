-- Roblox Services
local Players = game:GetService("Players")
local MarketplaceService = game:GetService("MarketplaceService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Packages
local knit = require(ReplicatedStorage.src.Packages.knit)

-- Config Modules
local productIds = require(script.Parent.monetizationService.productIds)
local eggConfig = require(ReplicatedStorage.src.GameConfiguration.Gameplay.eggConfig)

-->
local EggPurchaseService = knit.CreateService({
	Name = "EggPurchaseService",
	Client = {
		PurchaseResolved = knit.CreateSignal(),
	},

	Pending = {},
})

-- Client Exposed Methods
function EggPurchaseService.Client:RequestPurchase(player: Player, action: string, referenceName: string?)
	return self.Server:RequestPurchase(player, action, referenceName)
end

function EggPurchaseService.Client:CancelPrompt(player: Player, productId: number)
	if self.Server.Pending[player] == productId then
		self.Server.Pending[player] = nil
	end
end

-- Private Methods
function EggPurchaseService:getPurchases(player: Player)
	local purchases = self.DataService:GetValueObject(player, "EggPurchases")
	local data = purchases:Get()
	if
		data.SkipTimer == nil
		or data.SkipTimerCredits == nil
		or data.GrowAll == nil
		or data.Receipts == nil
		or data.Targets == nil
	then
		purchases:Update(function(saved)
			-- Keep any previously purchased universal skips separate from rarity credits.
			saved.SkipTimer = saved.SkipTimer or 0
			saved.SkipTimerCredits = saved.SkipTimerCredits or {}
			saved.GrowAll = saved.GrowAll or 0
			saved.Receipts = saved.Receipts or {}
			saved.Targets = saved.Targets or {}
		end)
	end

	return purchases
end

function EggPurchaseService:getRarity(referenceName: string?): string?
	local config = referenceName and eggConfig.Eggs[referenceName:split("_")[1]]

	return config and config.Rarity
end

function EggPurchaseService:getTargets(player: Player, action: string, referenceName: string?, rarity: string?)
	local targets = {}

	for name, egg in pairs(self.DataService:GetValue(player, "PlacedEggs")) do
		if not egg.CanHatch and (action == "GrowAll" or (name == referenceName and self:getRarity(name) == rarity)) then
			table.insert(targets, name)
		end
	end

	return targets
end

function EggPurchaseService:useCredit(player: Player, action: string, referenceName: string?, rarity: string?): boolean
	local purchases = self:getPurchases(player)
	local data = purchases:Get()
	local rarityCredit = action == "SkipTimer" and rarity ~= nil and (data.SkipTimerCredits[rarity] or 0) > 0
	if not rarityCredit and data[action] <= 0 then
		return false
	end

	local targets = self:getTargets(player, action, referenceName, rarity)
	if #targets == 0 then
		return false
	end

	self.EggGrowService:FinishEggs(player, targets)
	purchases:Update(function(data)
		if rarityCredit then
			data.SkipTimerCredits[rarity] -= 1
		else
			data[action] -= 1
		end
	end)

	return true
end

-- Public Methods
function EggPurchaseService:GetAction(productId: number): (string?, string?)
	local product = productIds[productId]
	if typeof(product) == "table" and (product.Action == "SkipTimer" or product.Action == "GrowAll") then
		return product.Action, product.Rarity
	end

	return nil, nil
end

function EggPurchaseService:GetProductId(action: string, rarity: string?): number?
	for id, product in pairs(productIds) do
		if typeof(product) == "table" and product.Action == action and product.Rarity == rarity then
			return id
		end
	end

	return nil
end

function EggPurchaseService:RequestPurchase(player: Player, action: string, referenceName: string?)
	if not self.DataService:GetProfile(player) then
		return { Status = false, Reason = "Your eggs are still loading." }
	end

	if
		(action ~= "SkipTimer" and action ~= "GrowAll")
		or (action == "SkipTimer" and typeof(referenceName) ~= "string")
	then
		return { Status = false, Reason = "Invalid egg purchase." }
	end

	if self.Pending[player] then
		return { Status = false, Silent = true }
	end

	local rarity = action == "SkipTimer" and self:getRarity(referenceName) or nil
	if #self:getTargets(player, action, referenceName, rarity) == 0 then
		return { Status = false, Reason = "There are no growing eggs to skip." }
	end

	if self:useCredit(player, action, referenceName, rarity) then
		return { Status = true, UsedCredit = true }
	end

	local productId = self:GetProductId(action, rarity)

	if not productId or productId <= 0 then
		return { Status = false, Reason = "This egg purchase is not available yet." }
	end

	local purchases = self:getPurchases(player)
	purchases:Update(function(data)
		data.Targets[tostring(productId)] = action == "SkipTimer" and referenceName or "All"
	end)

	self.Pending[player] = productId

	return { Status = true, ProductId = productId }
end

-- Called only by MonetizationService.ProcessReceipt, never by a client remote.
function EggPurchaseService:ProcessReceipt(player: Player, receipt)
	local action, rarity = self:GetAction(receipt.ProductId)
	local profile = self.ProfileStoreService:getProfile(player)
	if not action or not profile or not profile:IsActive() or not self.DataService:GetProfile(player) then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end

	local purchases = self:getPurchases(player)
	local receiptId = receipt.PurchaseId
	if not purchases:Get().Receipts[receiptId] then
		-- Store the receipt and its credit together, so a retry cannot grant it twice.
		purchases:Update(function(data)
			data.Receipts[receiptId] = true
			if action == "SkipTimer" then
				data.SkipTimerCredits[rarity] = (data.SkipTimerCredits[rarity] or 0) + 1
			else
				data[action] += 1
			end
		end)

		local targetKey = tostring(receipt.ProductId)
		local target = purchases:Get().Targets[targetKey]
		local used = self:useCredit(player, action, target, rarity)
		purchases:Update(function(data)
			data.Targets[targetKey] = nil
		end)

		if self.Pending[player] == receipt.ProductId then
			self.Pending[player] = nil
		end

		self.Client.PurchaseResolved:Fire(player, used)
	end

	-- Acknowledge only after the receipt and reward have reached the profile store.
	profile:Save()
	local deadline = os.clock() + 20

	while profile:IsActive() and os.clock() < deadline do
		local saved = profile.LastSavedData.EggPurchases
		if saved and saved.Receipts and saved.Receipts[receiptId] then
			return Enum.ProductPurchaseDecision.PurchaseGranted
		end

		task.wait(0.2)
	end

	return Enum.ProductPurchaseDecision.NotProcessedYet
end

-- LifeCycle
function EggPurchaseService:KnitInit()
	self.DataService = knit.GetService("DataService")
	self.EggGrowService = knit.GetService("EggGrowService")
	self.ProfileStoreService = knit.GetService("ProfileStoreService")
end

function EggPurchaseService:KnitStart()
	Players.PlayerRemoving:Connect(function(player)
		self.Pending[player] = nil
	end)

	MarketplaceService.PromptProductPurchaseFinished:Connect(function(userId, productId, purchased)
		local player = Players:GetPlayerByUserId(userId)
		if player and not purchased and self.Pending[player] == productId then
			self.Pending[player] = nil
		end
	end)
end

return EggPurchaseService
