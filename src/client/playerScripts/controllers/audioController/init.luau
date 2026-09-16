-- Roblox Services
local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")

-- Packages
local knit = require(ReplicatedStorage.src.Packages.knit)

-->
local AudioController = knit.CreateController({
	Name = "AudioController",
})

-- Public Methods
function AudioController:PlaySfx(
	name: string,
	playbackConfig: { Parent: Instance, PlayOver: boolean, PlaybackSpeed: number }?
)
	assert(typeof(name) == "string", "name arg must be a string")
	assert(typeof(playbackConfig) == "table", "playbackConfig arg must be a table")
	local sound = SoundService:FindFirstChild(name, true) :: Sound
	if playbackConfig and playbackConfig.PlayOver then
		sound = sound:Clone()
		sound.Name = `{sound.Name}_{HttpService:GenerateGUID(false)}`
		sound.PlaybackSpeed = playbackConfig.PlaybackSpeed or sound.PlaybackSpeed
		sound.Parent = playbackConfig.Parent or SoundService
		sound.Ended:Once(function()
			sound:Destroy()
		end)
	end
	sound:Play()
end

return AudioController
