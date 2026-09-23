-- Server-built (InventoryService) so every player sees it. Shows the whole model in the player's hand, the way the reference game does it: the Tool's
-- Handle is a tiny invisible part that Roblox's grip system welds to the hand, and the visible
-- model is a separate thing welded to that Handle by its visible bottom.
--
-- Scaling is done with Model:ScaleTo, never by resizing a part: the animal rigs are skinned, so
-- changing MeshPart.Size shrinks the mesh while the bones stay put and the animal deforms.

-- Roblox Services
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

-- Utility Modules
local EggHandler = require(ReplicatedStorage.src.utility.eggHandler)

-- Constants
local MaxHeldStuds = 5 -- where the held model starts being shrunk, on its largest axis
local SoftCapExponent = 1 -- how hard it is compressed past that point (1 = no shrinking)
local ForwardRatio = 0.1 -- nudged this fraction of its length forward, out of the body
local EggHeldRotation = CFrame.Angles(0, math.rad(-90), 0) -- turn right around the attachment point
local GripTimeout = 1 -- seconds to wait for the hand weld before giving up
local WeldName = "HeldWeld"

local HeldModel = {}

-- Helper Functions
-- Parts start anchored so nothing can fall while we wait for the grip; the weld replaces the
-- anchor at the end of Attach.
local function prepare(model: Model)
	for _, descendant in ipairs(model:GetDescendants()) do
		if descendant:IsA("BasePart") then
			descendant.Anchored = true
			descendant.CanCollide = false
			descendant.CanTouch = false
			descendant.CanQuery = false
			descendant.Massless = true
		elseif descendant:IsA("BaseScript") or descendant:IsA("ProximityPrompt") then
			descendant:Destroy()
		end
	end
end

local function release(model: Model)
	for _, descendant in ipairs(model:GetDescendants()) do
		if descendant:IsA("BasePart") then
			descendant.Anchored = false
		end
	end
end

local function weldTo(part: BasePart, target: BasePart)
	local previous = part:FindFirstChild(WeldName)
	if previous then
		previous:Destroy()
	end

	local weld = Instance.new("WeldConstraint")
	weld.Name = WeldName
	weld.Part0 = part
	weld.Part1 = target
	weld.Parent = part
end

-- Every part is welded, not only the one that holds the Handle: some models ship a Hitbox beside
-- their mesh, and any part left unwelded just falls away once the model is unanchored.
local function weldAssembly(model: Model, primaryPart: BasePart, handle: BasePart)
	for _, descendant in ipairs(model:GetDescendants()) do
		if descendant:IsA("BasePart") and descendant ~= primaryPart then
			weldTo(descendant, primaryPart)
		end
	end

	weldTo(primaryPart, handle)
end

-- The part everything else hangs from. An egg's PrimaryPart is its Hitbox on purpose (that is
-- what puts the pivot at the bottom), so it is kept; only a model without one has to choose, and
-- there a visible part is preferred over whichever part happens to come first.
local function resolvePrimaryPart(model: Model): BasePart?
	if model.PrimaryPart then
		return model.PrimaryPart
	end

	local fallback = nil
	for _, descendant in ipairs(model:GetDescendants()) do
		if not descendant:IsA("BasePart") then
			continue
		end

		fallback = fallback or descendant
		if descendant.Name ~= "Hitbox" and descendant.Transparency < 1 then
			return descendant
		end
	end

	return fallback
end

-- Visible bounds in the model's own pivot space, ignoring the Hitbox and invisible parts.
-- Falls back to the full bounding box when a model has nothing visible, because GetVisibleBounds
-- returns infinities in that case and every measurement downstream would be garbage.
local function getVisibleBox(model: Model): (CFrame, Vector3, Vector3)
	local pivot = model:GetPivot()
	local minBound, maxBound = EggHandler.GetVisibleBounds(model, pivot)
	local size = maxBound - minBound
	if size.Magnitude ~= size.Magnitude or size.Magnitude == math.huge then
		local boxCFrame, boxSize = model:GetBoundingBox()
		local center = pivot:PointToObjectSpace(boxCFrame.Position)

		return pivot, center - boxSize / 2, boxSize
	end

	return pivot, minBound, size
