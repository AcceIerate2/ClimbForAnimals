-- Roblox Services
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Utility Modules
local EggHandler = require(ReplicatedStorage.src.utility.eggHandler)
local ViewportHandler = require(ReplicatedStorage.src.utility.viewportHandler)
local NumberShortner = require(ReplicatedStorage.src.utility.NumberShortner)
local RarityStyle = require(ReplicatedStorage.src.utility.rarityStyle)

-- Constants
local BackgroundBaseColor = Color3.fromRGB(25, 25, 25)
local BackgroundTintStrength = (152 - 25) / (255 - 25)
local PlotColor = Color3.fromRGB(85, 255, 0)
local BackpackColor = Color3.fromRGB(255, 255, 255)

-- Helper Functions
local function textLabel(object)
	return (object:IsA("TextLabel") or object:IsA("TextButton")) and object
		or object:FindFirstChildWhichIsA("TextLabel", true)
end

-->
local Row = {}

-- Public Methods
function Row.Create(template: Frame, referenceName: string, buttons)
	local frame = template:Clone()
	frame.Name = referenceName
	frame.Visible = true
	local button = frame.SellBtn
	button:SetAttribute("Type", "Action")
	button:SetAttribute("Action", "SellAnimal")
	button:SetAttribute("ReferenceName", referenceName)
	CollectionService:AddTag(button, "GuiButton")
	frame.Parent = template.Parent
	buttons:Link(button)

	return { Frame = frame, Button = button, ButtonLabel = textLabel(button) }
end

function Row.Update(row, item, onPlot: boolean, quote, pending: boolean)
	local frame = row.Frame
	local custom = item.CustomData or {}
	local variant = item.Variant or custom.Variant or "Normal"
	local rarity = EggHandler.GetRarity(item.Name)
	frame.ItemName.Text = item.Name
	frame.IncomePerSecond.Text = quote and `${NumberShortner(math.round(quote.Income))}/s` or ""
	frame.Locked.Visible = quote == nil
	row.Button.Interactable = quote ~= nil and not pending
	row.Button.Active = row.Button.Interactable
	if row.ButtonLabel then
		row.ButtonLabel.Text = quote and `${NumberShortner(quote.Price)}` or "Can't Sell"
	end

	local status = frame.View.Status
	local label = textLabel(status)
	if label then
		label.Text = onPlot and "Plot" or "Backpack"
		label.TextColor3 = Color3.fromRGB(255, 255, 255)
		label.BackgroundTransparency = 0.45
	end
	status.BackgroundColor3 = onPlot and PlotColor or BackpackColor
	status.BackgroundTransparency = 0.45
	if status:IsA("ImageLabel") then
		status.ImageColor3 = status.BackgroundColor3
	end

	if row.Rarity ~= rarity then
		row.Rarity = rarity
		frame.Rarity.Text = rarity or ""
		RarityStyle.ApplyRarity(frame.Rarity, rarity)
		local color = RarityStyle.GetTintColor(rarity)
		if color then
			local background = frame.Background
			local tint = BackgroundBaseColor:Lerp(color, BackgroundTintStrength)
			background.BackgroundColor3 = tint
			if background:IsA("ImageLabel") then
				background.ImageColor3 = tint
			end
		end
	end

	if row.Name == item.Name and row.Variant == variant and row.Handler == item.Handler then
		return
	end
	if row.ResizeConnection then
		row.ResizeConnection:Disconnect()
	end
	if row.Viewport then
		row.Viewport:Destroy()
		row.Viewport = nil
	end
	row.Name, row.Variant, row.Handler = item.Name, variant, item.Handler
	local subject
	if item.Handler == "Animal" then
		subject = EggHandler.GetAnimalTemplate(item.Name, variant)
	else
		subject = EggHandler.GetTemplate(item.Name, variant)
	end
	if subject then
		local viewport = frame.View.ViewportFrame
		row.Viewport = ViewportHandler.Setup(viewport, subject, {
			ClearOnSetup = false,
			NormalizeRotation = true,
			Yaw = 180,
			Pitch = 0,
		})
		if item.Handler == "Egg" then
			local model = row.Viewport.Clone
			model:PivotTo(model:GetPivot() * CFrame.Angles(0, math.rad(90), 0))
			row.Viewport:Refit()
		end
		row.ResizeConnection = viewport:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
			row.Viewport:Refit()
		end)
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
