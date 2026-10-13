-- Roblox Services
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")
local RunService = game:GetService("RunService")

-- Packages
local knit = require(ReplicatedStorage.src.Packages.knit)

-- Utility Modules
local EggHandler = require(ReplicatedStorage.src.utility.eggHandler)

-- Config Modules
local Config = require(ReplicatedStorage.src.GameConfiguration.Gameplay.fuseConfig)

-->
local FuseService = knit.CreateService({
	Name = "FuseService",
	Client = { Completed = knit.CreateSignal() },
	Pending = {},
	LastRequest = {},
})

-- Client Exposed Methods
function FuseService.Client:SetSlot(player: Player, slot: number, reference: string?)
	return self.Server:SetSlot(player, slot, reference)
end

-- Private Methods
function FuseService:isReady(player: Player): boolean
	local profile = self.ProfileStoreService:getProfile(player)
	return profile ~= nil
		and profile:IsActive()
		and self.DataService:GetProfile(player) ~= nil
		and self.AnimalService.Profiles[player] ~= nil
		and player:FindFirstChild("Synced") ~= nil
end

function FuseService:save(player: Player, state)
	self.DataService:GetValueObject(player, "Fuse"):Set(state)
end

function FuseService:complete(player: Player, state): boolean
	if not state.FinishAt or os.time() < state.FinishAt then
		return false
	end

	local inventory = self.DataService:GetValue(player, "Inventory")
	local changed = false
	for slot, reference in pairs(state.Slots) do
		if not inventory[reference] then
			state.Slots[slot] = nil
			changed = true
		end
	end
	if changed then
		state.FinishAt = nil
		state.Remaining = nil
		self:save(player, state)
		return false
	end

	local result = Config.GetResult(state, inventory)
	if not result or not EggHandler.GetAnimalTemplate(result.Name, result.CustomData.Variant) then
		-- Keep every input owned and removable if an asset/config changes during a fuse.
		state.FinishAt = nil
		self:save(player, state)
		return false
	end

	local reference = `{result.Name}_{HttpService:GenerateGUID(false)}`
	for _, selected in pairs(state.Slots) do
		inventory[selected] = nil
	end
	inventory[reference] = result

	-- No yielding between inventory replacement and clearing the job. The three inputs
	-- and result share one ProfileStore session; a repeated tick cannot grant twice.
	self.DataService:GetValueObject(player, "Inventory"):Set(inventory)
	self:save(player, { Slots = {} })
	self.InventoryService:StoreInBackpack(player, reference, "Animal")
	self.IndexService:Discover(player, result.Name)
	self.Client.Completed:Fire(player, result.Name, result.CustomData.Variant)
	return true
end

function FuseService:setSlot(player: Player, slot: number, reference: string?)
	if not Config.Enabled or not self:isReady(player) then
		return { Status = false, Reason = "The fuse machine is still loading or unavailable." }
	end
	if type(slot) ~= "number" or slot ~= slot or slot ~= math.floor(slot) or slot < 1 or slot > Config.SlotCount then
		return { Status = false, Reason = "Invalid fuse slot." }
	end
	if reference ~= nil and (type(reference) ~= "string" or #reference > 256) then
		return { Status = false, Reason = "Invalid animal." }
	end

	local state = self.DataService:GetValue(player, "Fuse")
	if self:complete(player, state) then
		return { Status = false, Reason = "Your fusion has already finished!" }
	end
	state = self.DataService:GetValue(player, "Fuse")
	local inventory = self.DataService:GetValue(player, "Inventory")
	local key = tostring(slot)
	local oldReference = state.Slots[key]
	if reference then
		if oldReference or Config.IsSelected(state, reference) then
			return { Status = false, Reason = "This animal or slot is already selected." }
		end
		local item = inventory[reference]
		if not Config.CanSelect(item, state, inventory) then
			return {
				Status = false,
				Reason = "Choose three animals of the same species and variant. Ruby is the highest tier.",
			}
		end
		if self.EggHatchService:IsRevealing(player, reference) then
			return { Status = false, Reason = "Wait for this animal's reveal to finish." }
		end
		local variant = Config.GetNextVariant(Config.GetVariant(item))
		if not EggHandler.GetAnimalTemplate(item.Name, variant) then
			return { Status = false, Reason = "This animal's fused variant is unavailable." }
		end

		-- Selected animals leave the plot/backpack but stay owned until completion.
		local equipped = self.DataService:GetValue(player, "EquippedAnimals")
		if equipped[reference] then
			local response = self.AnimalService:UnEquipAnimal(player, reference)
			if not response.Status then
				return response
			end
		end
		state.Slots[key] = reference
	else
		if not oldReference then
			return { Status = true }
		end
		if Config.ResetOnRemoval then
			state.Remaining = nil
		elseif state.FinishAt then
			state.Remaining = math.max(0, state.FinishAt - os.time())
		end
		state.FinishAt = nil
		state.Slots[key] = nil
		if next(state.Slots) == nil then
			state.Remaining = nil
		end
	end

	local result = Config.GetResult(state, inventory)
	if result then
		local duration = state.Remaining or Config.GetDuration(Config.GetVariant(inventory[state.Slots["1"]]))
		state.FinishAt = os.time() + duration
		state.Remaining = nil
	end
	self:save(player, state)
	if reference then
		self.InventoryService:RemoveTool(player, reference)
	elseif inventory[oldReference] then
		self.InventoryService:StoreInBackpack(player, oldReference, "Animal")
	end
	return { Status = true }
end

-- Public Methods
function FuseService:SetSlot(player: Player, slot: number, reference: string?)
	local now = os.clock()
	if self.Pending[player] or now - (self.LastRequest[player] or -math.huge) < Config.RequestCooldown then
		return { Status = false, Reason = "Please wait a moment before changing another slot." }
	end
	self.Pending[player] = true
	self.LastRequest[player] = now
	local success, response = xpcall(function()
		return self:setSlot(player, slot, reference)
	end, debug.traceback)
	self.Pending[player] = nil
	if not success then
		warn(`[FuseService] {response}`)
		return { Status = false, Reason = "Couldn't update the fuse machine. Please try again." }
	end
	return response
end

-- LifeCycle
function FuseService:KnitInit()
	self.DataService = knit.GetService("DataService")
	self.ProfileStoreService = knit.GetService("ProfileStoreService")
	self.AnimalService = knit.GetService("AnimalService")
	self.InventoryService = knit.GetService("InventoryService")
	self.EggHatchService = knit.GetService("EggHatchService")
	self.IndexService = knit.GetService("IndexService")
end

function FuseService:KnitStart()
	local elapsed = 0
	RunService.Heartbeat:Connect(function(deltaTime)
		elapsed += deltaTime
		if elapsed < Config.UpdateInterval then
			return
		end
		elapsed = 0
		for _, player in ipairs(Players:GetPlayers()) do
			if Config.Enabled and not self.Pending[player] and self:isReady(player) then
				self.Pending[player] = true
				local success, reason = xpcall(function()
					self:complete(player, self.DataService:GetValue(player, "Fuse"))
				end, debug.traceback)
				self.Pending[player] = nil
				if not success then
					warn(`[FuseService] {reason}`)
				end
			end
		end
	end)

	Players.PlayerRemoving:Connect(function(player)
		self.Pending[player] = nil
		self.LastRequest[player] = nil
	end)
end

return FuseService
