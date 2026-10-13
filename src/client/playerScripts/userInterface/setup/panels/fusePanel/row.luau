-- Roblox Services
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Utility Modules
local EggHandler = require(ReplicatedStorage.src.utility.eggHandler)
local ViewportHandler = require(ReplicatedStorage.src.utility.viewportHandler)
local RarityStyle = require(ReplicatedStorage.src.utility.rarityStyle)

-- Config Modules
local Config = require(ReplicatedStorage.src.GameConfiguration.Gameplay.fuseConfig)
local VariantColors = require(ReplicatedStorage.src.GameConfiguration.General.variantColors)
local VariantGradients = require(ReplicatedStorage.src.GameConfiguration.General.variantGradients)

-->
local Row = {}

-- Public Methods
function Row.Clear(row)
	if row.ResizeConnection then
		row.ResizeConnection:Disconnect()
		row.ResizeConnection = nil
	end
	if row.Viewport then
		row.Viewport:Destroy()
		row.Viewport = nil
	end
	row.Name, row.Variant = nil, nil
end

function Row.Update(row, item)
	local frame = row.Frame
	local variant = item and Config.GetVariant(item)
	local empty = item == nil
	frame.AnimalName.Text = empty and "Empty" or item.Name
	frame.VariantName.Text = empty and "" or variant
	frame.Weight.Text = empty and ""
		or EggHandler.GetWeightKgDisplay(item.Name, item.CustomData and item.CustomData.AssetScale)
	frame.ViewportFrame.Visible = not empty
	local cross = frame:FindFirstChild("X")
	if cross then
		cross.Visible = not empty
	end

	frame.VariantName.TextColor3 = Color3.new(1, 1, 1)
	RarityStyle.ApplyVariant(frame.VariantName, variant)
	local stroke = frame:FindFirstChild("VariantStroke")
	if stroke then
		stroke.Color = variant and VariantColors[variant] or Color3.new(1, 1, 1)
		local gradient = stroke:FindFirstChildOfClass("UIGradient")
		if gradient then
			gradient:Destroy()
		end
		local style = variant and VariantGradients[variant]
		if style then
			stroke.Color = Color3.new(1, 1, 1)
			gradient = Instance.new("UIGradient")
			gradient.Color = style.Color
			gradient.Rotation = style.Rotation or 0
			gradient.Parent = stroke
		end
	end

	if empty then
		Row.Clear(row)
		return
	end
	if row.Name == item.Name and row.Variant == variant then
		return
	end
	Row.Clear(row)
	row.Name, row.Variant = item.Name, variant
	local asset = EggHandler.GetAnimalTemplate(item.Name, variant)
	if asset then
		row.Viewport = ViewportHandler.Setup(frame.ViewportFrame, asset, {
			ClearOnSetup = false,
			NormalizeRotation = true,
			Yaw = 180,
			Pitch = 0,
		})
		row.ResizeConnection = frame.ViewportFrame:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
			row.Viewport:Refit()
		end)
	end
end

return Row
