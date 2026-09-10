-- Roblox Services
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

-- Packages
local knit = require(ReplicatedStorage.src.Packages.knit)

-- Utility Modules
local InstanceCreator = require(ReplicatedStorage.src.utility.InstanceCreator)

-- Constants
local Player = Players.LocalPlayer

-->
local GateController = knit.CreateController({ Name = "GateController" })

-- Private Methods
function GateController:openGate() end

function GateController:closeGate() end

-- LifeCycle
function GateController:KnitInit()
	self.BaseController = knit.GetController("BaseController")
end

function GateController:KnitStart()
	self.Base = self.BaseController:GetBase()
	local Gate = self.Base:WaitForChild("Gate")

	local Left = Gate:WaitForChild("Left")
	local Right = Gate:WaitForChild("Right")

	local LeftGate = Left:WaitForChild("Gate")
	local RightGate = Right:WaitForChild("Gate")

	local LeftHinge = Left:WaitForChild("Anchor"):WaitForChild("HingeConstraint") :: HingeConstraint
	local RightHinge = Right:WaitForChild("Anchor"):WaitForChild("HingeConstraint") :: HingeConstraint

	LeftHinge.AngularSpeed = 6
	RightHinge.AngularSpeed = 6

	LeftHinge.ServoMaxTorque = math.huge
	RightHinge.ServoMaxTorque = math.huge

	LeftGate.CanCollide = false
	RightGate.CanCollide = false

	for _, basePart: BasePart in pairs(Left:WaitForChild("Deco"):GetChildren()) do
		basePart.CanCollide = false
		basePart.Anchored = false
		basePart.Massless = true
		InstanceCreator("WeldConstraint", "WeldConstraint", LeftGate, {
			Part0 = basePart,
			Part1 = LeftGate,
		})
	end

	for _, basePart: BasePart in pairs(Right:WaitForChild("Deco"):GetChildren()) do
		basePart.CanCollide = false
		basePart.Anchored = false
		basePart.Massless = true
		InstanceCreator("WeldConstraint", "WeldConstraint", RightGate, {
			Part0 = basePart,
			Part1 = RightGate,
		})
	end

	local function getSide()
		local Character = Player.Character
		local HumanoidRootPart = Character and Character:FindFirstChild("HumanoidRootPart")
		if not HumanoidRootPart then
			return
		end

		local gateCFrame = Gate:GetPivot()

		local direction = HumanoidRootPart.Position - gateCFrame.Position
		return gateCFrame:VectorToObjectSpace(direction).Z > 0
	end

	local closed = true
	RunService.RenderStepped:Connect(function(deltaTime: number)
		local character = Player.Character
		if not character then
			return
		end

		local gatePosition = Gate:GetPivot().Position
		local playerPosition = Player.Character:GetPivot()

		local offset = playerPosition - gatePosition
		local distance = Vector3.new(offset.X, 0, offset.Z).Magnitude

		local shouldOpen = distance < 5

		if shouldOpen and closed then
			local side = getSide()
			LeftHinge.TargetAngle = side and -90 or 90
			RightHinge.TargetAngle = side and 90 or -90
			closed = false
		elseif not shouldOpen and not closed then
			LeftHinge.TargetAngle = 0
			RightHinge.TargetAngle = 0
			closed = true
		end
	end)
end

return GateController
