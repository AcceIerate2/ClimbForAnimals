-- Roblox Services
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Packages
local knit = require(ReplicatedStorage.src.Packages.knit)

-- Utility Modules
local InstanceCreator = require(ReplicatedStorage.src.utility.InstanceCreator)

-- Constants
local Bases = workspace.Structures.Bases
local Fences = ReplicatedStorage.Assets.Fences

-- Local Types
type BaseData = {
	Taken: boolean,
	Owner: Player?,
	DefaultFences: Model?,
	GateColors: { [BasePart]: Color3 },
}

-->
local BaseService = knit.CreateService({
	Name = "BaseService",
	MaxBases = #Bases:GetChildren(),
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
		local success, image = pcall(function()
			return Players:GetUserThumbnailAsync(
				player.UserId,
				Enum.ThumbnailType.HeadShot,
				Enum.ThumbnailSize.Size420x420
			)
		end)

		if success and self.Bases[base].Owner == player then
			base.BaseOwner.PlayerName.Frame.PlayerIcon.Image = image
		end
	else
		base.BaseOwner.PlayerName.Frame.PlayerName.Text = ""
		base.BaseOwner.PlayerName.Frame.PlayerIcon.Image = ""
	end
end

-- Public Methods
function BaseService:ToggleBaseModel(player: Player, level: number)
	local playerBase = self:GetPlayerBase(player)

	local assetToRemove = playerBase:FindFirstChild("Fences")
	if assetToRemove then
		assetToRemove:Destroy()
	end

	local fencesAsset = Fences:FindFirstChild(`Level_{level}`):Clone()
	fencesAsset.Name = "Fences"
	fencesAsset:PivotTo(playerBase.FencesCFrame:GetPivot() * CFrame.new(4.75, 0, 0) * CFrame.Angles(0, math.rad(90), 0))
	fencesAsset.Parent = playerBase

	-- Update Gate Color
	if level >= 8 then
		local function colorKey(color: Color3)
			return string.format(
				"%d,%d,%d",
				math.round(color.R * 255),
				math.round(color.G * 255),
				math.round(color.B * 255)
			)
		end

		local originalColor1 = Color3.fromRGB(225, 116, 66)
		local originalColor2 = Color3.fromRGB(152, 80, 45)

		local level8Color1 = Color3.fromRGB(159, 161, 172)
		local level8Color2 = Color3.fromRGB(202, 203, 209)

		local level9Color1 = Color3.fromRGB(9, 137, 207)
		local level9Color2 = Color3.fromRGB(4, 175, 236)

		local level10Color1 = Color3.fromRGB(160, 132, 79)
		local level10Color2 = Color3.fromRGB(239, 184, 56)

		local gateColorConfig = {}

		if level == 8 then
			gateColorConfig[colorKey(originalColor1)] = level8Color1
			gateColorConfig[colorKey(originalColor2)] = level8Color2
		elseif level == 9 then
			gateColorConfig[colorKey(originalColor1)] = level9Color1
			gateColorConfig[colorKey(originalColor2)] = level9Color2

			gateColorConfig[colorKey(level8Color1)] = level9Color1
			gateColorConfig[colorKey(level8Color2)] = level9Color2
		elseif level == 10 then
			gateColorConfig[colorKey(originalColor1)] = level10Color1
			gateColorConfig[colorKey(originalColor2)] = level10Color2

			gateColorConfig[colorKey(level8Color1)] = level10Color1
			gateColorConfig[colorKey(level8Color2)] = level10Color2

			gateColorConfig[colorKey(level9Color1)] = level10Color1
			gateColorConfig[colorKey(level9Color2)] = level10Color2
		end

		local leftGateDeco = playerBase.Gate.Left.Deco
		local rightGateDeco = playerBase.Gate.Right.Deco

		local function applyGateColors(deco)
			for _, basePart in deco:GetDescendants() do
				if not basePart:IsA("BasePart") then
					continue
				end

				local newColor = gateColorConfig[colorKey(basePart.Color)]

				if newColor then
					basePart.Color = newColor
				end
			end
		end

		applyGateColors(leftGateDeco)
		applyGateColors(rightGateDeco)
	end

	return fencesAsset
end

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

	local baseLevel = self.DataService:GetValue(player, "BaseLevel")
	self:ToggleBaseModel(player, baseLevel)
	self:toggleOverheadGui(availableBase, player)
	if self.Bases[availableBase].Owner ~= player then
		return
	end

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

function BaseService:Disconnect(player: Player)
	local base = self:GetPlayerBase(player)
	if not base then
		return
	end

	local baseData = self.Bases[base]
	self:toggleOverheadGui(base, nil)

	for _, folderName in ipairs({ "PlacedEggs", "Animals" }) do
		local folder = base:FindFirstChild(folderName)
		if folder then
			folder:ClearAllChildren()
		end
	end

	local fences = base:FindFirstChild("Fences")
	if fences then
		fences:Destroy()
	end

	if baseData.DefaultFences then
		baseData.DefaultFences:Clone().Parent = base
	end

	for part, color in pairs(baseData.GateColors) do
		if part.Parent then
			part.Color = color
		end
	end

	baseData.Owner = nil
	baseData.Taken = false
end

-- LifeCycle
function BaseService:KnitInit()
	self.PlayerService = knit.GetService("PlayerService")
	self.DataService = knit.GetService("DataService")
end

function BaseService:KnitStart()
	for _, baseAsset in pairs(Bases:GetChildren()) do
		if baseAsset:HasTag("Taken") then
			continue
		end

		baseAsset.BaseOwner.PlayerName.Enabled = false
		InstanceCreator("Folder", "PlacedEggs", baseAsset)
		InstanceCreator("Folder", "Animals", baseAsset)

		local gateColors = {}
		for _, deco in ipairs({ baseAsset.Gate.Left.Deco, baseAsset.Gate.Right.Deco }) do
			for _, part in ipairs(deco:GetDescendants()) do
				if part:IsA("BasePart") then
					gateColors[part] = part.Color
				end
			end
		end

		local fences = baseAsset:FindFirstChild("Fences")
		self.Bases[baseAsset] = {
			Taken = false,
			Owner = nil,
			DefaultFences = fences and fences:Clone(),
			GateColors = gateColors,
		}
	end

	-- Listen To Character Resets
	self.PlayerService.CharacterReset:Connect(function(player: Player, newCharacter: any)
		local base = self:GetPlayerBase(player)
		if base then
			newCharacter:PivotTo(base:GetPivot() * CFrame.new(0, 5, 40))
		end
	end)
end

return BaseService