end

-- A WeldConstraint freezes the offset once, so welding before the grip has moved the Handle into
-- the hand locks the model wherever the Handle happens to be -- and an unwelded Handle is still
-- free-falling, which is how a freshly equipped tool ended up dropping into the void.
local function waitForGrip(tool: Tool, handle: BasePart): boolean
	local deadline = os.clock() + GripTimeout
	repeat
		if tool.Parent == nil then
			return false
		end

		-- Once the grip weld exists the Handle is part of the character's assembly, so it is no
		-- longer its own root.
		local root = handle.AssemblyRootPart
		if root and root ~= handle then
			return true
		end

		RunService.Heartbeat:Wait()
	until os.clock() >= deadline

	return false
end

-- Public Methods
-- Builds the model for a tool and welds it to the Handle. Returns it so the caller can destroy it.
function HeldModel.Attach(tool: Tool, model: Model, rotation: CFrame?): Model?
	local handle = tool:FindFirstChild("Handle")
	local primaryPart = resolvePrimaryPart(model)
	if not handle or not handle:IsA("BasePart") or not primaryPart then
		model:Destroy()
		return nil
	end

	prepare(model)
	model.PrimaryPart = primaryPart

	-- Only the ones that would fill the screen are shrunk, and they are compressed rather than
	-- clamped: a hard ceiling made every animal above it look exactly the same size in the hand,
	-- which hid the size it was actually rolled at.
	local _, _, size = getVisibleBox(model)
	local largestAxis = math.max(size.X, size.Y, size.Z)
	if largestAxis > MaxHeldStuds then
		local fitted = MaxHeldStuds * (largestAxis / MaxHeldStuds) ^ SoftCapExponent
		model:ScaleTo(model:GetScale() * (fitted / largestAxis))
	end

	model.Parent = tool

	if not waitForGrip(tool, handle) or model.Parent ~= tool then
		model:Destroy()
		return nil
	end

	local pivot, minBound, boxSize = getVisibleBox(model)
	local center = minBound + boxSize / 2
	local anchor = pivot * CFrame.new(center.X, minBound.Y, center.Z + boxSize.Z * ForwardRatio)
	model:PivotTo(handle.CFrame * (rotation or CFrame.identity) * anchor:ToObjectSpace(pivot))

	-- Unanchor first and weld second, both in the same frame: a WeldConstraint created against an
	-- anchored part can come up inactive, and the model then drops away the moment it is released.
	release(model)
	weldAssembly(model, primaryPart, handle)

	-- Last resort: if the weld did not take, the part is not in the character's assembly and would
	-- fall into the void. Rebuilding it once on the next frame costs nothing and never loops.
	task.spawn(function()
		-- After a physics step, so the assemblies have actually been rebuilt.
		RunService.Heartbeat:Wait()
		if model.Parent ~= tool or primaryPart.AssemblyRootPart == handle.AssemblyRootPart then
			return
		end

		weldAssembly(model, primaryPart, handle)
	end)

	return model
end

-- The egg keeps the size that was rolled for it; CreateModel also brings the variant aura.
function HeldModel.BuildEgg(tool: Tool): Model?
	local eggName = tool:GetAttribute("ItemName") or tool.Name
	local model = EggHandler.CreateModel(eggName, tool:GetAttribute("Variant"), tool:GetAttribute("AssetScale"))

	return model and HeldModel.Attach(tool, model, EggHeldRotation)
end

function HeldModel.BuildAnimal(tool: Tool): Model?
	local animalName = tool:GetAttribute("ItemName") or tool.Name
	local template = EggHandler.GetAnimalTemplate(animalName, tool:GetAttribute("Variant"))
	if not template then
		return nil
	end

	local model = template:Clone() :: Model
	-- ScaleTo, not MeshPart.Size: these rigs are skinned and would deform otherwise. Same value
	-- the plot uses, so the animal is the same size in the hand and on the ground.
	model:ScaleTo(model:GetScale() * EggHandler.GetVisualScale(tool:GetAttribute("AssetScale")))

	return HeldModel.Attach(tool, model)
end

return HeldModel
