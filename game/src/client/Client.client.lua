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
local CharacterPose = require(script.Parent:WaitForChild("CharacterPose"))
local PaintVisual = require(script.Parent:WaitForChild("PaintVisual"))
local ItemClient = require(script.Parent:WaitForChild("ItemClient"))
local StarterGui = game:GetService("StarterGui")
local TextChatService = game:GetService("TextChatService")

-- 채팅창은 왼쪽 아래, 기본 가방(1~0 단축키)은 끔 → 숫자키는 무기 교체용
task.spawn(function()
	local cfg = TextChatService:FindFirstChildOfClass("ChatWindowConfiguration") or TextChatService:WaitForChild("ChatWindowConfiguration", 10)
	if cfg then
		cfg.HorizontalAlignment = Enum.HorizontalAlignment.Left
		cfg.VerticalAlignment = Enum.VerticalAlignment.Bottom
	end
	for _ = 1, 10 do
		if pcall(function()
			StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Backpack, false)
			StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Health, false)
		end) then
			break
		end
		task.wait(1)
	end
end)

-- 관리자가 바꾼 운영 설정(부활 시간·아이템 유지 시간 등)을 이 클라이언트의 Config에도 반영
do
	local HttpService = game:GetService("HttpService")
	local Cfg = require(ReplicatedStorage.Shared.Config)
	local function sync()
		local raw = ReplicatedStorage:GetAttribute("SF_Settings")
		if raw then
			local ok, t = pcall(function()
				return HttpService:JSONDecode(raw)
			end)
			if ok then
				Cfg.ApplySettings(t)
			end
		end
	end
	sync()
	ReplicatedStorage:GetAttributeChangedSignal("SF_Settings"):Connect(sync)
end
HUD.Build()
-- 전체 UI 글꼴을 SF 이탤릭으로 (이후 만들어지는 창·킬피드·결과 화면 포함)
require(script.Parent:WaitForChild("UIKit")).AutoStyle(player:WaitForChild("PlayerGui"))
LobbyUI.Init(remotes, HUD)
WeaponController.Init(remotes, HUD, Effects)
CBTPanel.Init(remotes, HUD)
MapInteract.Init(Effects)
-- 창(상점·랭킹·크레이트·피드백·관리자)이 하나라도 열려 있으면 마우스 커서를 풀어 줌
local openWindows = {}
local function modal(source, on)
	openWindows[source] = on and true or nil
	WeaponController.SetUIMode(next(openWindows) ~= nil)
end
CBTPanel.SetModalHandler(function(on)
	modal("cbt", on)
end)
LobbyUI.SetModalHandler(function(on)
	modal("lobby", on)
end)
HUD.SetLeaveHandler(function(on)
	modal("leave", on)
end, function()
	remotes.Queue:FireServer("leaveMatch")
end)
CharacterPose.Init()
PaintVisual.Init()
ItemClient.Init(remotes, HUD)
HUD.UpdateQuests()
LobbyUI.UpdateQuests()

-- 저장 데이터 경고 (불러오기 실패 시)
local function dataWarn()
	local w = player:GetAttribute("DataWarning")
	if w then
		HUD.Banner(w, Color3.fromRGB(255, 140, 120))
	end
end
player:GetAttributeChangedSignal("DataWarning"):Connect(dataWarn)
task.delay(3, dataWarn)

-- 레벨 업 축하
player:GetAttributeChangedSignal("LevelUp"):Connect(function()
	local v = player:GetAttribute("LevelUp") or ""
	local lv, coins = string.match(v, "^(%d+):(%d+)")
	if lv then
		HUD.Banner(string.format("레벨 %s 달성!  +%s 코인", lv, coins), Color3.fromRGB(255, 210, 80))
		SoundBank.Play("crate_epic", nil, 0.6)
	end
end)
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
	-- 이번 판에 참가한 사람만 결과창을 봄 (중간에 나간 사람·로비 사람은 제외)
	local joined = false
	for _, row in ipairs(r.Rows) do
		if row.Player == player then
			joined = true
		end
	end
	if not joined then
		return
	end
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
	elseif kind == "Elim" then
		HUD.Elim(data)
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
	HUD.ScreenSplat(color, amount)
	Effects.Shake(math.clamp(amount / 80, 0.05, 0.35))
	SoundBank.Play("hurt", nil, 0.5)
end)

remotes.CrateResult.OnClientEvent:Connect(function(res)
	LobbyUI.ShowCrate(res)
end)

print("[SplashFront] 클라이언트 준비 — B: 상점, F4: 피드백, F2: 관리자, 경기 중 좌클릭 발사 / 우클릭 조준 / Q 스페셜 / C 앉기 / V 1·3인칭 / 스폰에서 1~6·T 무기 교체")
