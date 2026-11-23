-- 클로즈 테스트 입장 제한 + 테스터용 관리자 패널(F2) 명령
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage.Shared.Config)
local Weapons = require(ReplicatedStorage.Shared.Weapons)
local Cosmetics = require(ReplicatedStorage.Shared.Cosmetics)
local DataService = require(script.Parent.DataService)
local CrateService = require(script.Parent.CrateService)
local MatchService = require(script.Parent.MatchService)
local Combatants = require(script.Parent.Combatants)
local Telemetry = require(script.Parent.TelemetryService)

local AdminService = {}

local function inList(list, userId)
	for _, id in ipairs(list) do
		if id == userId then
			return true
		end
	end
	return false
end

function AdminService.IsAdmin(player)
	return RunService:IsStudio() or inList(Config.CBT.Admins, player.UserId)
end

function AdminService.CanJoin(player)
	if not Config.CBT.Enabled or RunService:IsStudio() then
		return true
	end
	if inList(Config.CBT.Testers, player.UserId) or inList(Config.CBT.Admins, player.UserId) then
		return true
	end
	if Config.CBT.GroupId ~= 0 then
		local ok, rank = pcall(function()
			return player:GetRankInGroup(Config.CBT.GroupId)
		end)
		if ok and rank >= Config.CBT.GroupMinRank then
			return true
		end
	end
	return false
end

local missionDefaults = { First = Config.MissionFirstDelay, Interval = Config.MissionInterval }

local ACTIONS = {}

ACTIONS.time = function(player, n)
	n = tonumber(n) or 30
	if MatchService.SetTimeLeft(n) then
		return "남은 시간 " .. n .. "초로 변경"
	end
	return "경기/카운트다운 중에만 가능"
end

ACTIONS.endMatch = function()
	if MatchService.SetTimeLeft(0) then
		return "경기를 종료합니다"
	end
	return "진행 중인 경기 없음"
end

ACTIONS.coins = function(player, n)
	local p = DataService.Get(player)
	n = math.clamp(tonumber(n) or 5000, -1000000, 1000000)
	p.Coins = math.max(0, p.Coins + n)
	DataService.Publish(player)
	return string.format("코인 %+d → %d", n, p.Coins)
end

ACTIONS.unlockAll = function(player)
	local p = DataService.Get(player)
	for _, w in ipairs(Weapons.List) do
		p.Owned[w.Id] = true
	end
	DataService.Publish(player)
	return "모든 무기 해금"
end

ACTIONS.crate = function(player, n)
	n = math.clamp(math.floor(tonumber(n) or 1), 1, 50)
	local counts = {}
	local last = nil
	for _ = 1, n do
		last = CrateService.Open(player)
		if last then
			counts[last.RarityName] = (counts[last.RarityName] or 0) + 1
		end
	end
	local parts = {}
	for _, r in ipairs(Cosmetics.Rarities) do
		table.insert(parts, string.format("%s %d", r.Name, counts[r.Name] or 0))
	end
	return string.format("무료 개봉 %d회: %s", n, table.concat(parts, " · "))
end

ACTIONS.bots = function()
	Config.FillWithBots = not Config.FillWithBots
	return "봇 채우기: " .. (Config.FillWithBots and "켜짐" or "꺼짐") .. " (다음 경기부터)"
end

ACTIONS.rankedBots = function()
	Config.RankedAllowBots = not Config.RankedAllowBots
	return "봇 포함 랭크 반영: " .. (Config.RankedAllowBots and "켜짐" or "꺼짐")
end

ACTIONS.fastMissions = function()
	if Config.MissionInterval == missionDefaults.Interval then
		Config.MissionFirstDelay = 3
		Config.MissionInterval = 27
		return "빠른 미션: 켜짐 (다음 경기부터 3초 후 시작, 27초 간격)"
	end
	Config.MissionFirstDelay = missionDefaults.First
	Config.MissionInterval = missionDefaults.Interval
	return "빠른 미션: 꺼짐"
end

ACTIONS.special = function(player)
	local e = Combatants.FromPlayer(player)
	if not e then
		return "경기 중에만 가능"
	end
	e.Special = Config.SpecialCells
	Combatants.Sync(e)
	return "스페셜 게이지 100%"
end

ACTIONS.rating = function(player, n)
	local p = DataService.Get(player)
	p.Rating = math.max(0, math.floor(tonumber(n) or Config.Rating.Start))
	DataService.Publish(player)
	return "레이팅 " .. p.Rating .. " (" .. Config.GetTier(p.Rating).Name .. ")"
end

ACTIONS.resetProfile = function(player)
	DataService.Reset(player)
	player:SetAttribute("FirstMatch", true)
	return "내 데이터 초기화 (첫 접속 상태)"
end

ACTIONS.nextMap = function(player, arg)
	return "다음 경기 맵: " .. MatchService.SetNextMap(arg)
end

ACTIONS.balance = function()
	return Telemetry.BalanceReport()
end

ACTIONS.feedback = function()
	return Telemetry.FeedbackList()
end

function AdminService.Init(remotes)
	remotes.Admin.OnServerInvoke = function(player, action, arg)
		if not AdminService.IsAdmin(player) then
			return { ok = false, msg = "관리자 권한 없음" }
		end
		local fn = ACTIONS[action]
		if not fn then
			return { ok = false, msg = "알 수 없는 명령" }
		end
		local ok, result = pcall(fn, player, arg)
		print(string.format("[SplashFront][관리자] %s → %s(%s): %s", player.Name, tostring(action), tostring(arg), tostring(result)))
		if not ok then
			return { ok = false, msg = "오류: " .. tostring(result) }
		end
		return { ok = true, msg = result }
	end
end

-- 입장 시 호출: 허용되지 않으면 내보냄
function AdminService.Gate(player)
	if not AdminService.CanJoin(player) then
		player:Kick(Config.CBT.KickMessage)
		return false
	end
	player:SetAttribute("IsAdmin", AdminService.IsAdmin(player))
	return true
end

return AdminService
