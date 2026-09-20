-- Roblox Services
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Packages
local knit = require(ReplicatedStorage.src.Packages.knit)

-->
return function(button: GuiButton)
	local purchaseType = button:GetAttribute("PurchaseType")
	local id = button:GetAttribute("Id")
	if button:GetAttribute("DebugPurchasePrompt") then
		print(`[Shop debug] Prompting {purchaseType} ID: {id}`)
	end

	knit.GetController("MonetizationController"):promptPurchase(purchaseType, id)
end
