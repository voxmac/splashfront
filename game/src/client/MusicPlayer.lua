-- 맵별 배경음악: 로비 → lobby, 크로마 스퀘어 → chroma, 스카이 루프탑 → sky, 결과 → victory/defeat 징글
-- 파이널 스플래쉬(마지막 30초)에는 템포를 올림. 음원 ID는 AssetIds.Music (업로드 전이면 무음)
local Players = game:GetService("Players")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage.Shared.Config)
local AssetIds = require(ReplicatedStorage.Shared.AssetIds)

local player = Players.LocalPlayer
local MusicPlayer = {}

local MAP_TRACK = { ChromaSquare = "chroma", SkyRooftop = "sky" }
local loop, jingle
local current = nil
local jinglePlaying = false

local function idOf(track)
	local id = AssetIds.Music[track]
	if id and id ~= 0 then
		return "rbxassetid://" .. id
	end
	return nil
end

-- 서버 이동 전환 화면(SF_Transition) 중에는 배경음악·징글을 끄고, 끝나면 서서히 다시 켬
local function muted()
	return SoundService:GetAttribute("SF_Transition") == true
end
local function targetVolume()
	return muted() and 0 or Config.Music.Volume
end

local function setTrack(track)
	if track == current then
		return
	end
	current = track
	local id = track and idOf(track)
	if not id then
		loop:Stop()
		return
	end
	-- 짧게 줄였다가 새 곡으로
	TweenService:Create(loop, TweenInfo.new(0.4), { Volume = 0 }):Play()
	task.delay(0.4, function()
		if current ~= track then
			return
		end
		loop.SoundId = id
		loop.TimePosition = 0
		loop:Play()
		TweenService:Create(loop, TweenInfo.new(0.6), { Volume = targetVolume() }):Play()
	end)
end

function MusicPlayer.Init()
	loop = Instance.new("Sound")
	loop.Name = "SplashMusic"
	loop.Looped = true
	loop.Volume = Config.Music.Volume
	loop.Parent = SoundService
	jingle = Instance.new("Sound")
	jingle.Name = "SplashJingle"
	jingle.Volume = Config.Music.Volume + 0.2
	jingle.Parent = SoundService
	jingle.Ended:Connect(function()
		jinglePlaying = false
	end)
	SoundService:GetAttributeChangedSignal("SF_Transition"):Connect(function()
		if muted() then
			TweenService:Create(loop, TweenInfo.new(0.5), { Volume = 0 }):Play()
			TweenService:Create(jingle, TweenInfo.new(0.5), { Volume = 0 }):Play()
		else
			TweenService:Create(loop, TweenInfo.new(1.5), { Volume = Config.Music.Volume }):Play()
			jingle.Volume = Config.Music.Volume + 0.2
		end
	end)
	if muted() then
		loop.Volume = 0
	end
end

function MusicPlayer.OnState(s)
	if jinglePlaying then
		return
	end
	local inMatch = player:GetAttribute("InMatch") == true
	if inMatch and (s.Phase == "Playing" or s.Phase == "Results") then
		setTrack(MAP_TRACK[s.MapId] or "chroma")
	else
		setTrack("lobby")
	end
	loop.PlaybackSpeed = (inMatch and s.FinalSplash and s.Phase == "Playing") and Config.Music.FinalSplashSpeed or 1
end

-- 결과 화면: 승리/패배 징글 (음악은 잠깐 멈춤)
function MusicPlayer.PlayResult(won)
	local id = idOf(won and "victory" or "defeat")
	if not id then
		return
	end
	loop:Stop()
	current = nil
	jinglePlaying = true
	jingle.SoundId = id
	jingle.Volume = muted() and 0 or (Config.Music.Volume + 0.2)
	jingle:Play()
	task.delay(20, function()
		jinglePlaying = false
	end)
end

return MusicPlayer
