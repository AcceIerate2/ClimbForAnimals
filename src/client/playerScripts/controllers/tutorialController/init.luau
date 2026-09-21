-- Roblox Services
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")

-- Packages
local knit = require(ReplicatedStorage.src.Packages.knit)

-- Utility Modules
local EggHandler = require(ReplicatedStorage.src.utility.eggHandler)
local Targets = require(ReplicatedStorage.src.utility.tutorialTargets)
local Location = require(ReplicatedStorage.src.utility.tutorialLocation)

-- Config Modules
local Config = require(ReplicatedStorage.src.GameConfiguration.Gameplay.tutorialConfig)
local StaminaConfig = require(ReplicatedStorage.src.GameConfiguration.Economy.staminaUpgradeConfig)

-- Modules
local Guidance = require(script.guidance)
local WorldHighlighter = require(script.worldHighlighter)

-- Constants
local Player = Players.LocalPlayer

-- Helper Functions
local function pivot(instance)
	return Targets.GetCFrame(instance)
end

local function find(root, name)
	return root and root:FindFirstChild(name, true)
end

-->
local TutorialController = knit.CreateController({
	Name = "TutorialController",
	Connections = {},
	Waypoints = {},
	TextRevision = 0,
})

-- Private Methods
function TutorialController:confirmStaminaClosed()
	if self.ClosePending or self.CloseConfirmed or os.clock() < (self.CloseRetryAt or 0) then
		return
	end
	self.ClosePending = true
	self.TutorialService
		:StaminaPanelClosed()
		:andThen(function(accepted)
			self.CloseConfirmed = accepted
		end)
		:catch(warn)
		:finally(function()
			self.ClosePending = false
			self.CloseRetryAt = os.clock() + 1
		end)
end

function TutorialController:setText(key: string)
	local text = Config.Text[key] or key
	if text == self.CurrentText then
		return
	end
	self.CurrentText = text
	self.TextRevision += 1
	local revision = self.TextRevision
	self.Text.Text = text
	self.Text.MaxVisibleGraphemes = 0

	task.spawn(function()
		local lastSound = -math.huge
		local count = 0
		for _ in utf8.graphemes(text) do
			if revision ~= self.TextRevision or not self.Text.Parent then
				return
			end
			count += 1
			self.Text.MaxVisibleGraphemes = count
			if self.WriteSound and os.clock() - lastSound >= Config.WriteSoundInterval then
				self.WriteSound:Play()
				lastSound = os.clock()
			end
			task.wait(Config.TextInterval)
		end
	end)
end

function TutorialController:clearHighlight()
	if self.Highlighted then
		self.UIHighlighterController:Destroy()
	end
	self.Highlighted = nil
	if self.WorldHighlighter then
		self.WorldHighlighter:Clear()
	end
end

function TutorialController:highlight(button)
	if button ~= self.Highlighted then
		self:clearHighlight()
		self.Highlighted = button
	end
	if not button or not button.Parent then
		return
	end

	self.UIHighlighterController:Draw({ Target = button, Padding = Config.HighlightPadding })
end

function TutorialController:findEgg(root)
	local folder = workspace:FindFirstChild("SpawnedEggs")
	local biome = folder
		and folder:FindFirstChild(Location.GetBiome(root.Position) or (self.State and self.State.Biome) or "")
	local selected = self.SelectedEgg
	if selected and selected.Parent == biome then
		local prompt = selected:FindFirstChildWhichIsA("ProximityPrompt", true)
		if prompt and prompt.Enabled then
			return selected
		end
	end
	self.SelectedEgg = nil
	local best, bestDuration, bestDistance
	for _, model in ipairs(biome and biome:GetChildren() or {}) do
		if not model:IsA("Model") or not model:GetAttribute("EggId") then
			continue
		end
		local prompt = model:FindFirstChildWhichIsA("ProximityPrompt", true)
		if not prompt or not prompt.Enabled then
			continue
		end
		local name = model:GetAttribute("EggName")
		local duration = EggHandler.GetHatchDuration(name, model:GetAttribute("AssetScale"))
		local distance = (model:GetPivot().Position - root.Position).Magnitude
		if not best or duration < bestDuration or (duration == bestDuration and distance < bestDistance) then
			best, bestDuration, bestDistance = model, duration, distance
		end
	end
	self.SelectedEgg = best
	return best
