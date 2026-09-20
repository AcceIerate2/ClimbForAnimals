-- Roblox Services
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Utility Modules
local EggHandler = require(ReplicatedStorage.src.utility.eggHandler)
local ViewportHandler = require(ReplicatedStorage.src.utility.viewportHandler)
local EarningCurve = require(ReplicatedStorage.src.utility.earningCurve)
local NumberShortner = require(ReplicatedStorage.src.utility.NumberShortner)
local RarityStyle = require(ReplicatedStorage.src.utility.rarityStyle)

-- Config Modules

-- Constants
local EquippedColor = Color3.fromRGB(255, 50, 50)
local UnequippedColor = Color3.fromRGB(85, 255, 0)
local BackgroundBaseColor = Color3.fromRGB(25, 25, 25)
local BackgroundTintStrength = (152 - 25) / (255 - 25) -- Match the egg row background tint.

local Row = {}

function Row.Create(template: Frame, referenceName: string, item, buttons)
	local frame = template:Clone()
	frame.Name = referenceName
	frame.Visible = true

	local button = frame.EquipToggler
	button:SetAttribute("Type", "Action")
	button:SetAttribute("Action", "AnimalPanelAction")
	button:SetAttribute("ReferenceName", referenceName)
	CollectionService:AddTag(button, "GuiButton")

	local row = { Frame = frame, Button = button }
	frame.Parent = template.Parent
	buttons:Link(button)
	Row.Update(row, item, false)
	return row
end

function Row.Update(row, item, equipped: boolean, cashMultiplier: number?)
	local custom = item.CustomData or {}
	local frame = row.Frame
	local rarity = EggHandler.GetRarity(item.Name)
	local variant = custom.Variant or "Normal"
	frame["Name Animal"].Text = item.Name
	frame.Rarity.Text = rarity or ""
	frame.Variation.Text = variant
	frame.Bar.Weight.Text = EggHandler.GetWeightKgDisplay(item.Name, custom.AssetScale)
	local income = EarningCurve.GetCashPerSecond(item.Name, custom.AssetScale, custom.Variant)
	income *= cashMultiplier or 1
	frame.Income.Text = `(${NumberShortner(math.round(income))}/s)`
	RarityStyle.ApplyRarity(frame.Rarity, rarity)
	RarityStyle.ApplyVariant(frame.Variation, variant)

	local color = RarityStyle.GetTintColor(rarity)
	if color then
		local background = frame.InnerStroke.Background
		local tint = BackgroundBaseColor:Lerp(color, BackgroundTintStrength)
		background.BackgroundColor3 = tint
		background.ImageColor3 = tint
	end

	row.Button.BackgroundColor3 = equipped and EquippedColor or UnequippedColor
	row.Button.TextLabel.Text = equipped and "UNEQUIP" or "EQUIP"

	if row.Name ~= item.Name or row.Variant ~= variant then
		if row.ResizeConnection then
			row.ResizeConnection:Disconnect()
		end
		if row.Viewport then
			row.Viewport:Destroy()
			row.Viewport = nil
		end

		row.Name, row.Variant = item.Name, variant
		local subject = EggHandler.GetAnimalTemplate(item.Name, custom.Variant)
		if subject then
			local viewport = frame.Bar.ViewportFrame
			row.Viewport = ViewportHandler.Setup(viewport, subject, {
				ClearOnSetup = false,
				NormalizeRotation = true,
				Yaw = 180, -- camera faces the asset's forward (-Z) direction
				Pitch = 0,
			})
			row.ResizeConnection = viewport:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
				row.Viewport:Refit()
			end)
		end
	end
end

function Row.Destroy(row, buttons)
	buttons:Unlink(row.Button)
	if row.ResizeConnection then
		row.ResizeConnection:Disconnect()
	end
	if row.Viewport then
		row.Viewport:Destroy()
	end
	row.Frame:Destroy()
end

return Row
