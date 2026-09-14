-- Roblox Services
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Packages
local Signal = require(ReplicatedStorage.src.Packages.Signal)
local knit = require(ReplicatedStorage.src.Packages.knit)

-- Constants
local Player = Players.LocalPlayer

-->
local CharacterController = knit.CreateController({
	Name = "CharacterController",
	CharacterAdded = Signal.new(),
	CharacterRemoved = Signal.new(),
})

-- LifeCycle
function CharacterController:KnitStart()
	if Player.Character then
		self.CharacterAdded:Fire(Player.Character)
	end

	Player.CharacterAdded:Connect(function(character)
		self.CharacterAdded:Fire(character)
	end)

	Player.CharacterRemoving:Connect(function(character)
		self.CharacterRemoved:Fire(character)
	end)
end

return CharacterController
