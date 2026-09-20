-- Roblox Services
local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")

-- Packages
local Signal = require(ReplicatedStorage.src.Packages.Signal)
local knit = require(ReplicatedStorage.src.Packages.knit)

-- Utility
local TypeCheck = require(ReplicatedStorage.src.utility.TypeCheck)

-- Sfx
local MonetizationSounds =
	SoundService:WaitForChild("src"):WaitForChild("Sfx"):WaitForChild("MonetizationSounds") :: Folder
local promptSfx = MonetizationSounds:WaitForChild("Prompt") :: Sound
local purchaseSfx = MonetizationSounds:WaitForChild("PurchaseSuccess") :: Sound

-->
local MonetizationController = knit.CreateController({
	Name = "MonetizationController",
	Items = {} :: { [string]: { [string]: any } },
	OwnedPasses = {},
	OwnershipChanged = Signal.new(),

	PurchaseProcessingChanged = Signal.new(),
	PromptActive = false,
})

-- Public Methods
function MonetizationController:getMonetizationItemInfo(monetizationType: "Product" | "GamePass", id: number)
	if not TypeCheck.string(monetizationType) then
		warn("monetizationType arg must be a string - monetizationController:getMonetizationItemInfo")
		return
	end

	if not TypeCheck.number(id) or id == 0 then
		return
	end

	local cacheKey = `{string.lower(monetizationType)}:{id}`
	if self.Items[cacheKey] then
		return self.Items[cacheKey]
	end

	local rpcOk: boolean, response: { [string]: any } =
		self.Service:getMonetizationItemInfo(monetizationType, id):await()

	if not rpcOk then
		warn("RPC failed: getMonetizationItemInfo")
		return
	end

	if not TypeCheck.table(response) then
		warn(
			"Server:getMonetizationItemInfo did not return a valid response - monetizationController:getMonetizationItemInfo"
		)
		return
	end

	if type(response.PriceInRobux) == "number" then
		self.Items[cacheKey] = response
	end
	return response
end

function MonetizationController:GetShopCatalog()
	local success, items = self.Service:GetShopCatalog():await()
	if not success or type(items) ~= "table" then
		warn("Couldn't load the Shop catalog")
		return
	end

	for _, item in ipairs(items) do
		if item.PurchaseType == "GamePass" and item.Owned then
			self.OwnedPasses[item.Id] = true
		end
	end

	return items
end

function MonetizationController:OwnsPass(id: number): boolean
	return self.OwnedPasses[id] == true
end

function MonetizationController:purchased()
	self.NotificationController:Push({
		Message = `Thanks for your <font color="rgb(157, 255, 0)">purchase</font>!`,
		Color = Color3.fromRGB(255, 255, 255),
		Sound = purchaseSfx.Name,
	})
end

function MonetizationController:promptPurchase(purchaseType: string, id: number): boolean
	if not TypeCheck.string(purchaseType) then
		warn("[purchaseType] arg must be a string")
		return false
	end

	if not TypeCheck.number(id) or id <= 0 then
		warn("[id] arg must be a number")
		return false
	end

	if self.PromptActive then
		return false
	end

	if purchaseType:lower() == "gamepass" then
		purchaseType = "GamePass"
	elseif purchaseType:lower() == "product" then
		purchaseType = "Product"
	else
		warn(`Unsupported purchase type: {purchaseType}`)
		return false
	end

	if purchaseType == "GamePass" and self:OwnsPass(id) then
		return false
	end

	self.PromptActive = true
	promptSfx:Play()
	self.PurchaseProcessingChanged:Fire(true)

	local connection
	local function finish()
		connection:Disconnect()
		self.PromptActive = false
		self.PurchaseProcessingChanged:Fire(false)
	end

	connection = MarketplaceService[`Prompt{purchaseType}PurchaseFinished`]:Connect(function(buyer, productId)
		local localBuyer = purchaseType == "Product" and Players.LocalPlayer.UserId or Players.LocalPlayer
		if buyer == localBuyer and productId == id then
			finish()
		end
	end)

	local success, message = pcall(function()
		MarketplaceService[`Prompt{purchaseType}Purchase`](MarketplaceService, Players.LocalPlayer, id)
	end)
	if not success then
		finish()
		warn(message)
		return false
	end

	return true
end

-- LifeCycle
function MonetizationController:KnitInit()
	self.Service = knit.GetService("MonetizationService")
	self.Service.PassOwned:Connect(function(id: number)
		self.OwnedPasses[id] = true
		self.OwnershipChanged:Fire(id)
	end)
	self.Service.UserPurchased:Connect(function()
		self:purchased()
	end)

	self.NotificationController = knit.GetController("NotificationController")
end

function MonetizationController:KnitStart()
	require(script.PurchaseGui):Init()
end

return MonetizationController
