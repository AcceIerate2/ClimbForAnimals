-- Roblox Services
local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Packages
local knit = require(ReplicatedStorage.src.Packages.knit)

-- Utility Modules
local NumberShortner = require(ReplicatedStorage.src.utility.NumberShortner)
local PlayTween = require(ReplicatedStorage.src.utility.PlayTween)

-- Modules
local Popup = require(script.popup)

-- Constants
local AssetsFolder = ReplicatedStorage:WaitForChild("Assets")
local CashIncreaseGui = AssetsFolder:WaitForChild("Gui"):WaitForChild("CashIncrease")
local PopupDuration = 0.9

-->
local CashFlowController = knit.CreateController({
	Name = "CashFlowController",
})

-- Private Methods
function CashFlowController:showIncrease(referenceName: string, increase: number)
	local animal = self.AnimalController.Animals[referenceName]
	if not animal or animal.Revealing or not animal.Asset.Parent or increase <= 0 then
		return
	end

	local asset = animal.Asset
	local root = asset.PrimaryPart
		or asset:FindFirstChild("HumanoidRootPart", true)
		or asset:FindFirstChildWhichIsA("BasePart", true)
	if not root or not root:IsA("BasePart") then
		return
	end

	local camera = workspace.CurrentCamera
	if not camera then
		return
	end

	local _, onScreen = camera:WorldToViewportPoint(asset:GetPivot().Position)
	if not onScreen then
		return
	end

	local startPosition, endPosition = Popup.GetPositions(asset, root)
	local attachment = CashIncreaseGui:Clone() :: Attachment
	attachment.Position = startPosition

	local gui = attachment:FindFirstChild("Gui")
	local canvasGroup = gui and gui:FindFirstChild("CanvasGroup")
	local income = canvasGroup and canvasGroup:FindFirstChild("Income")
	if not gui or not canvasGroup or not income then
		attachment:Destroy()
		return
	end

	local label = income:IsA("TextLabel") and income or income:FindFirstChildWhichIsA("TextLabel", true)
	if not label then
		attachment:Destroy()
		return
	end

	-- Rounded, not floored: the head billboard rounds its /s figure, and NumberShortner floors
	-- anything under 1000, so a 77.72/s animal advertised 78/s used to pop up as +$77.
	label.Text = "+$" .. NumberShortner(math.round(increase))
	income.Visible = true
	canvasGroup.Visible = true
	canvasGroup.GroupTransparency = 0
	gui.Adornee = attachment
	gui.Enabled = true
	attachment.Parent = root

	PlayTween(attachment, TweenInfo.new(PopupDuration, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Position = endPosition,
	})

	PlayTween(canvasGroup, TweenInfo.new(PopupDuration, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
		GroupTransparency = 1,
	})

	-- Parenting to the rig also cleans up immediately if the animal is removed.
	Debris:AddItem(attachment, PopupDuration + 0.1)
end

-- LifeCycle
function CashFlowController:KnitInit()
	self.CashFlowService = knit.GetService("CashFlowService")
	self.AnimalController = knit.GetController("AnimalController")
end

function CashFlowController:KnitStart()
	self.CashFlowService.AnimalCashUpdated:Connect(function(referenceName: string, increase: number)
		self:showIncrease(referenceName, increase)
	end)
end

return CashFlowController
