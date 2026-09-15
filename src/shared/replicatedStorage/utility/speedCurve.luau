-- Converts the Speed stat into a real Humanoid.WalkSpeed using a logarithmic curve,
-- so Speed can grow unbounded (thousands/millions) while WalkSpeed stays in a
-- physically sane range. Every x1.15 of accumulated Speed adds +2 WalkSpeed, capped at 300.

local BASE_WALK_SPEED = 18
local MAX_WALK_SPEED = 300
local BASE_SPEED = 10 -- starting Speed stat; values at or below this map to BASE_WALK_SPEED
local STEP_RATIO = 1.15
local WALK_SPEED_PER_STEP = 2

local SpeedCurve = {}

function SpeedCurve.ToWalkSpeed(speed: number?): number
	speed = typeof(speed) == "number" and speed or BASE_SPEED

	local effective = math.max(speed - BASE_SPEED, 0)
	if effective <= 0 then
		return BASE_WALK_SPEED
	end

	local steps = math.log(1 + effective * 0.15 / 100) / math.log(STEP_RATIO)
	local progression = math.min(10 + steps * WALK_SPEED_PER_STEP, MAX_WALK_SPEED)

	local t = math.clamp((progression - 10) / (MAX_WALK_SPEED - 10), 0, 1)
	return BASE_WALK_SPEED + t * (MAX_WALK_SPEED - BASE_WALK_SPEED)
end

return SpeedCurve
