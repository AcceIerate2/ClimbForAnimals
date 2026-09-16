-- Roblox Services
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Packages
local knit = require(ReplicatedStorage.src.Packages.knit)

-- Utility Modules
local WaitForUiDesc = require(ReplicatedStorage.src.utility.WaitForUiDesc)
local NumberShortner = require(ReplicatedStorage.src.utility.NumberShortner)

-- Config Modules
local trailsConfig = require(ReplicatedStorage.src.GameConfiguration.Economy.trailsConfig)

-- Constants
local ButtonColors = {
	Default = Color3.fromRGB(0, 255, 0),
	Equipped = Color3.fromRGB(255, 0, 0),
}

-->
local TrailsShop = {
	Entries = {}, -- [trailName]: { Button: GuiButton, Label: TextLabel }
}

function TrailsShop:syncGui(owned: { [string]: boolean }, equipped: string?)
	for trailName: string, entry in pairs(self.Entries) do
		if equipped == trailName then
			entry.Label.Text = "UNEQUIP"
			entry.Button.BackgroundColor3 = ButtonColors.Equipped
		elseif owned[trailName] then
			entry.Label.Text = "EQUIP"
			entry.Button.BackgroundColor3 = ButtonColors.Default
		else
			entry.Label.Text = `${NumberShortner(trailsConfig.Trails[trailName].Price)}`
			entry.Button.BackgroundColor3 = ButtonColors.Default
		end
	end
end

function TrailsShop:connectButton(button: GuiButton, trailName: string)
	button:AddTag("GuiButton")
	button:SetAttribute("Type", "Action")
	button:SetAttribute("Action", "SelectTrail")
	button:SetAttribute("TrailName", trailName)
end

-- LifeCycle
function TrailsShop:Init(player: Player)
	self.TrailsShopController = knit.GetController("TrailsShopController")

	local panel = player.PlayerGui:WaitForChild("Panels"):WaitForChild("Trails")
	local scrollingFrame = WaitForUiDesc(panel, "ScrollingFrame", { Name = "ScrollingFrame" })

	for trailName: string, trailData in pairs(trailsConfig.Trails) do
		local trailFrame = scrollingFrame:FindFirstChild(trailName)
		if not trailFrame then
			warn(`[TrailsShop] Could not find frame for {trailName}`)
			continue
		end

		trailFrame.LayoutOrder = trailData.Order

		local multiplierFrame = trailFrame:FindFirstChild("Frame")
		local multiplierLabel = multiplierFrame and multiplierFrame:FindFirstChild("Text")
		if multiplierLabel then
			multiplierLabel.Text = `{trailData.SpeedMultiplier}x Speed`
		end

		local button = trailFrame:WaitForChild("Button")
		self:connectButton(button, trailName)

		self.Entries[trailName] = {
			Button = button,
			Label = button:WaitForChild("TextLabel"),
		}
	end

	self.TrailsShopController.Signals.TrailsChanged:Connect(function(owned, equipped)
		self:syncGui(owned, equipped)
	end)

	self:syncGui({}, nil)
	self.TrailsShopController:SyncTrails()
end

return TrailsShop
