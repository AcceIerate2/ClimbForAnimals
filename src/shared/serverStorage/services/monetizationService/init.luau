-- Roblox Services
local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Packages
local knit = require(ReplicatedStorage.src.Packages.knit)

-- Utility
local TypeCheck = require(ReplicatedStorage.src.utility.TypeCheck)
local SafeFunctionCaller = require(ReplicatedStorage.src.utility.SafeFunctionCaller)

-->
local MonetizationService = knit.CreateService({
	Name = "MonetizationService",
	Client = {
		UserPurchased = knit.CreateSignal(),
		PassOwned = knit.CreateSignal(),
	},

	NotifiedReceipts = {},
	OwnedPasses = {},
	ProductIds = require(script.productIds),
	PassIds = require(script.passIds),
})

-- Client Exposed Methods
function MonetizationService.Client:getMonetizationItemInfo(
	_player: Player,
	monetizationType: "Product" | "GamePass",
	id: number
)
	return self.Server:getMonetizationItemInfo(monetizationType, id)
end

function MonetizationService.Client:GetShopCatalog(player: Player)
	return self.Server:GetShopCatalog(player)
end

-- Public Methods
function MonetizationService:GetShopCatalog(player: Player)
	local items = {}

	for purchaseType, registry in pairs({ GamePass = self.PassIds, Product = self.ProductIds }) do
		for id, item in pairs(registry) do
			if type(item) ~= "table" or not item.ShopKey or id <= 0 then
				continue
			end

			local owned = self.OwnedPasses[player] and self.OwnedPasses[player][id] == true
			if purchaseType == "GamePass" and not owned then
				local success, result =
					SafeFunctionCaller(MarketplaceService.UserOwnsGamePassAsync, MarketplaceService, player.UserId, id)
				owned = success and result == true
			end

			table.insert(items, {
				Key = item.ShopKey,
				Id = id,
				PurchaseType = purchaseType,
				CashAmount = item.CashAmount,
				Owned = owned == true,
			})
		end
	end

	return items
end

function MonetizationService:getMonetizationItemInfo(
	monetizationType: "Product" | "GamePass",
	id: number
): { [string]: any }
	assert(TypeCheck.string(monetizationType), "monetizationType arg must be a string")
	assert(TypeCheck.number(id), "id arg must be a number")

	if monetizationType:lower() == "gamepass" then
		monetizationType = "GamePass"
	end

	local status: boolean, response: { [string]: any } = SafeFunctionCaller(
		MarketplaceService.GetProductInfoAsync,
		MarketplaceService,
		id,
		Enum.InfoType[monetizationType]
	)

	return status and response or {}
end

function MonetizationService:gamepassPurchaseHandler(player: Player, passId: number, init: boolean)
	assert(TypeCheck.Instance(player), "player arg must be a Player")
	assert(TypeCheck.number(passId), "passId arg must be a number")

	local grantPurchaseHandler = self.PassIds[passId]
	if not grantPurchaseHandler then
		return
	end

	if init == nil then
		init = false
	end

	if type(grantPurchaseHandler) == "table" then
		grantPurchaseHandler = grantPurchaseHandler.Grant
	end

	grantPurchaseHandler(player, init)
	self.OwnedPasses[player] = self.OwnedPasses[player] or {}
	self.OwnedPasses[player][passId] = true
	self.Client.PassOwned:Fire(player, passId)
end

function MonetizationService:loadGamepasses(player: Player)
	local userId = player.UserId
	player:SetAttribute("AllTimeCashMultiplier", self.DataService:GetValue(player, "AllTimeCashMultiplier"))

	for passId: number in pairs(self.PassIds) do
		local status, owns =
			SafeFunctionCaller(MarketplaceService.UserOwnsGamePassAsync, MarketplaceService, userId, passId)
		if player.Parent ~= Players then
			return
		end

		if not status or not owns then
			continue
		end

		self:gamepassPurchaseHandler(player, passId, true)
	end
end

function MonetizationService:productPurchaseHandler(player: Player, productId: number) -- Exposed Method for other services to call
	local grantPurchaseHandler = self.ProductIds[productId]
	if typeof(grantPurchaseHandler) ~= "function" then
		return
	end
	SafeFunctionCaller(grantPurchaseHandler, player)
end

