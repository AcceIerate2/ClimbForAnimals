-- Roblox Services
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Packages
local knit = require(ReplicatedStorage.src.Packages.knit)

-- Utility Modules
local InstanceCreator = require(ReplicatedStorage.src.utility.InstanceCreator)
local NumberShortner = require(ReplicatedStorage.src.utility.NumberShortner)

-- Config Modules
local trailsConfig = require(ReplicatedStorage.src.GameConfiguration.Economy.trailsConfig)

-- Constants
local TrailAssets = ReplicatedStorage:WaitForChild("Assets"):WaitForChild("Trails")
local TrailAnchors = {
	Walk = { "HumanoidRootPart" },
	Climb = { "RightHand", "LeftHand", "RightFoot", "LeftFoot" },
}
local TrailWidths = { -- distance between the two attachments of each trail
	Walk = 1.5,
	Climb = 0.5,
}
local TrailHolderSize = Vector3.new(0.2, 0.2, 0.2)
local TrailHolderName = "TrailHolder"
local DefaultTrailMode = "Walk"

-->
local TrailsService = knit.CreateService({
	Name = "TrailsService",
	Client = {},

	-- Session only (not saved): [Player]: { Mode: string }
	-- Owned and equipped trails are saved in the profile (TrailInventory, EquippedTrail)
	PlayerTrails = {},

	-- Trails currently on a character: [Player]: { [mode]: { Trail } }
	ActiveTrails = {},
})

-- Client Exposed Methods
function TrailsService.Client:GetTrails(player: Player)
	return self.Server:GetTrails(player)
end

function TrailsService.Client:SelectTrail(player: Player, trailName: string)
	return self.Server:SelectTrail(player, trailName)
end

function TrailsService.Client:SetTrailMode(player: Player, mode: string)
	return self.Server:SetTrailMode(player, mode)
end

-- Private Methods
function TrailsService:getPlayerTrails(player: Player)
	if not self.PlayerTrails[player] then
		self.PlayerTrails[player] = {
			Mode = DefaultTrailMode,
		}
	end
	return self.PlayerTrails[player]
end

function TrailsService:getOwnedTrails(player: Player): { [string]: boolean }
	return self.DataService:GetValue(player, "TrailInventory") or {}
end

function TrailsService:getEquippedTrail(player: Player): string?
	local equipped = self.DataService:GetValue(player, "EquippedTrail")
	if equipped == nil or equipped == "" then
		return nil
	end
	return equipped
end

function TrailsService:setEquippedTrail(player: Player, trailName: string?)
	self.DataService:GetValueObject(player, "EquippedTrail"):Set(trailName or "")
end

function TrailsService:purchaseTrail(player: Player, trailName: string)
	local price = trailsConfig.Trails[trailName].Price

	if not self.CashService:CanAfford(player, price) then
		return {
			Status = false,
			Reason = `You need ${NumberShortner(price - self.DataService:GetValue(player, "Cash"))} more!`,
		}
	end

	self.CashService:ManipulatePlayerCash(player, -price, "Addition")

	self.DataService:GetValueObject(player, "TrailInventory"):Update(function(inventory)
		inventory[trailName] = true
	end)
	self:setEquippedTrail(player, trailName)

	return {
		Status = true,
		Result = "Purchased",
	}
end

function TrailsService:removeCharacterTrail(player: Player, character: Model)
	self.ActiveTrails[player] = nil

	for _, child in ipairs(character:GetChildren()) do
		if child.Name == TrailHolderName then
			child:Destroy()
		end
	end
end

function TrailsService:createTrailHolder(anchorPart: BasePart, trailAsset: Trail, width: number): Trail
	local holder = InstanceCreator("Part", TrailHolderName, nil, {
		Size = TrailHolderSize,
		Transparency = 1,
		CanCollide = false,
		CanQuery = false,
		CanTouch = false,
		Massless = true,
		Anchored = false,
		CastShadow = false,
		CFrame = anchorPart.CFrame,
	}) :: BasePart

	InstanceCreator("WeldConstraint", "WeldConstraint", holder, {
		Part0 = anchorPart,
		Part1 = holder,
	})

	local attachment0 = InstanceCreator("Attachment", "TrailAttachment0", holder, {
		Position = Vector3.new(0, width / 2, 0),
	})
	local attachment1 = InstanceCreator("Attachment", "TrailAttachment1", holder, {
		Position = Vector3.new(0, -width / 2, 0),
	})

	local trail = trailAsset:Clone()
	trail.Attachment0 = attachment0
	trail.Attachment1 = attachment1
	trail.Enabled = false
	trail.Parent = holder

	holder.Parent = anchorPart.Parent
	return trail
