-- Types
type MovementState = {
	From: CFrame,
	To: CFrame,
	StartedAt: number,
	Duration: number,
}

-->
local Movement = {}

function Movement.GetPose(state: MovementState, now: number): (CFrame, boolean)
	local elapsed = now - state.StartedAt
	local alpha = state.Duration > 0 and math.clamp(elapsed / state.Duration, 0, 1) or 1
	local moving = state.Duration > 0 and alpha < 1

	local position = state.From.Position:Lerp(state.To.Position, alpha)
	local turn = state.Duration > 0 and math.clamp(elapsed / 0.25, 0, 1) or 1
	local rotation = state.From.Rotation:Lerp(state.To.Rotation, turn)

	return CFrame.new(position) * rotation, moving
end

return Movement
