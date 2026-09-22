-- Highlights an egg while its prompt is on screen, for both prompts an egg can have: stealing
-- one in the world and hatching one on the plot.

-- Roblox Services
local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Packages
local knit = require(ReplicatedStorage.src.Packages.knit)

-- Constants
local HighlightTemplate = ReplicatedStorage:WaitForChild("Assets"):WaitForChild("Eggs"):WaitForChild("Highlight")
-- The folders eggs live in: spawned eggs in the world, placed eggs on a plot.
local EggFolders = { SpawnedEggs = true, PlacedEggs = true }

-->
local EggHighlightController = knit.CreateController({
	Name = "EggHighlightController",
	Highlights = {} :: { [ProximityPrompt]: Highlight },
})

-- Private Methods
-- Walks up to the model the prompt belongs to and only accepts it if that model sits inside an
-- egg folder. Matching on the folder instead of the prompt name covers both prompts today (they
-- are named differently) and any egg prompt added later.
function EggHighlightController:findEgg(prompt: ProximityPrompt): Model?
	local link = prompt:FindFirstChild("Egg")
	if link and link:IsA("ObjectValue") and link.Value and link.Value:IsA("Model") then
		return link.Value
	end

	local instance: Instance? = prompt.Parent
	while instance and instance ~= workspace do
		if instance:IsA("Model") then
			local folder = instance.Parent
			while folder and folder ~= workspace do
				if EggFolders[folder.Name] then
					return instance
				end
				folder = folder.Parent
			end

			return nil
		end

		instance = instance.Parent
	end

	return nil
end

function EggHighlightController:show(prompt: ProximityPrompt)
	if self.Highlights[prompt] then
		return
	end

	local egg = self:findEgg(prompt)
	if not egg then
		return
	end

	local highlight = HighlightTemplate:Clone() :: Highlight
	highlight.Adornee = egg
	highlight.Parent = egg
	self.Highlights[prompt] = highlight

	-- Being a child of the egg, the highlight dies with it when the egg is stolen or hatched;
	-- this drops the map entry so the destroyed prompt is not kept alive as a key.
	highlight.Destroying:Once(function()
		if self.Highlights[prompt] == highlight then
			self.Highlights[prompt] = nil
		end
	end)
end

function EggHighlightController:hide(prompt: ProximityPrompt)
	local highlight = self.Highlights[prompt]
	if not highlight then
		return
	end

	self.Highlights[prompt] = nil
	highlight:Destroy()
end

-- LifeCycle
function EggHighlightController:KnitStart()
	ProximityPromptService.PromptShown:Connect(function(prompt: ProximityPrompt)
		self:show(prompt)
	end)

	ProximityPromptService.PromptHidden:Connect(function(prompt: ProximityPrompt)
		self:hide(prompt)
	end)
end

return EggHighlightController