-- Store the cash and receipt in one profile; acknowledge only after both are saved.
function MonetizationService:ProcessCashPackReceipt(player: Player, receipt)
	local profile = self.ProfileStoreService:getProfile(player)
	local product = self.ProductIds[receipt.ProductId]
	if not profile or not profile:IsActive() or not self.DataService:GetProfile(player) then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end

	local amount = product and product.Action == "CashPack" and product.CashAmount
	if typeof(amount) ~= "number" or amount ~= amount or amount <= 0 or amount == math.huge then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end

	local history = self.DataService:GetValueObject(player, "PurchaseHistory")
	local receiptId = receipt.PurchaseId
	if not history:Get()[receiptId] then
		self.CashService:ManipulatePlayerCash(player, amount, "Addition", nil, "PurchasedCash")
		history:Update(function(saved)
			saved[receiptId] = true
		end)
	end

	profile:Save()
	local deadline = os.clock() + 20
	while profile:IsActive() and os.clock() < deadline do
		if profile.LastSavedData.PurchaseHistory[receiptId] then
			return Enum.ProductPurchaseDecision.PurchaseGranted
		end

		task.wait(0.2)
	end

	return Enum.ProductPurchaseDecision.NotProcessedYet
end

-- Private Methods
function MonetizationService:processReceipt(receiptInfo)
	local player = Players:GetPlayerByUserId(receiptInfo.PlayerId)
	if not player then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end

	if not self.DataService:GetProfile(player) then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end

	local product = self.ProductIds[receiptInfo.ProductId]
	if typeof(product) == "table" and typeof(product.ProcessReceipt) == "function" then
		local succeeded, decision = SafeFunctionCaller(product.ProcessReceipt, player, receiptInfo)
		if not succeeded or decision ~= Enum.ProductPurchaseDecision.PurchaseGranted then
			return Enum.ProductPurchaseDecision.NotProcessedYet
		end

		-- Notify once per receipt, even if Roblox retries while a save is in progress.
		local notified = self.NotifiedReceipts[player]
		if not notified then
			notified = {}
			self.NotifiedReceipts[player] = notified
		end
		if not notified[receiptInfo.PurchaseId] then
			notified[receiptInfo.PurchaseId] = true
			self.Client.UserPurchased:Fire(player)
		end

		return Enum.ProductPurchaseDecision.PurchaseGranted
	end

	local purchaseHistoryValueObject = self.DataService:GetValueObject(player, "PurchaseHistory")
	local history = purchaseHistoryValueObject:Get() or {}

	local purchaseKey = receiptInfo.PurchaseId
	if history[purchaseKey] then
		return Enum.ProductPurchaseDecision.PurchaseGranted
	end

	local grantPurchaseHandler = self.ProductIds[receiptInfo.ProductId]
	if not grantPurchaseHandler then
		warn(`No purchase handler defined for product ID {receiptInfo.ProductId}`)
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end

	local gift = self.GiftService:peekGiftRequest(player)
	if gift then
		self.GiftService:clearGiftRequest(player)
		player = gift.OtherPlayer
	end

	local handlerSucceeded, handlerResult = SafeFunctionCaller(grantPurchaseHandler, player)
	if not handlerSucceeded then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end

	local saved =
		pcall(purchaseHistoryValueObject.Insert, purchaseHistoryValueObject, purchaseKey, handlerResult or true)
	if not saved then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end

	self.Client.UserPurchased:Fire(player)
	return Enum.ProductPurchaseDecision.PurchaseGranted
end

-- LifeCycle
function MonetizationService:KnitInit()
	self.DataService = knit.GetService("DataService")
	self.CashService = knit.GetService("CashService")
	self.ProfileStoreService = knit.GetService("ProfileStoreService")
	self.GiftService = knit.GetService("GiftService")

	Players.PlayerRemoving:Connect(function(player)
		self.NotifiedReceipts[player] = nil
		self.OwnedPasses[player] = nil
	end)

	MarketplaceService.ProcessReceipt = function(receiptInfo)
		return self:processReceipt(receiptInfo)
	end

	MarketplaceService.PromptProductPurchaseFinished:Connect(
		function(userId: number, productId: number, purchased: boolean)
			if purchased then
				return
			end

			local player = Players:GetPlayerByUserId(userId)
			if not player then
				return
			end

			self.GiftService:clearGiftRequest(player)
		end
	)

	MarketplaceService.PromptGamePassPurchaseFinished:Connect(
		function(player: Player, passId: number, purchased: boolean)
			local gift = self.GiftService:peekGiftRequest(player)
			if gift then
				self.GiftService:clearGiftRequest(player)
				if purchased then
					local other = gift.OtherPlayer
					if other then
						player = other
					end
				end
			end

			if not purchased then
				return
			end

			self.Client.UserPurchased:Fire(player)
			self:gamepassPurchaseHandler(player, passId, false)
		end
	)
end

return MonetizationService
