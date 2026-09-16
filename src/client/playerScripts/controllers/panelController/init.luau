-- Roblox Services
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

-- Packages
local Signal = require(ReplicatedStorage.src.Packages.Signal)
local knit = require(ReplicatedStorage.src.Packages.knit)

-- Utility Modules
local partOfCharacter = require(ReplicatedStorage.src.utility.partOfCharacter)

-->
local PanelController = knit.CreateController({
	Name = "PanelController",
	TogglePanelSignal = Signal.new(),
	PanelStateChanged = Signal.new(), -- {Visible: boolean, PanelName: string}
	ActivePanel = nil :: string?,
})

-- Public Methods
function PanelController:TogglePanel(panelName: string)
	self.TogglePanelSignal:Fire(panelName)
end

function PanelController:UpdateActivePanel(panelName: string)
	self.ActivePanel = panelName
end

function PanelController:BindHitbox(hitbox: BasePart, panelName: string)
	local wasInHitbox = false

	RunService.Heartbeat:Connect(function()
		local partsInHitbox = workspace:GetPartsInPart(hitbox)
		local playerInHitbox = false

		for _, basePart: BasePart in pairs(partsInHitbox) do
			local player = Players:GetPlayerFromCharacter(partOfCharacter(basePart))
			if player == Players.LocalPlayer then
				playerInHitbox = true
				break
			end
		end

		-- Only act when entering or leaving the hitbox
		if playerInHitbox == wasInHitbox then
			return
		end
		wasInHitbox = playerInHitbox

		if playerInHitbox then
			if self.ActivePanel ~= panelName then
				self:TogglePanel(panelName)
			end
		elseif self.ActivePanel == panelName then
			self:TogglePanel(panelName)
		end
	end)
end

function PanelController:WaitForPanelToClose(panelName: string, timeoutSeconds: number?)
	local hasClosed = false
	local panelStateChangedConnection: RBXScriptConnection? = nil

	local function disconnect()
		if not panelStateChangedConnection then
			return
		end

		panelStateChangedConnection:Disconnect()
		panelStateChangedConnection = nil
	end

	panelStateChangedConnection = self.PanelStateChanged:Connect(function(state: {
		Visible: boolean,
		PanelName: string,
	})
		if state.PanelName ~= panelName or state.Visible then
			return
		end

		hasClosed = true
		disconnect()
	end)

	local startTimeSeconds = os.clock()

	while not hasClosed do
		if timeoutSeconds and (os.clock() - startTimeSeconds) >= timeoutSeconds then
			disconnect()
			return false
		end
		task.wait()
	end
	return true
end

return PanelController
