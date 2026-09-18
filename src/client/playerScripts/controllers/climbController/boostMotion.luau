local BoostMotion = {}

function BoostMotion.Create(height: number, normalSpeed: number, multiplier: number, slowdownDuration: number)
	local peakSpeed = math.max(normalSpeed * multiplier, normalSpeed, 0.001)
	local slowdown = math.min(math.max(slowdownDuration, 0.001), 2 * height / (peakSpeed + normalSpeed))
	local cruise = math.max(0, (height - (peakSpeed + normalSpeed) * slowdown / 2) / peakSpeed)

	return {
		Height = height,
		NormalSpeed = normalSpeed,
		PeakSpeed = peakSpeed,
		Slowdown = slowdown,
		Cruise = cruise,
		Duration = cruise + slowdown,
	}
end

function BoostMotion.Progress(plan, elapsed: number): number
	return math.clamp((elapsed - plan.Cruise) / plan.Slowdown, 0, 1)
end

function BoostMotion.Distance(plan, elapsed: number): number
	local progress = BoostMotion.Progress(plan, elapsed)
	-- Integral of 1 - smoothstep(progress), so even a short boost has a fixed distance budget.
	local integral = progress - progress ^ 3 + progress ^ 4 / 2
	return plan.PeakSpeed * math.clamp(elapsed, 0, plan.Cruise)
		+ plan.Slowdown * (plan.NormalSpeed * progress + (plan.PeakSpeed - plan.NormalSpeed) * integral)
end

return BoostMotion
