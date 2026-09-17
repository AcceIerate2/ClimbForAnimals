-- Roblox Services
local PhysicsService = game:GetService("PhysicsService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Utility Modules
local CollisionHandler = require(ReplicatedStorage.src.utility.CollisionHandler)

-->
PhysicsService:RegisterCollisionGroup("PlayerCollisions")
PhysicsService:RegisterCollisionGroup("RagdollCollisions")

PhysicsService:CollisionGroupSetCollidable("PlayerCollisions", "PlayerCollisions", false)
PhysicsService:CollisionGroupSetCollidable("PlayerCollisions", "RagdollCollisions", false)

PhysicsService:CollisionGroupSetCollidable("RagdollCollisions", "RagdollCollisions", true)
PhysicsService:CollisionGroupSetCollidable("RagdollCollisions", "PlayerCollisions", false)

-- Climbing: behaves like PlayerCollisions, but collides with the invisible walls
PhysicsService:RegisterCollisionGroup("ClimbingCollisions")
PhysicsService:RegisterCollisionGroup("InvisibleWalls")

PhysicsService:CollisionGroupSetCollidable("ClimbingCollisions", "PlayerCollisions", false)
PhysicsService:CollisionGroupSetCollidable("ClimbingCollisions", "ClimbingCollisions", false)
PhysicsService:CollisionGroupSetCollidable("ClimbingCollisions", "RagdollCollisions", false)

PhysicsService:CollisionGroupSetCollidable("InvisibleWalls", "PlayerCollisions", false)
PhysicsService:CollisionGroupSetCollidable("InvisibleWalls", "RagdollCollisions", false)
PhysicsService:CollisionGroupSetCollidable("InvisibleWalls", "ClimbingCollisions", true)

-- Debris (egg shells and other short-lived effect parts): collides with the map only
PhysicsService:RegisterCollisionGroup("Debris")

PhysicsService:CollisionGroupSetCollidable("Debris", "PlayerCollisions", false)
PhysicsService:CollisionGroupSetCollidable("Debris", "RagdollCollisions", false)
PhysicsService:CollisionGroupSetCollidable("Debris", "ClimbingCollisions", false)
PhysicsService:CollisionGroupSetCollidable("Debris", "InvisibleWalls", false)
PhysicsService:CollisionGroupSetCollidable("Debris", "Debris", false)

-- Animals (client-rendered plot animals) are queryable but invisible to every normal query:
-- only a ray in the Hover group can hit them, which is how the weight hover picks the mesh
-- under the cursor without the ground checks and hitbox overlaps ever seeing them.
PhysicsService:RegisterCollisionGroup("Animals")
PhysicsService:RegisterCollisionGroup("Hover")

for _, group: string in ipairs({
	"Default",
	"PlayerCollisions",
	"RagdollCollisions",
	"ClimbingCollisions",
	"InvisibleWalls",
	"Debris",
	"Animals",
}) do
	PhysicsService:CollisionGroupSetCollidable("Animals", group, false)
end
PhysicsService:CollisionGroupSetCollidable("Animals", "Hover", true)

-- The Hover ray only sees the map (so walls occlude the cursor) and the animals themselves.
for _, group: string in ipairs({
	"PlayerCollisions",
	"RagdollCollisions",
	"ClimbingCollisions",
	"InvisibleWalls",
	"Debris",
	"Hover",
}) do
	PhysicsService:CollisionGroupSetCollidable("Hover", group, false)
end
PhysicsService:CollisionGroupSetCollidable("Hover", "Default", true)

CollisionHandler.SetInstanceOrGroup(workspace:WaitForChild("InvisibleWalls"), "InvisibleWalls")
