-- Roblox Services
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local GuiService = game:GetService("GuiService")

-- Packages
local knit = require(ReplicatedStorage.src.Packages.knit)

-- Utility Modules
local PlayTween = require(ReplicatedStorage.src.utility.PlayTween)
local EggHandler = require(ReplicatedStorage.src.utility.eggHandler)

-- Constants
local Player = Players.LocalPlayer
local Gui = Player.PlayerGui:WaitForChild("Weight")
local TemplateFrame = Gui:WaitForChild("Template")
local HoverDistance = 300
local HoverCollisionGroup = "Hover" -- registered in ServerScriptService.world.physics
local CursorOffset = Vector2.new(16, 16)
local GenderIcons = {
	Male = "rbxassetid://73804167581803",
	Female = "rbxassetid://100101680414110",
}
local FadeTweenInfo = TweenInfo.new(0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

-- The ray only collides with the map (so walls occlude the cursor) and with the Animals group,
-- so the mesh under the cursor always wins: a huge animal cannot cover the smaller ones.
local hoverParams = RaycastParams.new()
hoverParams.IgnoreWater = true
hoverParams.CollisionGroup = HoverCollisionGroup

-->
local WeightController = knit.CreateController({
	Name = "WeightController",
})

-- Private Methods
function WeightController:getAnimalWeight(animal): string?
	local state = animal and animal.State
	if not state then
		return nil
	end

	-- The visual size is clamped 0.6x-8x, the weight is not, so this reads the raw rolled scale.
	return EggHandler.GetWeightKgDisplay(state.Name, state.AssetScale or state.Scale)
end

function WeightController:getHoveredAnimal()
	local camera = workspace.CurrentCamera
	if not camera or UserInputService:GetFocusedTextBox() then
		return nil
	end

	local mouseLocation = UserInputService:GetMouseLocation()
	local ray = camera:ViewportPointToRay(mouseLocation.X, mouseLocation.Y)
	local result = workspace:Raycast(ray.Origin, ray.Direction * HoverDistance, hoverParams)
	local hit = result and result.Instance
	if not hit then
		return nil
	end

	for _, animal in pairs(self.AnimalController.Animals) do
		if not animal.Revealing and animal.Asset.Parent and hit:IsDescendantOf(animal.Asset) then
			return animal
		end
	end

	return nil
end

function WeightController:positionEntry(entry)
	if not entry.Animal.Asset.Parent then
		entry.Frame.Visible = false
		return
	end

	local inset = Gui.IgnoreGuiInset and Vector2.zero or GuiService:GetGuiInset()
	local position = UserInputService:GetMouseLocation() - inset + CursorOffset
	entry.Frame.Position = UDim2.fromOffset(position.X, position.Y)
	entry.Frame.Visible = true
end

function WeightController:setHoveredAnimal(animal)
	if self.Current and self.Current.Animal == animal then
		return
	end

	local previous = self.Current
	self.Current = nil
	if previous then
		if previous.GuiTween then
			previous.GuiTween:Cancel()
		end
		if previous.HighlightTween then
			previous.HighlightTween:Cancel()
		end
		PlayTween(previous.Highlight, FadeTweenInfo, { OutlineTransparency = 1 })
		PlayTween(previous.Group, FadeTweenInfo, { GroupTransparency = 1 }, function()
			previous.Frame:Destroy()
			previous.Highlight:Destroy()
		end)
	end

	if not animal then
		return
	end

	local frame = TemplateFrame:Clone()
	frame.Name = "AnimalWeight"
	frame.AnchorPoint = Vector2.zero
	frame.Parent = Gui
	local group = frame:WaitForChild("CanvasGroup")
	group.GroupTransparency = 1

	local label = group:FindFirstChild("Weight")
	if label and label:IsA("TextLabel") then
		label.Text = self:getAnimalWeight(animal) or "--"
	end

	local icon = group:FindFirstChild("Image")
	local genderIcon = GenderIcons[animal.State.Gender]
	if icon and icon:IsA("ImageLabel") then
		icon.Visible = genderIcon ~= nil
		if genderIcon then
			icon.Image = genderIcon
		end
	end

	local highlight = Instance.new("Highlight")
	highlight.Adornee = animal.Asset
	highlight.FillTransparency = 1
	highlight.OutlineColor = Color3.new(1, 1, 1)
	highlight.OutlineTransparency = 1
	highlight.DepthMode = Enum.HighlightDepthMode.Occluded
	highlight.Parent = frame

	local entry = { Animal = animal, Frame = frame, Group = group, Highlight = highlight }
	self.Current = entry
	self:positionEntry(entry)
	entry.GuiTween = PlayTween(group, FadeTweenInfo, { GroupTransparency = 0 }, function()
		entry.GuiTween = nil
	end)
	entry.HighlightTween = PlayTween(highlight, FadeTweenInfo, { OutlineTransparency = 0 }, function()
		entry.HighlightTween = nil
	end)
end

-- LifeCycle
function WeightController:KnitInit()
	self.AnimalController = knit.GetController("AnimalController")
end

function WeightController:KnitStart()
	TemplateFrame.Visible = false

	-- One raycast per frame, like the reference game's ModelMouseHover.
	self.RenderConnection = RunService.RenderStepped:Connect(function()
		self:setHoveredAnimal(self:getHoveredAnimal())

		if self.Current then
			self:positionEntry(self.Current)
		end
	end)

	Gui.Destroying:Once(function()
		self.RenderConnection:Disconnect()
		if self.Current then
			local entry = self.Current
			self.Current = nil
			if entry.GuiTween then
				entry.GuiTween:Cancel()
			end
			if entry.HighlightTween then
				entry.HighlightTween:Cancel()
			end
		end
	end)
end

return WeightController
