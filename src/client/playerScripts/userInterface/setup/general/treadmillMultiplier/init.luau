-- Roblox Services
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Packages
local knit = require(ReplicatedStorage.src.Packages.knit)

-- Utility Modules
local Spring = require(ReplicatedStorage.src.utility.Spring)
local PlayTween = require(ReplicatedStorage.src.utility.PlayTween)

-- Helper Functions
local function getPosition()
	local x = math.random(30, 70) / 100
	local y = math.random(30, 70) / 100
	return UDim2.fromScale(x, y)
end

-->
local TreadmillMultiplier = {
	BonusFrames = {},
}

-- LifeCycle
function TreadmillMultiplier:Init(player: Player)
	self.Container = player.PlayerGui:WaitForChild("General")
	self.Template = self.Container:WaitForChild("BonusClick")

	self.ButtonsController = knit.GetController("ButtonsController")
	self.TreadmillController = knit.GetController("TreadmillController")

	self.TreadmillController.Signals.TreadmillDeactivated:Connect(function()
		for _, bonusFrame in pairs(self.BonusFrames) do
			local button = bonusFrame:FindFirstChildOfClass("ImageButton")
			if button then
				self.ButtonsController:Unlink(button)
			end
			bonusFrame:Destroy()
		end
		table.clear(self.BonusFrames)
	end)

	self.TreadmillController.Signals.ShowMultiplierButton:Connect(function(guid: string, session: string)
		-- Local signals may run after the server listener, so validate at creation too.
		if not self.TreadmillController:IsCurrentTreadmillSession(session) then
			return
		end

		local newBonusFrame = self.Template:Clone()
		newBonusFrame.Name = guid
		newBonusFrame.Position = getPosition()

		local defaultSize = self.Template.Size
		newBonusFrame.Size = UDim2.fromScale(0, 0)

		local button = newBonusFrame:WaitForChild("ImageButton")
		button:AddTag("GuiButton")
		button:SetAttribute("Type", "Action")
		button:SetAttribute("Action", "ClaimTmMultiplier")
		button:SetAttribute("Id", guid)
		self.ButtonsController:Link(button)

		-- Button setup can yield. Never publish a prompt whose ride ended meanwhile.
		if not self.TreadmillController:IsCurrentTreadmillSession(session) then
			self.ButtonsController:Unlink(button)
			newBonusFrame:Destroy()
			return
		end

		newBonusFrame.Visible = true
		newBonusFrame.Parent = self.Container

		PlayTween(newBonusFrame, TweenInfo.new(0.75, Enum.EasingStyle.Linear, Enum.EasingDirection.In, -1, true, 0), {
			Rotation = 20,
		})

		Spring.target(newBonusFrame, 0.75, 4, {
			Size = defaultSize,
		})

		table.insert(self.BonusFrames, newBonusFrame)
	end)
end

return TreadmillMultiplier