end

function TutorialController:update()
	local state = self.State
	if not Config.Enabled or not state or not state.Initialized then
		self.Frame.Visible = false
		self.Guidance:Clear()
		self:clearHighlight()
		return
	end
	if state.Completed then
		self.Guidance:Clear()
		self:clearHighlight()
		if self.WasActive and not self.FinishedAt then
			self.FinishedAt = os.clock()
			self:setText("Finish")
		end
		self.Frame.Visible = self.FinishedAt ~= nil and os.clock() - self.FinishedAt < Config.FinishSeconds
		return
	end

	self.WasActive = true
	if state.Step == "HatchReward" then
		-- Leave the reveal unobstructed while the server keeps the reward pause.
		self.Frame.Visible = false
		self.TextRevision += 1
		self.CurrentText = nil
		if self.WriteSound then self.WriteSound:Stop() end
		self.Guidance:Clear()
		self:clearHighlight()
		return
	end

	self.Frame.Visible = true
	local character = Player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not root or not humanoid or humanoid.Health <= 0 then
		self.Guidance:Clear()
		self:clearHighlight()
		return
	end

	-- Guard stuns pause guidance silently; ordinary jumps/falls keep the current instruction.
	if character:GetAttribute("GuardStunned") or character:HasTag("Knocked") then
		self.Guidance:Clear()
		self:clearHighlight()
		return
	end

	local step, text = state.Step, state.Step
	if step ~= "Steal" then
		self.SelectedEgg = nil
	end
	local parts = workspace:FindFirstChild(Config.PartsFolder)
	local base = self.BaseController:GetBase()
	local targets = {}
	local button
	local worldTarget
	local function point(instance)
		local frame = pivot(instance)
		if frame then
			table.insert(targets, frame)
		end
	end
	local function pointWaypoint(key)
		-- Workspace markers may not have streamed to this client yet, especially at spawn.
		local frame = pivot(find(parts, Config.Parts[key])) or self.Waypoints[key]
		if frame then
			table.insert(targets, frame)
		end
	end
	if step == "Climb" then
		pointWaypoint("Climb")
	elseif step == "Ascend" then
		pointWaypoint("Zone")
	elseif step == "Platform" then
		pointWaypoint("Left")
		pointWaypoint("Right")
	elseif step == "Steal" then
		local egg = self:findEgg(root)
		point(egg)
		if not egg then
			text = "NoEgg"
		end
	elseif step == "Return" or step == "Deposit" then
		local fences = base and base:FindFirstChild("Fences")
		if fences and fences:IsA("Model") then
			local frame = fences:GetBoundingBox()
			table.insert(targets, frame)
		end
	elseif step == "Hatch" then
		local placed = self.DataController:GetValue("PlacedEggs")
		local reference = placed[state.EggReference] and state.EggReference or next(placed)
		point(base and base:FindFirstChild("PlacedEggs") and base.PlacedEggs:FindFirstChild(reference or ""))
		if reference and placed[reference].CanHatch then
			text = "HatchReady"
		end
	elseif step == "Stamina" then
		local panel = Player.PlayerGui.Panels:FindFirstChild("Stamina")
		if panel and panel.Visible then
			local body = panel:FindFirstChild("Body")
			local content = body and body:FindFirstChild("Content")
			local requirements = content and content:FindFirstChild("Requirements")
			button = requirements and requirements:FindFirstChild("PurchaseBtn")
		else
			point(find(base, "StaminaShopCFrame"))
		end
		if Config.IsFreeStamina(state, self.DataController:GetValue("StaminaLevel"), StaminaConfig.BaseLevel) then
			text = "StaminaFree"
		end
	elseif step == "CloseStamina" then
		local panel = Player.PlayerGui.Panels:FindFirstChild("Stamina")
		if panel and panel.Visible then
			local body = panel:FindFirstChild("Body")
			local header = panel:FindFirstChild("Header") or (body and body:FindFirstChild("Header"))
			button = header
				and (
					header:FindFirstChild("Close", true)
					or header:FindFirstChild("Shop")
					or header:FindFirstChildWhichIsA("GuiButton", true)
				)
		elseif panel then
			-- Also handles closing via another UI action or resuming with the panel already closed.
			self:confirmStaminaClosed()
		end
	elseif step == "Treadmill" then
		point(find(base, "TMUpgradeSignCFrame"))
		local gui = find(base, "TreadmillUpgradeGui")
		worldTarget = base and base:FindFirstChild("TreadmillUpgradeSign")
		worldTarget = worldTarget or (gui and (gui.Adornee or gui.Parent))
	elseif step == "Train" then
		point(find(base, "TreadmillCFrame"))
	end

	if worldTarget then
		self:highlight(nil)
		self.WorldHighlighter:Show(worldTarget)
	else
		self.WorldHighlighter:Clear()
		self:highlight(button)
	end
	self.Guidance:Update(root, targets)
	self:setText(text)
