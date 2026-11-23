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

-- 원격 이벤트
local remotes = Instance.new("Folder")
remotes.Name = "Remotes"
for _, name in ipairs({ "Fire", "Special", "FX", "HitConfirm", "Damaged", "State", "Results", "Notify", "Queue", "CrateResult", "Telemetry" }) do
	local r = Instance.new("RemoteEvent")
	r.Name = name
	r.Parent = remotes
end
for _, name in ipairs({ "Shop", "Admin", "Feedback" }) do
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

-- 맵
MapBuilder.SetupLighting()
local lobby = MapBuilder.BuildLobby()
local maps = {
	MapBuilder.BuildArena(),      -- 크로마 스퀘어
	MapBuilder.BuildSkyRooftop(), -- 스카이 루프탑
}
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
	DataService.Load(player)
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
print("[SplashFront] 서버 준비 완료 (빌드 " .. Config.Build .. ") — 로비의 발판을 밟아 매치에 참가하세요")
