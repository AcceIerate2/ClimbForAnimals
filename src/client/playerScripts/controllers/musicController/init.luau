-- Roblox Services
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local SoundService = game:GetService("SoundService")

-- Packages
local knit = require(ReplicatedStorage.src.Packages.knit)
local topbarplus = require(ReplicatedStorage.src.Packages.topbarplus)

-- Config
local musicConfig = require(ReplicatedStorage.src.GameConfiguration.General.musicConfig)

-->
local MusicController = knit.CreateController({
	Name = "MusicController",
	Config = musicConfig,
	VolumeMultiplier = 1,
	Danger = false,
	TrackIndex = 0,
	Fades = {},
})

-- Public Methods
function MusicController:AdjustVolume(multiplier: number)
	self.VolumeMultiplier = math.max(multiplier, 0)
	self:updateMix()
end

function MusicController:SetDanger(active: boolean)
	if self.Danger == active then
		return
	end

	self.Danger = active
	self:updateMix()
end

-- Private Methods
function MusicController:fade(sound: Sound, volume: number, onComplete: (() -> ())?)
	local previous = self.Fades[sound]
	if previous then
		previous.Connection:Disconnect()
		previous.Tween:Cancel()
		previous.Tween:Destroy()
	end

	local tween = TweenService:Create(sound, TweenInfo.new(self.Config.FadeDuration), { Volume = volume })
	local fade = { Tween = tween }
	self.Fades[sound] = fade

	fade.Connection = tween.Completed:Connect(function()
		self.Fades[sound] = nil
		fade.Connection:Disconnect()
		tween:Destroy()

		if onComplete then
			onComplete()
		end
	end)

	tween:Play()
end

function MusicController:updateMix()
	local track = self.CurrentTrack
	if track then
		if self.Danger then
			self:fade(track, 0, function()
				if track.Playing then
					track:Pause()
					self.TrackPaused = true
				end
			end)
		else
			if self.TrackPaused then
				track:Resume()
				self.TrackPaused = false
			elseif not track.Playing then
				track:Play()
			end

			self:fade(track, self.Config.DefaultVolume * self.VolumeMultiplier)
		end
	end

	local dangerTrack = self.DangerTrack
	if self.Danger then
		if not dangerTrack.Playing then
			dangerTrack:Play()
		end

		self:fade(dangerTrack, self.Config.DangerVolume * self.VolumeMultiplier)
	else
		self:fade(dangerTrack, 0, function()
			dangerTrack:Stop()
		end)
	end
end

function MusicController:playNextTrack()
	if self.TrackEndedConnection then
		self.TrackEndedConnection:Disconnect()
	end

	local previous = self.CurrentTrack
	local fade = previous and self.Fades[previous]
	if fade then
		fade.Connection:Disconnect()
		fade.Tween:Cancel()
		fade.Tween:Destroy()
		self.Fades[previous] = nil
	end

	if #self.Config.SoundTracks == 0 then
		return
	end

	self.TrackIndex = self.TrackIndex % #self.Config.SoundTracks + 1
	local track = self.Config.SoundTracks[self.TrackIndex]
	self.CurrentTrack = track
	self.TrackPaused = false
	track.Volume = 0
	track.Looped = false
	self.TrackEndedConnection = track.Ended:Connect(function()
		self:playNextTrack()
	end)

	self:updateMix()
end

function MusicController:destroyBackpackButton()
	if not MusicController.topBarBackpackBtn then
		return
	end
	MusicController.topBarBackpackBtn:destroy()
	MusicController.topBarBackpackBtn = nil
end

-- LifeCycle
function MusicController:KnitInit()
	self:destroyBackpackButton()

	self.DangerTrack = self.Config.DangerTrack:Clone()
	self.DangerTrack.Name = "GuardDangerMusic"
	self.DangerTrack.Volume = 0
	self.DangerTrack.Looped = true
	self.DangerTrack.Parent = SoundService

	self.topBarBackpackBtn = topbarplus
		.new()
		:setName("Music")
		:setImage("rbxassetid://121511542895380", "Deselected")
		:setImage("rbxassetid://117072134589179", "Selected")
		:setImageScale(0.5)
		:setCaption("Toggle Music")
		:bindToggleKey(Enum.KeyCode.M)
		:autoDeselect(false)
		:setOrder(0)

	self.topBarBackpackBtn:select()
	self.topBarBackpackBtn.toggled:Connect(function(isToggled)
		self:AdjustVolume(isToggled and 1 or 0)
	end)
end

function MusicController:KnitStart()
	self:playNextTrack()
end

return MusicController
