-- SPLASH FRONT 클라이언트 진입점
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage.Shared.Config)

local player = Players.LocalPlayer
local remotes = ReplicatedStorage:WaitForChild("Remotes")

local HUD = require(script.Parent:WaitForChild("HUD"))
local Effects = require(script.Parent:WaitForChild("Effects"))
local WeaponController = require(script.Parent:WaitForChild("WeaponController"))
local LobbyUI = require(script.Parent:WaitForChild("LobbyUI"))
local CBTPanel = require(script.Parent:WaitForChild("CBTPanel"))
local MapInteract = require(script.Parent:WaitForChild("MapInteract"))
local SoundBank = require(script.Parent:WaitForChild("SoundBank"))
local MusicPlayer = require(script.Parent:WaitForChild("MusicPlayer"))

HUD.Build()
LobbyUI.Init(remotes, HUD)
WeaponController.Init(remotes, HUD, Effects)
CBTPanel.Init(remotes, HUD)
MapInteract.Init(Effects)
CBTPanel.SetModalHandler(WeaponController.SetUIMode)
MusicPlayer.Init()

-- 스페셜 충전 완료 / 부활
local lastSpecial = 0
player:GetAttributeChangedSignal("Special"):Connect(function()
	local v = player:GetAttribute("Special") or 0
	if v >= 1 and lastSpecial < 1 then
		SoundBank.Play("special_ready", nil, 0.6)
	end
	lastSpecial = v
end)
player.CharacterAdded:Connect(function()
	if player:GetAttribute("InMatch") then
		SoundBank.Play("respawn", nil, 0.5)
	end
end)

player:GetAttributeChangedSignal("InMatch"):Connect(function()
	if player:GetAttribute("InMatch") and player:GetAttribute("FirstMatch") then
		HUD.ShowTips()
	end
end)

remotes.State.OnClientEvent:Connect(function(s)
	HUD.OnState(s)
	LobbyUI.OnState(s)
	MusicPlayer.OnState(s)
end)

remotes.Results.OnClientEvent:Connect(function(r)
	HUD.ShowResults(r)
	CBTPanel.OnResults()
	for _, row in ipairs(r.Rows) do
		if row.Player == player then
			MusicPlayer.PlayResult(row.Won)
		end
	end
end)

remotes.Notify.OnClientEvent:Connect(function(msg, color)
	HUD.Banner(msg, color)
end)

remotes.FX.OnClientEvent:Connect(function(kind, data)
	Effects.OnFX(kind, data)
	if kind == "Kill" then
		HUD.KillFeed(data)
		if data.VictimPlayer == player then
			SoundBank.Play("splashed", nil, 0.8)
		end
	elseif kind == "Cue" then
		-- 서버가 알려주는 상황: 미션·깃발은 우리 팀이면 성공음, 아니면 실패음
		local mine = player:GetAttribute("OwnerId")
		local name = data.Name
		if name == "mission_result" then
			name = (data.Owner == mine) and "mission_success" or "mission_fail"
		elseif name == "flag" then
			name = (data.Owner == mine) and "flag_captured" or "flag_lost"
		end
		SoundBank.Play(name, data.Pos, data.Volume or 0.7)
	end
end)

remotes.HitConfirm.OnClientEvent:Connect(function(d)
	HUD.Hitmarker(d.Head, d.Kill)
	if d.Pos then
		Effects.DamageNumber(d.Pos + Vector3.new(0, 1, 0), d.Damage, d.Head, d.Kill)
	end
	SoundBank.Play(d.Head and "hit_head" or "hit", nil, d.Head and 0.8 or 0.6)
	if d.Kill then
		SoundBank.Play("kill", nil, 0.8)
	end
end)

remotes.Damaged.OnClientEvent:Connect(function(fromPos, amount, color)
	HUD.DamageFlash(color or Color3.fromRGB(255, 60, 60)) -- 기획서 4장: 화면 가장자리 적 색 비네트
	Effects.Shake(math.clamp(amount / 60, 0.1, 0.6))
	SoundBank.Play("hurt", nil, 0.5)
end)

remotes.CrateResult.OnClientEvent:Connect(function(res)
	LobbyUI.ShowCrate(res)
end)

print("[SplashFront] 클라이언트 준비 — B: 상점, F4: 피드백, F2: 관리자, 경기 중 좌클릭 발사 / 우클릭 조준 / Q 스페셜 / C 앉기 / V 1·3인칭")
