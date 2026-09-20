-- Roblox Services
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Packages
local Signal = require(ReplicatedStorage.src.Packages.Signal)
local knit = require(ReplicatedStorage.src.Packages.knit)

-- Constants
local Player = Players.LocalPlayer
local PollInterval = 0.1
-- How far above the pad still counts as standing on it, so a jump or a knockback does not read
-- as leaving.
local VerticalSlack = 12

-->
local PanelController = knit.CreateController({
	Name = "PanelController",
	TogglePanelSignal = Signal.new(),
	PanelStateChanged = Signal.new(), -- {Visible: boolean, PanelName: string}
	ActivePanel = nil :: string?,
	Pads = {}, -- [BasePart]: { PanelName: string, Opened: boolean }
	CurrentPad = nil :: BasePart?,
})

-- Private Methods
-- Standing on a pad is a vertical question, not a distance one, so the test is the part's own
-- footprint plus slack above it, measured in the part's space. It is arithmetic rather than a
-- spatial query on purpose: these hitboxes carry the TransparentPart tag, which sets
-- CanQuery = false, so neither a raycast nor an overlap query can ever see them.
function PanelController:isOnPad(rootPosition: Vector3, hitbox: BasePart): boolean
	local localPosition = hitbox.CFrame:PointToObjectSpace(rootPosition)
	local half = hitbox.Size / 2

	return math.abs(localPosition.X) <= half.X
		and math.abs(localPosition.Z) <= half.Z
		and localPosition.Y >= -half.Y
		and localPosition.Y <= half.Y + VerticalSlack
end

function PanelController:findPad(): BasePart?
	local character = Player.Character
	local rootPart = character and character:FindFirstChild("HumanoidRootPart")
	if not rootPart then
		return nil
	end

	local rootPosition = rootPart.Position
	for hitbox in pairs(self.Pads) do
		if hitbox.Parent and self:isOnPad(rootPosition, hitbox) then
			return hitbox
		end
	end

	return nil
end

-- Stepping from one pad onto another only fires the new pad's entry: PanelToggler already closes
-- whatever was open when it opens something else, so announcing the exit first would play a
-- redundant closing animation.
function PanelController:enterPad(hitbox: BasePart)
	local pad = self.Pads[hitbox]
	self.CurrentPad = hitbox

	if self.ActivePanel == pad.PanelName then
		pad.Opened = true
		return
	end

	-- Until the panel has actually opened once, keep asking: the first request can land before the
	-- interface is listening. Once it has opened, closing it by hand has to stick.
	if not pad.Opened then
		self:TogglePanel(pad.PanelName)
	end
end

function PanelController:leavePad()
	local hitbox = self.CurrentPad
	local pad = hitbox and self.Pads[hitbox]
	self.CurrentPad = nil
	if not pad then
		return
	end

	pad.Opened = false
	if self.ActivePanel == pad.PanelName then
		self:TogglePanel(pad.PanelName)
	end
end

function PanelController:startPadLoop()
	if self.PadLoop then
		return
	end

	self.PadLoop = task.spawn(function()
		while true do
			local hitbox = self:findPad()
			if hitbox then
				self:enterPad(hitbox)
			elseif self.CurrentPad then
				self:leavePad()
			end

			task.wait(PollInterval)
		end
	end)
end

-- Public Methods
function PanelController:TogglePanel(panelName: string)
	self.TogglePanelSignal:Fire(panelName)
end

function PanelController:UpdateActivePanel(panelName: string)
	self.ActivePanel = panelName
end

function PanelController:BindHitbox(hitbox: BasePart, panelName: string)
	self.Pads[hitbox] = { PanelName = panelName, Opened = false }

	hitbox.Destroying:Once(function()
		if self.CurrentPad == hitbox then
			self:leavePad()
		end

		self.Pads[hitbox] = nil
	end)

	self:startPadLoop()
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
