return {
	PatrolWalkDuration = 5,
	PatrolIdleDuration = 3,
	ChaseSpeed = 18,
	ChaseRepathInterval = 0.2,
	TurnSpeed = 12, -- Higher values turn toward the target faster.
	UpdateInterval = 0.05,
	ZoneHeight = 18, -- Area is a ground part; detect characters above its surface.
	AlertHeightOffset = 0.75,
	CaptureCooldown = 3,
	RequestCooldown = 0.25,
	CapturePositionTolerance = 8,
	HitTolerance = 3,
	FallbackHitboxSize = Vector3.new(4, 5, 4),
	RagdollDuration = 1,
	PunchDirection = Vector3.new(1, 0, 0), -- World-space horizontal direction; lift is applied separately.
	PunchDistance = 50, -- Approximate travel in studs on level ground.
	PunchFlightTime = 1, -- Seconds in the air; controls the height of the arc.
}
