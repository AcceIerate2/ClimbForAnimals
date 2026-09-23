-- Roblox Services
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Config Modules
local eggConfig = require(ReplicatedStorage.src.GameConfiguration.Gameplay.eggConfig)
local animalConfig = require(ReplicatedStorage.src.GameConfiguration.Gameplay.animalConfig)

-- Constants
local EggAssets = ReplicatedStorage:WaitForChild("Assets"):WaitForChild("Eggs")
local AnimalAssets = ReplicatedStorage.Assets:WaitForChild("Animals")
local EggVariantVfxs = EggAssets:FindFirstChild("VariantsVfxs")
local AnimalVariantVfxs = AnimalAssets:FindFirstChild("VariantsVfxs")
local DefaultVariant = "Normal"
local AnimalEggs = nil -- lazily built: animal name -> its egg entry in eggConfig.Eggs

-- Helper Functions
-- The variant auras are Attachments holding a ParticleEmitter, so they parent straight onto a
-- part and need no invisible holder. Applied BEFORE any ScaleTo: Roblox scales a
-- ParticleEmitter's Size along with the model, so the aura follows the rolled size for free.
local function applyVariantVfx(model: Model, variant: string?, vfxFolder: Folder?)
	local template = variant and vfxFolder and vfxFolder:FindFirstChild(variant)
	if not template then
		return -- the plain variant has no aura
	end

	local anchor = model:FindFirstChild("Hitbox", true)
		or model.PrimaryPart
		or model:FindFirstChildWhichIsA("BasePart", true)
	if not anchor then
		return
	end

	local aura = template:Clone()
	-- An Attachment's Position becomes relative to whatever part it is parented to, and these
	-- templates were authored out in the world, so the egg ones carried a ~1035 stud offset and
	-- emitted far away from the egg. The anchor already sits at the model's centre.
	aura.CFrame = CFrame.identity
	aura.Parent = anchor
end

-->
local EggHandler = {}

-- Variant aura for a rendered animal. Must run before the model is scaled.
function EggHandler.ApplyAnimalVariantVfx(model: Model, variant: string?)
	applyVariantVfx(model, variant, AnimalVariantVfxs)
end

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

-- The egg entry that hatches this animal (Rarity, Biome, HatchDuration, ...).
-- A bigger egg takes proportionally longer to hatch, mirroring the reference
-- (EggItemUtil.getSizeGrowthMultiplier): flat below 2x, a steep curve up to 6x, then a gentler
-- one capped at 20x. The two curves meet exactly at 6x, so there is no step.
local GrowthFlatScale = 2
local GrowthMidScale = 6
local GrowthMidExponent = 1.389
local GrowthHighExponent = 0.72
local GrowthHighMultiplier = 4.6
local GrowthMaxMultiplier = 20

function EggHandler.GetGrowthMultiplier(assetScale: number?): number
	local scale = typeof(assetScale) == "number" and assetScale or 1
	if scale <= GrowthFlatScale then
		return 1
	end

	if scale <= GrowthMidScale then
		return (scale / GrowthFlatScale) ^ GrowthMidExponent
	end

	return math.min((scale / GrowthMidScale) ^ GrowthHighExponent * GrowthHighMultiplier, GrowthMaxMultiplier)
end

-- The hatch time an egg of this size really takes. Every side that shows or counts the timer
-- has to go through here, or the countdown and the hatch disagree.
function EggHandler.GetHatchDuration(eggName: string, assetScale: number?): number
	local eggData = eggConfig.Eggs[eggName]
	if not eggData then
		return 0
	end

	return eggData.HatchDuration * EggHandler.GetGrowthMultiplier(assetScale)
end

function EggHandler.GetEggDataForAnimal(animalName: string)
	if not AnimalEggs then
		AnimalEggs = {}
		for eggName: string, eggData in pairs(eggConfig.Eggs) do
			AnimalEggs[eggData.Animal or eggName] = eggData
		end
	end

	return AnimalEggs[animalName]
end

-- Animal models live in Assets.Animals.<Variant>.<Biome>.<AnimalName>, using the biome of the
-- egg that hatches them (unknown variants use Normal).
-- Falls back to Assets.Animals.<AnimalName> for older loose models.
function EggHandler.GetAnimalTemplate(animalName: string, variant: string?): Model?
	local eggData = EggHandler.GetEggDataForAnimal(animalName)
	local biome = eggData and eggData.Biome
	local variantFolder = AnimalAssets:FindFirstChild(variant or DefaultVariant)
		or AnimalAssets:FindFirstChild(DefaultVariant)
	local biomeFolder = biome and variantFolder and variantFolder:FindFirstChild(biome)
	local template = biomeFolder and biomeFolder:FindFirstChild(animalName)

	-- Exclusives have no egg and no variants: a single model under Assets.Animals.Exclusives.
	local exclusives = AnimalAssets:FindFirstChild("Exclusives")
	return template or AnimalAssets:FindFirstChild(animalName) or (exclusives and exclusives:FindFirstChild(animalName))
end

-- Rarity lives on the egg entry, so an animal borrows its egg's. Accepts either name.
-- An animal with no egg (the exclusives) carries its own Rarity in animalConfig.
function EggHandler.GetRarity(name: string): string?
	local eggData = eggConfig.Eggs[name] or EggHandler.GetEggDataForAnimal(name)
	if eggData then
		return eggData.Rarity
	end

	local animalData = animalConfig[name]
	return animalData and animalData.Rarity
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
-- Neither of these reads the Hitbox: a Hitbox encloses its mesh in the mesh's OWN axes, and
-- plenty of egg meshes are authored lying down, so its Size says 1.31 where the egg really
-- covers 6.03 studs. Only the visible bounds answer these questions.

-- Widest world-space axis the model covers on the ground: how much room it needs, so two eggs
-- spawned side by side never overlap.
function EggHandler.GetFootprint(model: Model): number
	local minBound, maxBound = EggHandler.GetVisibleBounds(model, CFrame.new())
	local size = maxBound - minBound

	return math.max(size.X, size.Z)
end

-- Narrowest world-space axis: how wide the model actually SITS. Wings, tails and spikes stick
-- out past this and are meant to overhang the nest's rim -- sizing a nest by the widest axis
-- instead gave a winged egg a nest as wide as its wingspan. The reference does the same thing in
-- spirit: its GetFitScaleForContainer picks the most restrictive axis, not the widest.
function EggHandler.GetSeatWidth(model: Model): number
	local minBound, maxBound = EggHandler.GetVisibleBounds(model, CFrame.new())
	local size = maxBound - minBound

	return math.min(size.X, size.Z)
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
	applyVariantVfx(eggModel, variant, EggVariantVfxs)
	EggHandler.ScaleAndPivotToBottom(eggModel, EggHandler.GetVisualScale(assetScale))
	eggModel:SetAttribute("BaseScale", eggModel:GetScale())
	eggModel:SetAttribute("Variant", variant or DefaultVariant)

	return eggModel
end

return EggHandler