end

-- LifeCycle
function TutorialController:KnitInit()
	self.TutorialService = knit.GetService("TutorialService")
	self.DataController = knit.GetController("DataController")
	self.BaseController = knit.GetController("BaseController")
	self.ZoneController = knit.GetController("ZoneController")
	self.UIHighlighterController = knit.GetController("UIHighlighterController")
end

function TutorialController:KnitStart()
	Player:WaitForChild("ClientReady")
	local hud = Player.PlayerGui:WaitForChild("Hud")
	self.Frame = hud:WaitForChild("Tutorial")
	self.Text = self.Frame:WaitForChild("Text")
	self.Frame:WaitForChild("Title").Text = Config.Title
	local template = ReplicatedStorage:WaitForChild("Assets"):WaitForChild("TutorialBeam"):WaitForChild("Beam")
	self.Guidance = Guidance.new(template, Config.Beam)
	self.WorldHighlighter = WorldHighlighter.new(self.UIHighlighterController, Config.HighlightPadding)
	self.TutorialService
		:GetWaypoints()
		:andThen(function(waypoints)
			self.Waypoints = waypoints
			for _, message in ipairs(waypoints.Errors or {}) do
				warn(`Tutorial destination: {message}`)
			end
		end)
		:catch(warn)
	local soundFolder = SoundService:FindFirstChild("Tutorial", true)
	local sound = soundFolder and soundFolder:FindFirstChild("Write")
	if sound then
		self.WriteSound = sound:Clone()
		self.WriteSound.Parent = SoundService
	end
	self.State = self.DataController:GetValue("Tutorial")
	table.insert(
		self.Connections,
		self.DataController:GetValueChangedSignal("Tutorial"):Connect(function(state)
			self.State = state
			self:update()
		end)
	)
	local elapsed = 0
	table.insert(
		self.Connections,
		RunService.Heartbeat:Connect(function(deltaTime)
			elapsed += deltaTime
			if elapsed < Config.UpdateInterval then
				return
			end
			elapsed = 0
			self:update()
		end)
	)
	self:update()
	hud.Destroying:Once(function()
		self.TextRevision += 1
		for _, connection in ipairs(self.Connections) do
			connection:Disconnect()
		end
		self.Guidance:Clear()
		self:clearHighlight()
		if self.WriteSound then
			self.WriteSound:Destroy()
		end
	end)
end

return TutorialController
