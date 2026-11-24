-- SPLASH FRONT 서버 진입점
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Services = script.Parent
local MapBuilder = require(Services.MapBuilder)
local PaintService = require(Services.PaintService)
local CombatService = require(Services.CombatService)
local DataService = require(Services.DataService)
local ShopService = require(Services.ShopService)
local RankService = require(Services.RankService)
local MatchService = require(Services.MatchService)
local Telemetry = require(Services.TelemetryService)
local AdminService = require(Services.AdminService)
local Config = require(ReplicatedStorage.Shared.Config)
local ModelService = require(Services.ModelService)
local ItemService = require(Services.ItemService)
local ImageService = require(Services.ImageService)
local QuestService = require(Services.QuestService)

-- 원격 이벤트
local remotes = Instance.new("Folder")
remotes.Name = "Remotes"
for _, name in ipairs({ "Fire", "Special", "FX", "HitConfirm", "Damaged", "State", "Results", "Notify", "Queue", "CrateResult", "Telemetry", "SwitchWeapon", "UseItem" }) do
	local r = Instance.new("RemoteEvent")
	r.Name = name
	r.Parent = remotes
end
-- 조준 각도·자세 공유 (자주 보내므로 신뢰성 없는 이벤트)
do
	local pose = Instance.new("UnreliableRemoteEvent")
	pose.Name = "Pose"
	pose.Parent = remotes
	local STANCES = { Normal = true, Run = true, Walk = true, Crouch = true }
	pose.OnServerEvent:Connect(function(pl, pitch, stance)
		if type(pitch) == "number" and pitch == pitch then
			local p = math.clamp(math.floor(pitch + 0.5), -70, 70)
			if math.abs((pl:GetAttribute("AimPitch") or 0) - p) >= 2 then
				pl:SetAttribute("AimPitch", p)
			end
		end
		if STANCES[stance] and pl:GetAttribute("Stance") ~= stance then
			pl:SetAttribute("Stance", stance)
		end
	end)
end
for _, name in ipairs({ "Shop", "Admin", "Feedback", "Leaderboard" }) do
	local f = Instance.new("RemoteFunction")
	f.Name = name
	f.Parent = remotes
end
remotes.Parent = ReplicatedStorage

local fx = Instance.new("Folder")
fx.Name = "FX"
fx.Parent = workspace

-- 업로드된 Blender 모델 불러오기 (없으면 내장 대체 모델)
ModelService.Load()

-- 운영 설정 (관리자 패널에서 바꾼 값 불러오기)
require(script.Parent.SettingsService).Init()

-- 맵
MapBuilder.SetupLighting()
local lobby = MapBuilder.BuildLobby()
local maps = {
	MapBuilder.BuildArena(),      -- 크로마 스퀘어
	MapBuilder.BuildSkyRooftop(), -- 스카이 루프탑
}
-- 시가전: ServerStorage에 BigCity 모델이 있으면 추가. 공동 작업 테스트에서는 모델이 늦게 들어오므로 들어오는 즉시 추가
do
	local CityMap = require(script.Parent.CityMap)
	local function tryCity()
		for _, m in ipairs(maps) do
			if m.Id == "BigCity" then
				return true
			end
		end
		local ok, city = pcall(CityMap.Build)
		if ok and city then
			table.insert(maps, city) -- MatchService가 같은 표를 쓰므로 바로 맵 목록에 나타남
			return true
		elseif not ok then
			warn("[SplashFront] 크로마 시티 맵 생성 실패: " .. tostring(city))
		end
		return false
	end
	if not tryCity() then
		task.spawn(function()
			local src = game:GetService("ServerStorage"):WaitForChild("BigCity", 300)
			if src then
				task.wait(2)
				tryCity()
			else
				warn("[SplashFront] 크로마 시티 맵: ServerStorage에 'BigCity' 모델이 없어 건너뜀")
			end
		end)
	end
end

-- 업로드한 표면 텍스처·HUD 아이콘 (없으면 단색·이모지로 대체)
ImageService.Load()
ImageService.ApplyTextures(lobby.Folder, ImageService.LobbyRules)
-- 로비 대형 간판: 업로드한 로고 이미지가 있으면 글자 대신 이미지로
do
	local url = ReplicatedStorage:FindFirstChild("Images") and ReplicatedStorage.Images:GetAttribute("icon_logo")
	local board = lobby.Folder:FindFirstChild("TitleBoard")
	local sg = board and board:FindFirstChild("Logo")
	if url then
		MapBuilder.ApplyMonitorLogo(lobby.Folder, url)
	end
	if url and sg then
		for _, c in ipairs(sg:GetChildren()) do
			if c:IsA("GuiObject") then
				c.Visible = false
			end
		end
		local img = Instance.new("ImageLabel")
		img.Size = UDim2.fromScale(0.96, 0.96)
		img.Position = UDim2.fromScale(0.02, 0.02)
		img.BackgroundTransparency = 1
		img.ScaleType = Enum.ScaleType.Fit
		img.Image = url
		img.Parent = sg
	end
end
for _, m in ipairs(maps) do
	if not m.NoTextures then
		ImageService.ApplyTextures(m.Folder)
	end
end
local activeCells = Instance.new("ObjectValue")
activeCells.Name = "ActiveCells" -- 클라이언트가 현재 맵의 바닥 셀을 찾는 용도
activeCells.Value = maps[1].Cells
activeCells.Parent = ReplicatedStorage
PaintService.Init(maps[1].Cells)

-- 서비스
Players.CharacterAutoLoads = false
DataService.Start()
CombatService.Init(remotes)
ShopService.Init(remotes)
MatchService.Init(remotes, maps, lobby)
Telemetry.Init(remotes)
AdminService.Init(remotes)
RankService.StartBoard(lobby.Leaderboard)
RankService.Init(remotes)
ItemService.Init(remotes)
QuestService.Init(remotes)
CombatService.OnSpecialUsed = function(pl)
	QuestService.Add(pl, "Specials", 1)
end
ItemService.OnUsed = function(pl)
	QuestService.Add(pl, "Items", 1)
end

-- 전투 틱 (잉크 충전·체력 회복)
task.spawn(function()
	local last = os.clock()
	while true do
		task.wait(0.1)
		local t = os.clock()
		CombatService.Tick(t - last)
		last = t
	end
end)

local function onPlayer(player)
	if not AdminService.Gate(player) then
		return
	end
	player.DevEnableMouseLock = false -- Shift는 달리기 (기본 시프트락 끔)
	DataService.Load(player)
	QuestService.Publish(player)
	player.CharacterAdded:Connect(function(character)
		local hum = character:WaitForChild("Humanoid")
		hum.Died:Connect(function()
			if not player:GetAttribute("InMatch") then
				task.delay(2, function()
					if player.Parent and not player:GetAttribute("InMatch") then
						player:LoadCharacter()
					end
				end)
			end
		end)
	end)
	player:LoadCharacter()
end

Players.PlayerAdded:Connect(onPlayer)
for _, p in ipairs(Players:GetPlayers()) do
	task.spawn(onPlayer, p)
end

MatchService.Run()
print("[SplashFront] 서버 준비 완료 (빌드 " .. Config.Build .. ") · 로비의 발판을 밟아 매치에 참가하세요")