end

function TrailsService:applyCharacterTrail(player: Player, character: Model?)
	character = character or player.Character
	if not character then
		return
	end

	self:removeCharacterTrail(player, character)

	local equipped = self:getEquippedTrail(player)
	if not equipped then
		return
	end

	local trailAsset = TrailAssets:FindFirstChild(equipped)
	if not trailAsset then
		warn(`[TrailsService] Could not find trail asset for {equipped}`)
		return
	end

	local activeTrails = {}
	for mode: string, anchors: { string } in pairs(TrailAnchors) do
		activeTrails[mode] = {}

		for _, partName: string in ipairs(anchors) do
			local anchorPart = character:WaitForChild(partName, 5) :: BasePart
			if not anchorPart then
				continue
			end

			table.insert(activeTrails[mode], self:createTrailHolder(anchorPart, trailAsset, TrailWidths[mode]))
		end
	end

	self.ActiveTrails[player] = activeTrails
	self:updateTrailMode(player)
end

-- Only the trails of the current mode are enabled (Walk: torso, Climb: hands and feet)
function TrailsService:updateTrailMode(player: Player)
	local activeTrails = self.ActiveTrails[player]
	if not activeTrails then
		return
	end

	local currentMode = self:getPlayerTrails(player).Mode
	for mode: string, trails: { Trail } in pairs(activeTrails) do
		for _, trail: Trail in ipairs(trails) do
			trail.Enabled = mode == currentMode
		end
	end
end

-- Public Methods
function TrailsService:GetTrails(player: Player)
	return {
		Owned = self:getOwnedTrails(player),
		Equipped = self:getEquippedTrail(player),
	}
end

function TrailsService:SelectTrail(player: Player, trailName: string)
	if typeof(trailName) ~= "string" or not trailsConfig.Trails[trailName] then
		return { Status = false, Reason = "Invalid trail!" }
	end

	local response

	if not self:getOwnedTrails(player)[trailName] then
		response = self:purchaseTrail(player, trailName)
	elseif self:getEquippedTrail(player) == trailName then
		self:setEquippedTrail(player, nil)
		response = { Status = true, Result = "Unequipped" }
	else
		self:setEquippedTrail(player, trailName)
		response = { Status = true, Result = "Equipped" }
	end

	if response.Status then
		self:applyCharacterTrail(player)
	end

	local trails = self:GetTrails(player)
	response.Owned = trails.Owned
	response.Equipped = trails.Equipped

	return response
end

function TrailsService:GetEquippedMultiplier(player: Player): number
	local equipped = self:getEquippedTrail(player)
	local trailData = equipped and trailsConfig.Trails[equipped]
	return trailData and trailData.SpeedMultiplier or 1
end

function TrailsService:SetTrailMode(player: Player, mode: string)
	if not TrailAnchors[mode] then
		return
	end

	self:getPlayerTrails(player).Mode = mode
	self:updateTrailMode(player)
end

-- LifeCycle
function TrailsService:KnitInit()
	self.CashService = knit.GetService("CashService")
	self.DataService = knit.GetService("DataService")
	self.PlayerService = knit.GetService("PlayerService")
end

function TrailsService:KnitStart()
	-- Re-apply the equipped trail on join and after every respawn
	self.PlayerService.CharacterReset:Connect(function(player: Player, character: Model)
		self:getPlayerTrails(player).Mode = DefaultTrailMode
		self:applyCharacterTrail(player, character)
	end)

	Players.PlayerRemoving:Connect(function(player: Player)
		self.PlayerTrails[player] = nil
		self.ActiveTrails[player] = nil
	end)
end

return TrailsService
