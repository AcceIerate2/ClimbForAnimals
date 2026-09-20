-- Roblox Services
local SoundService = game:GetService("SoundService")

--
local MusicFolder = SoundService:WaitForChild("src"):WaitForChild("Music"):WaitForChild("Background")

-->
local MusicConfig = {}

-- In Order
MusicConfig.SoundTracks = {
	[1] = MusicFolder:WaitForChild("Music1"),
	[2] = MusicFolder:WaitForChild("Music2"),
	[3] = MusicFolder:WaitForChild("Music3"),
}

MusicConfig.DefaultVolume = 0.35
MusicConfig.DangerVolume = 0.5
MusicConfig.FadeDuration = 0.6
MusicConfig.DangerTrack =
	SoundService:WaitForChild("src"):WaitForChild("Sfx"):WaitForChild("EggStolen"):WaitForChild("Running")

MusicConfig.NightVolume = 0.5
MusicConfig.NightTrack =
	SoundService:WaitForChild("src"):WaitForChild("Sfx"):WaitForChild("CycleTime"):WaitForChild("NightTime")

return MusicConfig
