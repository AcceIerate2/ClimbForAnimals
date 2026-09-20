-- Roblox Services
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Utility Modules
local EggHandler = require(ReplicatedStorage.src.utility.eggHandler)
local ViewportHandler = require(ReplicatedStorage.src.utility.viewportHandler)
local FormatTime = require(ReplicatedStorage.src.utility.FormatTime)

-- Config Modules
local eggConfig = require(ReplicatedStorage.src.GameConfiguration.Gameplay.eggConfig)
local RarityStyle = require(ReplicatedStorage.src.utility.rarityStyle)

-- Constants
local BackgroundBaseColor = Color3.fromRGB(25, 25, 25)
local BackgroundTintStrength = (152 - 25) / (255 - 25) -- Common's white becomes RGB (152, 152, 152).

local Row = {}

function Row.Create(template: Frame, referenceName: string, data, buttons)
	local name = referenceName:split("_")[1]
	if not eggConfig.Eggs[name] then
		return nil
	end

	local frame = template:Clone()
	frame.Name = referenceName
	frame.Visible = true
	frame.Title.Text = name

	local rarity = eggConfig.Eggs[name].Rarity
	local color = RarityStyle.GetTintColor(rarity)
	if color then
		frame.InnerStroke.Background.BackgroundColor3 = BackgroundBaseColor:Lerp(color, BackgroundTintStrength)
	end

	local button = frame:WaitForChild("PurchaseBtn")
	button:SetAttribute("Type", "Action")
	button:SetAttribute("Action", "EggPanelAction")
	button:SetAttribute("ReferenceName", referenceName)
	CollectionService:AddTag(button, "GuiButton")

	local progress = frame:WaitForChild("ProgressBar")
	local row = {
		Frame = frame,
		Button = button,
		ButtonLabel = button:IsA("TextButton") and button or button:FindFirstChildWhichIsA("TextLabel", true),
		Bar = progress:WaitForChild("Bar"),
		Time = progress:WaitForChild("Time"),
		Name = name,
		Data = data,
	}
	row.FullSize = row.Bar.Size

	local subject = EggHandler.GetTemplate(name, data.Variant)
	if subject then
		local viewport = frame.Bar:WaitForChild("ViewportFrame")
		row.Viewport = ViewportHandler.Setup(viewport, subject, {
			ClearOnSetup = false,
			NormalizeRotation = true,
			Yaw = 180, -- camera faces the asset's forward (-Z) direction
			Pitch = 0,
		})
		local preview = row.Viewport.Clone
		preview:PivotTo(preview:GetPivot() * CFrame.Angles(0, math.rad(90), 0))
		row.Viewport:Refit()

		row.ResizeConnection = viewport:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
			row.Viewport:Refit()
		end)
	end

	frame.Parent = template.Parent
	buttons:Link(button)

	return row
end

function Row.Update(row, now: number)
	local duration = row.Data.HatchDuration or EggHandler.GetHatchDuration(row.Name, row.Data.AssetScale)
	local hatchDate = row.Data.HatchDate or (row.Data.PlaceDate + duration)
	local remaining = row.Data.CanHatch and 0 or math.max(0, hatchDate - now)
	local progress = duration > 0 and math.clamp(1 - remaining / duration, 0, 1) or 1
	local full = row.FullSize
	row.Bar.Size = UDim2.new(full.X.Scale * progress, full.X.Offset * progress, full.Y.Scale, full.Y.Offset)
	row.Time.Text = row.Data.CanHatch and "Ready!"
		or (remaining <= 0 and "Finishing..." or FormatTime(math.ceil(remaining), remaining < 3600))

	if row.ButtonLabel then
		row.ButtonLabel.Text = row.Data.CanHatch and "Hatch" or "Skip Timer"
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
