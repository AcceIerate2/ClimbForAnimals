-- Keep published names and ordering stable so historical charts remain comparable.
return {
	Enabled = true,
	DebugInStudio = false, -- Print events locally; Studio cannot send analytics.
	OverallFunnel = "Tutorial",
	StepFunnel = "TutorialSteps", -- Filter CustomField01 to inspect an individual step.
	Version = "1",
	Steps = {
		{ Key = "Climb", Name = "Start climbing" },
		{ Key = "Ascend", Name = "Climb to the first area" },
		{ Key = "Platform", Name = "Reach a platform" },
		{ Key = "Steal", Name = "Steal an egg" },
		{ Key = "Return", Name = "Return to base" },
		{ Key = "Deposit", Name = "Place the egg" },
		{ Key = "Hatch", Name = "Hatch the egg" },
		{ Key = "HatchReward", Name = "Reveal the animal" },
		{ Key = "Stamina", Name = "Upgrade stamina" },
		{ Key = "CloseStamina", Name = "Close stamina menu" },
		{ Key = "Treadmill", Name = "Get a treadmill" },
		{ Key = "Train", Name = "Train on the treadmill" },
	},
}
