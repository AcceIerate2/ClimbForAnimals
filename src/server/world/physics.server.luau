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

CollisionHandler.SetInstanceOrGroup(workspace:WaitForChild("InvisibleWalls"), "InvisibleWalls")
