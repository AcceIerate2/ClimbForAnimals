-- Tutorial progression and presentation. Purchase prices remain in their economy configs.
local Config = {
	Enabled = true,
	SkipExistingPlayers = true, -- Existing saves without tutorial progress are marked complete.
	FreeFirstStaminaPurchase = true, -- Only during the Stamina step, once per profile.
	StaminaTargetLevel = 2,
	TreadmillTargetLevel = 1, -- The existing first treadmill is already free.
	TrainingSeconds = 3,
	HatchRewardSeconds = 0, -- No extra pause after the hatch reveal.
	PlatformConfirmSeconds = 0.75,
	RouteExitConfirmSeconds = 1.5,
	PlatformHeight = 16,
	FallingSpeed = 8,
	ClimbColumnRadius = 40,
	UpdateInterval = 0.25,
	ServerInterval = 0.5,
	ArrivalDistance = 12,
	ZoneDistance = 18,
	PlatformDistance = 18, -- Landing near either marker advances straight to egg guidance.
	PlatformBiome = "Forest", -- Egg folder to use before entering the island's Area bounds.
	ClimbHeight = 4,
	TextInterval = 0.035,
	WriteSoundInterval = 0.075,
	FinishSeconds = 5,
	HighlightPadding = 8,
	Beam = {
		Width = 2,
		TextureSpeed = 1, -- Scroll magnitude; guidance applies the sign for the reversed texture endpoints.
		TextureLength = 4,
		Transparency = 0,
	},
	Title = "TUTORIAL",
	PartsFolder = "TutorialParts",
	Parts = { Climb = "Climb", Zone = "Zone", Left = "PlatformLeft", Right = "PlatformRight" },
	Text = {
		-- 1. Start climbing
		Climb = "Follow the arrow to start climbing.",

		-- 2. Reach the first area
		Ascend = "Climb up to the first area.",

		-- 3. Enter a platform
		Platform = "Move onto the platform to find an egg.",

		-- 4. Steal an egg (NoEgg is the waiting message)
		Steal = "Steal an egg.",
		NoEgg = "Wait for more eggs to appear.",

		-- 5. Return to base
		Return = "Bring the egg back to your base.",

		-- 6. Place the egg
		Deposit = "Equip the egg from your backpack and place it on your plot.",

		-- 7. Grow and hatch the egg, followed by the silent reward pause
		Hatch = "Wait for your egg to finish growing.",
		HatchReady = "Hatch your egg to discover an animal!",

		-- 8. Upgrade stamina (StaminaFree replaces Stamina when the offer applies)
		Stamina = "Upgrade your stamina to climb higher.",
		StaminaFree = "Upgrade your stamina to climb higher.",

		-- 9. Close the stamina menu
		CloseStamina = "Close the stamina menu to continue.",

		-- 10. Get a treadmill
		Treadmill = "Buy a treadmill.",

		-- 11. Train
		Train = "Step onto your treadmill to gain speed.",

		-- 12. Complete the tutorial
		Finish = "Tutorial complete! Explore new areas and collect more animals.",
	},
}

function Config.IsFreeStamina(state, level: number, baseLevel: number): boolean
	return Config.Enabled
		and Config.FreeFirstStaminaPurchase
		and type(state) == "table"
		and state.Initialized == true
		and not state.Completed
		and state.Step == "Stamina"
		and not state.FreeStaminaUsed
		and level == baseLevel
end

return Config
