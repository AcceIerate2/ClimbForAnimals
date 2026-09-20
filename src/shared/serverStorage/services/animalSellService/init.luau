-- Roblox Services
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Packages
local knit = require(ReplicatedStorage.src.Packages.knit)

-- Config Modules
local SellConfig = require(ReplicatedStorage.src.GameConfiguration.Economy.animalSellConfig)

-- Constants
local RequestCooldown = 0.3

-->
local AnimalSellService = knit.CreateService({
	Name = "AnimalSellService",
	Client = {},
	Pending = {},
	LastRequest = {},
})

-- Client Exposed Methods
function AnimalSellService.Client:Request(player: Player, action: string, referenceName: string?)
	return self.Server:Request(player, action, referenceName)
end

-- Private Methods
function AnimalSellService:sell(player: Player, action: string, referenceName: string?)
	local profile = self.ProfileStoreService:getProfile(player)
	if
		not profile
		or not profile:IsActive()
		or not self.DataService:GetProfile(player)
		or not self.AnimalService.Profiles[player]
	then
		return { Status = false, Reason = "Your animals are still loading. Please try again." }
	end

	if action ~= "Sell" and action ~= "SellAll" then
		return { Status = false, Reason = "Invalid sale request." }
	end
	if action == "Sell" and (type(referenceName) ~= "string" or #referenceName > 256) then
		return { Status = false, Reason = "Invalid animal." }
	end

	local inventory = self.DataService:GetValue(player, "Inventory")
	local selected = {}
	if action == "Sell" then
		local item = inventory[referenceName]
		if not item then
			return { Status = false, Reason = "You no longer own this animal." }
		end
		if item.Handler ~= "Animal" then
			return { Status = false, Reason = "Eggs can't be sold!" }
		end
		selected[referenceName] = item
	else
		for id, item in pairs(inventory) do
			if item.Handler == "Animal" then
				selected[id] = item
			end
		end
	end

	local rebirthMultiplier = self.DataService:GetValue(player, "CashMultiplier")
	local allTimeMultiplier = self.DataService:GetValue(player, "AllTimeCashMultiplier")
	local total, count = 0, 0
	for id, item in pairs(selected) do
		if self.EggHatchService:IsRevealing(player, id) then
			return { Status = false, Reason = "Wait for your animal to finish hatching before selling." }
		end
		local quote = SellConfig.GetQuote(item, rebirthMultiplier, allTimeMultiplier)
		if not quote then
			return { Status = false, Reason = "This animal can't be sold right now." }
		end
		total += quote.Price
		count += 1
	end
	if count == 0 then
		return { Status = false, Reason = "You have no animals to sell!" }
	end
	local balance = self.DataService:GetValue(player, "Cash")
	if total >= 2 ^ 53 or type(balance) ~= "number" or balance ~= balance or balance + total == math.huge then
		return { Status = false, Reason = "The sale could not be completed." }
	end

	-- All validation precedes mutation. These removal and cash methods do not yield:
	-- inventory, plot placement and cash change together in the active profile session.
	for id in pairs(selected) do
		self.AnimalService:RemoveAnimal(player, id)
	end
	self.CashService:ManipulatePlayerCash(player, total, "Addition", nil, "AnimalSale")

	return {
		Status = true,
		Amount = total,
		Count = count,
		Name = action == "Sell" and selected[referenceName].Name or nil,
	}
end

-- Public Methods
function AnimalSellService:Request(player: Player, action: string, referenceName: string?)
	local now = os.clock()
	if self.Pending[player] or now - (self.LastRequest[player] or -math.huge) < RequestCooldown then
		return { Status = false, Silent = true }
	end
	self.Pending[player] = true
	self.LastRequest[player] = now
	local success, response = xpcall(function()
		return self:sell(player, action, referenceName)
	end, debug.traceback)
	self.Pending[player] = nil
	if not success then
		warn(`[AnimalSellService] {response}`)
		return { Status = false, Reason = "Something went wrong while selling. Please try again." }
	end
	return response
end

-- LifeCycle
function AnimalSellService:KnitInit()
	self.DataService = knit.GetService("DataService")
	self.ProfileStoreService = knit.GetService("ProfileStoreService")
	self.AnimalService = knit.GetService("AnimalService")
	self.EggHatchService = knit.GetService("EggHatchService")
	self.CashService = knit.GetService("CashService")
end

function AnimalSellService:KnitStart()
	Players.PlayerRemoving:Connect(function(player)
		self.Pending[player] = nil
		self.LastRequest[player] = nil
	end)
end

return AnimalSellService
