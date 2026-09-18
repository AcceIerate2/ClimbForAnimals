-- Roblox Services
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Packages
local RagdollPackage = require(ReplicatedStorage.src.Packages.ragdoll)

-- Helper Functions
local function releaseAnimationJoints(character: Model)
	local joints = {}
	local root = character:FindFirstChild("HumanoidRootPart")

	-- The package handles Motor6Ds; upgraded avatars use AnimationConstraints instead.
	for _, joint in ipairs(character:GetDescendants()) do
		if not joint:IsA("AnimationConstraint") or not joint.Enabled then
			continue
		end

		local first, second = joint.Attachment0, joint.Attachment1
		if not first or not second or first.Parent == root or second.Parent == root then
			continue
		end

		local socket = Instance.new("BallSocketConstraint")
		socket.Name = "GuardRagdollJoint"
		socket.Attachment0 = first
		socket.Attachment1 = second
		socket.LimitsEnabled = true
		socket.UpperAngle = 45
		socket.TwistLimitsEnabled = true
		socket.TwistLowerAngle = -30
		socket.TwistUpperAngle = 30
		socket.Parent = joint.Parent
		joint.Enabled = false
		joints[joint] = socket
	end

	return function()
		for joint, socket in pairs(joints) do
			if joint.Parent then
				joint.Enabled = true
			end

			socket:Destroy()
		end
	end
end

local Ragdoll = {}

-- Public Methods
function Ragdoll.Start(character: Model, humanoid: Humanoid)
	local requiresNeck = humanoid.RequiresNeck
	local autoRotate = humanoid.AutoRotate
	local platformStand = humanoid.PlatformStand

	-- The package disables the neck motor along with the other joints.
	humanoid.RequiresNeck = false
	humanoid.AutoRotate = false
	humanoid.PlatformStand = true
	character:SetAttribute("GuardStunned", true)

	RagdollPackage.Enable(character, {
		collisionGroupName = "RagdollCollisions",
		serverOwnsPhysics = true,
		disableSelfCollision = true,
		enableLimbCollisions = true,
		disableRootCollision = true,
	})
	local restoreAnimationJoints = releaseAnimationJoints(character)

	local cleaned = false

	return function()
		if cleaned then
			return
		end

		cleaned = true
		restoreAnimationJoints()
		RagdollPackage.Destroy(character)

		if humanoid.Parent then
			humanoid.RequiresNeck = requiresNeck
			humanoid.AutoRotate = autoRotate
			humanoid.PlatformStand = platformStand
		end

		character:SetAttribute("GuardStunned", nil)
	end
end

return Ragdoll
