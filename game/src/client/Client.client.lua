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
	-- 실총은 둔탁한 실탄 타격음 + 옅은 페인트 튐, 페인트총은 페인트 타격음
	local myW = require(ReplicatedStorage.Shared.Weapons).Get(player:GetAttribute("Weapon"))
	if myW and myW.StoreModel then
		SoundBank.Play(d.Head and "hit_real_head" or "hit_real", nil, d.Head and 0.9 or 0.8)
		SoundBank.Play("hit", nil, 0.25)
	else
		SoundBank.Play(d.Head and "hit_head" or "hit", nil, d.Head and 0.8 or 0.6)
	end
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

-- 카메라 감시: 로비 입장·재스폰 직후 카메라가 캐릭터를 놓치는 경우(고정 카메라로 남거나 사라진 캐릭터를 따라가는 경우)를 바로잡음
do
	local function fixCamera()
		local cam = workspace.CurrentCamera
		local c = player.Character
		local hum = c and c:FindFirstChildOfClass("Humanoid")
		if not cam or not hum or cam:GetAttribute("SF_Intro") then
			return
		end
		if cam.CameraType == Enum.CameraType.Scriptable or cam.CameraType == Enum.CameraType.Fixed then
			cam.CameraType = Enum.CameraType.Custom
		end
		local subj = cam.CameraSubject
		if subj ~= hum and (subj == nil or not subj:IsDescendantOf(workspace) or (subj:IsA("Humanoid") and subj.Parent ~= c)) then
			cam.CameraSubject = hum
		end
	end
	player.CharacterAdded:Connect(function(c)
		c:WaitForChild("Humanoid", 10)
		task.wait(0.2)
		fixCamera()
	end)
	task.spawn(function()
		while true do
			task.wait(1)
			pcall(fixCamera)
		end
	end)
	workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(function()
		task.defer(fixCamera)
	end)
end

-- 채팅 입력 중 ESC: 입력창 닫기 (Roblox 메뉴 대신 채팅만 닫힘)
game:GetService("UserInputService").InputBegan:Connect(function(input)
	if input.KeyCode == Enum.KeyCode.Escape then
		local tb = game:GetService("UserInputService"):GetFocusedTextBox()
		if tb then
			pcall(function()
				tb:ReleaseFocus(false)
			end)
		end
	end
end)

-- 연막 안에 들어간 캐릭터는 이름·체력바를 숨김 (내 화면 기준, 0.15초마다 확인)
do
	local SHOW = Enum.HumanoidDisplayDistanceType.Viewer
	local HIDE = Enum.HumanoidDisplayDistanceType.None
	local hiddenByUs = setmetatable({}, { __mode = "k" })
	local function puffs()
		local out = {}
		local fx = workspace:FindFirstChild("FX")
		if fx then
			for _, cloud in ipairs(fx:GetChildren()) do
				if cloud.Name == "SmokeCloud" then
					for _, p in ipairs(cloud:GetChildren()) do
						if p:IsA("BasePart") and p.Transparency < 0.5 then
							table.insert(out, p)
						end
					end
				end
			end
		end
		return out
	end
	local function inSmoke(pos, list)
		for _, p in ipairs(list) do
			if (pos - p.Position).Magnitude < p.Size.X * 0.48 then
				return true
			end
		end
		return false
	end
	local function check(model, list)
		local hum = model and model:FindFirstChildOfClass("Humanoid")
		local head = model and (model:FindFirstChild("Head") or model:FindFirstChild("HumanoidRootPart"))
		if not hum or not head then
			return
		end
		local hide = #list > 0 and inSmoke(head.Position, list)
		if hide and hum.DisplayDistanceType ~= HIDE then
			hiddenByUs[hum] = hum.DisplayDistanceType
			hum.DisplayDistanceType = HIDE
		elseif not hide and hiddenByUs[hum] then
			hum.DisplayDistanceType = hiddenByUs[hum] or SHOW
			hiddenByUs[hum] = nil
		end
	end
	task.spawn(function()
		while true do
			task.wait(0.15)
			local list = puffs()
			for _, pl in ipairs(Players:GetPlayers()) do
				if pl ~= player and pl.Character then
					check(pl.Character, list)
				end
			end
			local bots = workspace:FindFirstChild("Bots")
			if bots then
				for _, m in ipairs(bots:GetChildren()) do
					check(m, list)
				end
			end
		end
	end)
end

print("[SplashFront] 클라이언트 준비 · B: 상점, F4: 피드백, F2: 관리자, 경기 중 좌클릭 발사 / 우클릭 조준 / Q 스페셜 / C 앉기 / V 1·3인칭 / 스폰에서 1~6·T 무기 교체")
