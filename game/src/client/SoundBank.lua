-- 상황별 효과음 재생
-- 업로드 후: 효과음 37개가 든 아틀라스 1개(AssetIds.SfxAtlas)에서 PlaybackRegion으로 해당 구간만 재생
-- 업로드 전: Studio 기본음으로 대체
local SoundService = game:GetService("SoundService")
local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local AssetIds = require(ReplicatedStorage.Shared.AssetIds)

local SoundBank = {}

local PING = "rbxasset://sounds/electronicpingshort.wav"
local WATER = "rbxasset://sounds/impact_water.mp3"
local SWOOSH = "rbxasset://sounds/swoosh.wav"
local FALLBACK = {
	fire_pistol = { PING, 1.1 }, fire_rifle = { PING, 1.0 }, fire_smg = { PING, 1.3 }, fire_shotgun = { PING, 0.7 },
	fire_sniper = { PING, 0.55 }, fire_launcher = { PING, 0.5 }, low_ink = { PING, 2.0 },
	hit = { WATER, 1.1 }, hit_head = { WATER, 1.4 }, kill = { SWOOSH, 1.0 }, hurt = { WATER, 0.8 }, splashed = { SWOOSH, 0.8 },
	paint_land = { WATER, 1.2 }, jump_pad = { SWOOSH, 1.5 }, zipline_start = { PING, 0.8 }, respawn = { SWOOSH, 1.2 },
	special_throw = { SWOOSH, 1.0 }, special_boom = { WATER, 0.6 },
}

local function container(position)
	if not position then
		return SoundService, nil
	end
	local folder = workspace:FindFirstChild("ClientFX")
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = "ClientFX"
		folder.Parent = workspace
	end
	local p = Instance.new("Part")
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.Transparency = 1
	p.Size = Vector3.new(0.1, 0.1, 0.1)
	p.Position = position
	p.Parent = folder
	return p, p
end

-- name: atlas 이름(fire_rifle, hit_head …), position: 3D 위치(없으면 2D), volume 0~1, pitch 배속
-- 아틀라스에 아직 없는 소리는 비슷한 소리로 대신 (새 효과음 업로드 전·새 총 추가 직후에도 무음이 되지 않게)
local ALIAS = { fire_k2 = "fire_rifle", fire_k2c1 = "fire_rifle", fire_k3 = "fire_smg", fire_k14 = "fire_sniper", fire_k5 = "fire_pistol",
	hit_real = "hit", hit_real_head = "hit_head",
	knife_swing = "special_throw", knife_hit = "hit_real", knife_draw = "zipline_start", slide = "jump_pad" }

function SoundBank.Play(name, position, volume, pitch, looped)
	if not AssetIds.SfxRegions[name] then
		name = ALIAS[name] or (string.sub(name, 1, 5) == "fire_" and "fire_rifle") or name
	end
	local region = AssetIds.SfxRegions[name]
	local s = Instance.new("Sound")
	s.Volume = volume or 0.6
	s.PlaybackSpeed = pitch or 1
	local length = 2
	if AssetIds.SfxAtlas ~= 0 and region then
		s.SoundId = "rbxassetid://" .. AssetIds.SfxAtlas
		s.PlaybackRegionsEnabled = true
		s.PlaybackRegion = NumberRange.new(region[1], region[2])
		if looped then
			s.LoopRegion = NumberRange.new(region[1], region[2])
		end
		length = region[2] - region[1]
	else
		local fb = FALLBACK[name]
		if not fb then
			return nil
		end
		s.SoundId = fb[1]
		s.PlaybackSpeed = (pitch or 1) * fb[2]
	end
	s.Looped = looped == true
	s.RollOffMaxDistance = 160
	local parent, part = container(position)
	s.Parent = parent
	s:Play()
	if not looped then
		Debris:AddItem(part or s, length / s.PlaybackSpeed + 0.3)
	end
	return s
end

return SoundBank
