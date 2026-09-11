-- Roblox Services
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Packages
local knit = require(ReplicatedStorage.src.Packages.knit)

-- Utility Modules
local AvatarHeadshot = require(ReplicatedStorage.src.utility.AvatarHeadshot)

-- Constants
local BaseAssets = workspace.Structures.Bases

-- Local Types
type BaseData = {
	Taken: boolean,
	Owner: Player?,
}

-->
local BaseService = knit.CreateService({
	Name = "BaseService",
	MaxBases = #BaseAssets:GetChildren(),
	Bases = {},
})

-- Client Exposed Methods
function BaseService.Client:GetPlayerBase(player: Player)
	return self.Server:GetPlayerBase(player)
end

-- Private Methods
function BaseService:getTakenBases()
	local takenBases = {}
	for baseAsset, baseData: BaseData in pairs(self.Bases) do
		if baseData.Taken then
			table.insert(takenBases, baseAsset)
		end
	end
	return takenBases
end

function BaseService:getAvailableBase()
	for baseAsset, baseData: BaseData in pairs(self.Bases) do
		if not baseData.Taken and not baseData.Owner then
			return baseAsset
		end
	end
	return
end

function BaseService:toggleOverheadGui(base: any, player: Player)
	local taken = player ~= nil
	base.BaseOwner.PlayerName.Enabled = taken

	if taken then
		base.BaseOwner.PlayerName.Frame.PlayerName.Text = player.DisplayName
		base.BaseOwner.PlayerName.Frame.PlayerIcon.Image = AvatarHeadshot(player)
	end
end

-- Public Methods
function BaseService:GetPlayerBase(player: Player)
	for baseAsset: any, baseData: BaseData in pairs(self.Bases) do
		if baseData.Owner == player and baseData.Taken then
			return baseAsset
		end
	end
	return
end

function BaseService:Connect(player: Player)
	if self.MaxBases <= #self:getTakenBases() then
		player:Kick("Couldn't find an available Base - Please rejoin, and try again.")
		return
	end

	local availableBase = self:getAvailableBase()
	self.Bases[availableBase].Owner = player
	self.Bases[availableBase].Taken = true
	self:toggleOverheadGui(availableBase, player)

	if player.Character then
		player.Character:PivotTo(self:GetPlayerBase(player):GetPivot() * CFrame.new(-45, 0, 0))
	end

	return {
		Function = self.Disconnect,
		Args = {
			self,
			player,
		},
	}
end

function BaseService:Disconnect(player: Player) end

-- LifeCycle
function BaseService:KnitInit()
	self.PlayerService = knit.GetService("PlayerService")
end

function BaseService:KnitStart()
	for _, baseAsset in pairs(BaseAssets:GetChildren()) do
		if baseAsset:HasTag("Taken") then
			continue
		end

		baseAsset.BaseOwner.PlayerName.Enabled = false
		self.Bases[baseAsset] = {
			Taken = false,
			Owner = nil,
		}
	end

	-- Listen To Character Resets
	self.PlayerService.CharacterReset:Connect(function(player: Player, newCharacter: any)
		newCharacter:PivotTo(self:GetPlayerBase(player):GetPivot() * CFrame.new(0, 5, 40))
	end)
end

return BaseService
