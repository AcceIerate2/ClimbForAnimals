-- Roblox Services
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Packages
local knit = require(ReplicatedStorage.src.Packages.knit)

-- Utility
local TypeCheck = require(ReplicatedStorage.src.utility.TypeCheck)

-- Config Modules
local RebirthConfig = require(ReplicatedStorage.src.GameConfiguration.Economy.rebirthConfig)

-->
local CashService = knit.CreateService({
	Name = "CashService",
	Client = {
		CashChanged = knit.CreateSignal(),
	},
})

-- Client Exposed Methods
function CashService.Client:GetCash(player: Player)
	local amount = self.Server:getCashValueObject(player):Get()
	return {
		Status = true,
		Amount = amount or 0,
	}
end

-- Private Methods
function CashService:getCashValueObject(player: Player)
	assert(TypeCheck.Instance(player), "player arg must be a player")
	return self.DataService:GetValueObject(player, "Cash")
end

-- Public Methods
function CashService:ManipulatePlayerCash(
	player: Player,
	change: number,
	arithmeticType: string,
	clientDelay: number?,
	source: string?
)
	assert(TypeCheck.Instance(player), "player arg must be a player")
	assert(TypeCheck.number(change), "change arg must be a number")
	assert(TypeCheck.string(arithmeticType), "arithmeticType must be a string")

	if change == 0 then
		return
	end

	local cashValueObject = self:getCashValueObject(player)
	if arithmeticType == "Addition" then
		if change > 0 and source ~= "SettledIncome" and source ~= "PurchasedCash" and source ~= "AnimalSale" then
			change *= RebirthConfig.ForSource(
				self.DataService:GetValue(player, "CashMultiplier"),
				source or "OtherRewards"
			)
			change *= self.DataService:GetValue(player, "AllTimeCashMultiplier") or 1
		end
		cashValueObject:Set(cashValueObject:Get() + change)
	elseif arithmeticType == "Multiplication" then
		cashValueObject:Set(cashValueObject:Get() * change)
	elseif arithmeticType == "Division" then
		cashValueObject:Set(cashValueObject:Get() / change)
	else
		error(`Invalid arithmeticType: {arithmeticType}`)
	end

	self.Client.CashChanged:Fire(player, cashValueObject:Get(), clientDelay or 0)
end

function CashService:CanAfford(player: Player, numberToBeComparedTo: number)
	assert(TypeCheck.Instance(player), "player arg must be a player")
	assert(TypeCheck.number(numberToBeComparedTo), "numberToBeComparedTo arg must be a number")
	return self:getCashValueObject(player):Get() >= numberToBeComparedTo
end

-- LifeCycle
function CashService:KnitInit()
	self.DataService = knit.GetService("DataService")
end

return CashService
