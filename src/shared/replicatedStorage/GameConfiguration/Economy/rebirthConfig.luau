-- Editable rebirth rules. Defaults follow our supplied UI, not a verified reference-game formula.
local Config = {}

-- General Settings
Config.Enabled = true
Config.MaxRebirths = 0 -- 0 = unlimited (until numeric safety limits are reached).
Config.RequestCooldown = 1

-- Rebirth Requirements
Config.Requirements = {
	-- 20K at 2.6x: the requirement grows about as fast as the treadmill accelerates (~2.15x per
	-- level), so while there is a level left to buy each rebirth costs 15-30 minutes of running;
	-- once the treadmill caps at level 10 only the requirement keeps growing, and the late ones
	-- turn into hours and days on their own.
	Speed = { Base = 10000, Growth = 7, Add = 0 },
	-- Cash = { Base = 250000, Growth = 2, Add = 0 },
} -- Requirement for next rebirth = Base * Growth ^ completedRebirths + Add * completedRebirths.

-- Cash Multiplier
Config.Multiplier = {
	Base = 1,
	Mode = "a",
	PerRebirth = 0.25, -- 1 -> 1.25 -> 1.5 -> 1.75 -> 2 ...
	Factor = 1.3, -- only used when Mode is "Multiplicative"
}

-- Per-Rebirth Overrides
Config.Overrides = {
	-- [2] = { Requirements = { Speed = 30000 }, CashMultiplier = 2 },
} -- Keys are the rebirth being PURCHASED (1, 2, ...). Requirements replaces the formula table.

-- Affected Cash Sources
Config.CashSources = {
	AnimalIncome = true,
	OfflineIncome = true,
	IndexRewards = false,
	OtherRewards = false,
}

-- Reset Settings
Config.Reset = {
	Speed = 250, -- false preserves a value. This is the current game's starting Speed.
	Cash = false,
	TreadmillLevel = false,
	StaminaConsumptionRate = false,
	StaminaLevel = false, -- Set to 1 to reset stamina upgrades on rebirth.
	BaseLevel = false,
	PendingOfflineCash = false,
}

Config.RemoveAnimals = false -- Deletes owned animals; Index discoveries remain.
Config.RemoveEggs = false -- Deletes owned/placed eggs; paid egg credits remain.
Config.UnequipAnimals = false -- Retains ownership, returns active animals to the backpack.

-- Paid Skip Settings
Config.Skip = { Enabled = true, ApplyResets = true } -- Always bypasses requirements; grants ONE rebirth.
-- Developer product ID lives ONLY in monetizationService/productIds.luau.

-- Public Methods
function Config.GetRequirements(completed: number)
	local override = Config.Overrides[completed + 1]

	if override and override.Requirements then
		return table.clone(override.Requirements)
	end

	local requirements = {}

	for key, rule in pairs(Config.Requirements) do
		requirements[key] = math.ceil(rule.Base * rule.Growth ^ completed + (rule.Add or 0) * completed)
	end

	return requirements
end

function Config.GetMultiplier(completed: number): number
	local override = Config.Overrides[completed]

	if override and override.CashMultiplier then
		return override.CashMultiplier
	end

	local rule = Config.Multiplier

	if rule.Mode == "Multiplicative" then
		return rule.Base * rule.Factor ^ completed
	end

	return rule.Base + rule.PerRebirth * completed
end

function Config.ForSource(multiplier: number?, source: string): number
	if not Config.CashSources[source] then
		return 1
	end

	return if typeof(multiplier) == "number" and multiplier > 0 and multiplier < math.huge then multiplier else 1
end

return Config
