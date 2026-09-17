-- Constants
local FloatHeight = 3
local FloatDuration = 1.4
local LandDuration = 0.8
local RevealScaleMultiplier = 1.5

-- Helper Functions
local function getLandingProgress(elapsed: number): number
	local progress = math.clamp((elapsed - FloatDuration) / LandDuration, 0, 1)

	return progress * progress * (3 - 2 * progress)
end

-->
local Reveal = {
	Duration = FloatDuration + LandDuration,
}

function Reveal.GetCFrame(groundCFrame: CFrame, elapsed: number, targetPosition: Vector3?): CFrame
	local eased = getLandingProgress(elapsed)
	local height = FloatHeight * (1 - eased)
	local cFrame = groundCFrame + Vector3.new(0, height, 0)

	if targetPosition then
		local direction = Vector3.new(targetPosition.X - cFrame.X, 0, targetPosition.Z - cFrame.Z)
		if direction.Magnitude > 0.001 then
			return CFrame.lookAt(cFrame.Position, cFrame.Position + direction)
		end
	end

	return cFrame
end

function Reveal.GetScale(defaultScale: number, elapsed: number): number
	local eased = getLandingProgress(elapsed)
	local multiplier = 1 + (RevealScaleMultiplier - 1) * (1 - eased)

	return defaultScale * multiplier
end

return Reveal
