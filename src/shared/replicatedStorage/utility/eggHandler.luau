-- Roblox Services
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Config Modules
local eggConfig = require(ReplicatedStorage.src.GameConfiguration.Gameplay.eggConfig)
local animalConfig = require(ReplicatedStorage.src.GameConfiguration.Gameplay.animalConfig)

-- Constants
local EggAssets = ReplicatedStorage:WaitForChild("Assets"):WaitForChild("Eggs")
local AnimalAssets = ReplicatedStorage.Assets:WaitForChild("Animals")
local DefaultVariant = "Normal"
local AnimalEggs = nil -- lazily built: animal name -> its egg entry in eggConfig.Eggs

-->
local EggHandler = {}

-- Egg models live in Assets.Eggs.<Variant>.<Biome>.<EggName> (unknown variants use Normal).
-- Falls back to Assets.Eggs.<EggName> for older loose models.
function EggHandler.GetTemplate(eggName: string, variant: string?): Model?
	local eggData = eggConfig.Eggs[eggName]
	local variantFolder = EggAssets:FindFirstChild(variant or DefaultVariant)
		or EggAssets:FindFirstChild(DefaultVariant)
	local biomeFolder = eggData and variantFolder and variantFolder:FindFirstChild(eggData.Biome)
	local template = biomeFolder and biomeFolder:FindFirstChild(eggName)

	return template or EggAssets:FindFirstChild(eggName)
end

-- Animal models live in Assets.Animals.<Variant>.<Biome>.<AnimalName>, using the biome of the
-- egg that hatches them (unknown variants use Normal).
-- Falls back to Assets.Animals.<AnimalName> for older loose models.
-- The egg entry that hatches this animal (Rarity, Biome, HatchDuration, ...).
function EggHandler.GetEggDataForAnimal(animalName: string)
	if not AnimalEggs then
		AnimalEggs = {}
		for eggName: string, eggData in pairs(eggConfig.Eggs) do
			AnimalEggs[eggData.Animal or eggName] = eggData
		end
	end

	return AnimalEggs[animalName]
end

function EggHandler.GetAnimalTemplate(animalName: string, variant: string?): Model?
	local eggData = EggHandler.GetEggDataForAnimal(animalName)
	local biome = eggData and eggData.Biome
	local variantFolder = AnimalAssets:FindFirstChild(variant or DefaultVariant)
		or AnimalAssets:FindFirstChild(DefaultVariant)
	local biomeFolder = biome and variantFolder and variantFolder:FindFirstChild(biome)
	local template = biomeFolder and biomeFolder:FindFirstChild(animalName)

	return template or AnimalAssets:FindFirstChild(animalName)
end

-- Rolled AssetScale -> rendered size multiplier (limits from eggConfig)
function EggHandler.GetVisualScale(assetScale: number?): number
	return math.clamp(assetScale or 1, eggConfig.MinVisualScale, eggConfig.MaxVisualScale)
end

-- Same formula for eggs and animals (like the reference): ModelWeight * AssetScale^3.
-- Accepts an egg name or an animal name.
function EggHandler.GetWeightKg(name: string, assetScale: number?): number
	local eggData = eggConfig.Eggs[name]
	local animalData = animalConfig[eggData and eggData.Animal or name]
	if not animalData or not animalData.ModelWeight then
		return 0
	end

	return animalData.ModelWeight * math.max(assetScale or 1, 0) ^ 3
end

-- Whole number with thousand separators, glued to the unit: 29Kg, 10,925Kg.
-- Only a sub-1Kg roll keeps its decimals, since it would otherwise read as 0Kg.
function EggHandler.GetWeightKgDisplay(name: string, assetScale: number?): string
	local weight = math.max(EggHandler.GetWeightKg(name, assetScale), 0)
	if weight > 0 and weight < 1 then
		return tostring(math.round(weight * 100) / 100) .. "Kg"
	end

	local whole = tostring(math.round(weight))
	whole = whole:reverse():gsub("(%d%d%d)", "%1,"):reverse():gsub("^,", "")

	return whole .. "Kg"
end

-- Bounds of the visible parts only (ignores the invisible Hitbox), in the space of referenceCFrame
function EggHandler.GetVisibleBounds(model: Model, referenceCFrame: CFrame): (Vector3, Vector3)
	local minBound = Vector3.new(math.huge, math.huge, math.huge)
	local maxBound = Vector3.new(-math.huge, -math.huge, -math.huge)

	for _, descendant in ipairs(model:GetDescendants()) do
		if not descendant:IsA("BasePart") or descendant.Name == "Hitbox" or descendant.Transparency >= 1 then
			continue
		end

		local halfSize = descendant.Size / 2
		for _, x in ipairs({ -1, 1 }) do
			for _, y in ipairs({ -1, 1 }) do
				for _, z in ipairs({ -1, 1 }) do
					local worldCorner = descendant.CFrame:PointToWorldSpace(halfSize * Vector3.new(x, y, z))
					local corner = referenceCFrame:PointToObjectSpace(worldCorner)
					minBound = minBound:Min(corner)
					maxBound = maxBound:Max(corner)
				end
			end
		end
	end

	return minBound, maxBound
end

-- Egg models: the Hitbox marks the egg body (same as the reference). Others: visible bounds.
function EggHandler.GetFootprint(model: Model): number
	local hitbox = model:FindFirstChild("Hitbox", true)
	if hitbox then
		return math.max(hitbox.Size.X, hitbox.Size.Z)
	end

	local minBound, maxBound = EggHandler.GetVisibleBounds(model, CFrame.new())
	local size = maxBound - minBound
	return math.max(size.X, size.Z)
end

-- Scales a clone relative to its authored scale and moves its pivot to the bottom (world axis aligned).
-- Pivot X/Z = Hitbox center when the model has one (like the reference EggRenderer), otherwise the visible center.
-- Uses a PrimaryPart so the pivot follows the parts when the model moves (e.g. welded to a player).
function EggHandler.ScaleAndPivotToBottom(model: Model, scaleMultiplier: number)
	local hitbox = model:FindFirstChild("Hitbox", true)
	local primaryPart = hitbox or model.PrimaryPart or model:FindFirstChildWhichIsA("BasePart", true)
	model.PrimaryPart = primaryPart
	primaryPart.PivotOffset = primaryPart.CFrame:ToObjectSpace(CFrame.new(primaryPart.Position))
	model:ScaleTo(model:GetScale() * scaleMultiplier)

	local referenceCFrame = CFrame.new(primaryPart.Position)
	local minBound, maxBound = EggHandler.GetVisibleBounds(model, referenceCFrame)
	local center = (minBound + maxBound) / 2
	local localBottom = hitbox and Vector3.new(0, minBound.Y, 0) or Vector3.new(center.X, minBound.Y, center.Z)
	primaryPart.PivotOffset =
		primaryPart.CFrame:ToObjectSpace(CFrame.new(referenceCFrame:PointToWorldSpace(localBottom)))
end

-- Clone of the egg model with the rolled size applied and the pivot at the bottom.
-- BaseScale attribute = the model scale at its rolled size (growth multiplies this value).
function EggHandler.CreateModel(eggName: string, variant: string?, assetScale: number?): Model?
	local template = EggHandler.GetTemplate(eggName, variant)
	if not template then
		warn(`[EggHandler] Missing egg model {variant or DefaultVariant}/{eggName}`)
		return nil
	end

	local eggModel = template:Clone() :: Model
	EggHandler.ScaleAndPivotToBottom(eggModel, EggHandler.GetVisualScale(assetScale))
	eggModel:SetAttribute("BaseScale", eggModel:GetScale())

	return eggModel
end

return EggHandler
