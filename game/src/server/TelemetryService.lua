-- 클로즈 테스트 지표 수집
-- 1) Roblox AnalyticsService: 온보딩 퍼널 / 경제 / 커스텀 이벤트 → Creator Hub > 분석 에서 확인
-- 2) 무기별 밸런스 통계 (자체 DataStore) → 관리자 패널 "밸런스 리포트"
-- 3) 게임 내 피드백 (자체 DataStore) → 관리자 패널 "피드백 보기"
local AnalyticsService = game:GetService("AnalyticsService")
local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage.Shared.Config)
local Weapons = require(ReplicatedStorage.Shared.Weapons)

local Telemetry = {}

local balanceStore, feedbackStore
pcall(function()
	balanceStore = DataStoreService:GetDataStore("SplashFront_Balance_" .. Config.DataVersion)
	feedbackStore = DataStoreService:GetDataStore("SplashFront_Feedback_" .. Config.DataVersion)
end)

local funnelDone = {}   -- player -> { [step] = true }
local joinTime = {}
local lastFeedback = {}

-- 내부 메모리 집계 (DataStore를 못 쓸 때 리포트용)
local localBalance = {}

local function fields(a, b, c)
	local f = {}
	pcall(function()
		if a then
			f[Enum.AnalyticsCustomFieldKeys.CustomField01.Name] = tostring(a)
		end
		if b then
			f[Enum.AnalyticsCustomFieldKeys.CustomField02.Name] = tostring(b)
		end
		if c then
			f[Enum.AnalyticsCustomFieldKeys.CustomField03.Name] = tostring(c)
		end
	end)
	return f
end

------------------------------------------------------------------------
-- AnalyticsService 래퍼 (실패해도 게임에 영향 없음)
------------------------------------------------------------------------
-- 온보딩 퍼널 단계 (세션당 1회)
Telemetry.Steps = {
	Joined = { 1, "입장" },
	Queued = { 2, "대기열 참가" },
	MatchStarted = { 3, "첫 경기 시작" },
	FirstPaint = { 4, "첫 페인트" },
	FirstKill = { 5, "첫 처치" },
	MatchFinished = { 6, "첫 경기 완료" },
	SecondMatch = { 7, "두 번째 경기 시작" },
	OpenedShop = { 8, "상점 열기" },
}

function Telemetry.Funnel(player, key)
	local step = Telemetry.Steps[key]
	if not step or not player then
		return
	end
	funnelDone[player] = funnelDone[player] or {}
	if funnelDone[player][key] then
		return
	end
	funnelDone[player][key] = true
	pcall(function()
		AnalyticsService:LogOnboardingFunnelStepEvent(player, step[1], step[2])
	end)
end

function Telemetry.Economy(player, isSource, amount, endingBalance, transactionType, sku)
	pcall(function()
		AnalyticsService:LogEconomyEvent(player,
			isSource and Enum.AnalyticsEconomyFlowType.Source or Enum.AnalyticsEconomyFlowType.Sink,
			"Coins", amount, endingBalance, transactionType, sku)
	end)
end

function Telemetry.Custom(player, name, value, a, b, c)
	pcall(function()
		AnalyticsService:LogCustomEvent(player, name, value or 1, fields(a, b, c))
	end)
end

------------------------------------------------------------------------
-- 무기 밸런스 통계
------------------------------------------------------------------------
local STAT_KEYS = { "Matches", "Wins", "Kills", "Deaths", "Shots", "Hits", "Headshots", "Cells", "Seconds" }

-- rows: { {WeaponId, Won, Kills, Deaths, Shots, Hits, Headshots, Cells, Seconds}, ... } (사람 플레이어만)
function Telemetry.RecordMatch(rows)
	local agg = {}
	for _, r in ipairs(rows) do
		local a = agg[r.WeaponId]
		if not a then
			a = {}
			for _, k in ipairs(STAT_KEYS) do
				a[k] = 0
			end
			agg[r.WeaponId] = a
		end
		a.Matches = a.Matches + 1
		a.Wins = a.Wins + (r.Won and 1 or 0)
		for _, k in ipairs({ "Kills", "Deaths", "Shots", "Hits", "Headshots", "Cells", "Seconds" }) do
			a[k] = a[k] + (r[k] or 0)
		end
	end
	for weaponId, a in pairs(agg) do
		local mem = localBalance[weaponId] or {}
		for _, k in ipairs(STAT_KEYS) do
			mem[k] = (mem[k] or 0) + a[k]
		end
		localBalance[weaponId] = mem
		if balanceStore then
			task.spawn(function()
				pcall(function()
					balanceStore:UpdateAsync("w_" .. weaponId, function(old)
						old = type(old) == "table" and old or {}
						for _, k in ipairs(STAT_KEYS) do
							old[k] = (old[k] or 0) + a[k]
						end
						return old
					end)
				end)
			end)
		end
	end
end

function Telemetry.BalanceReport()
	local lines = { string.format("%-10s %5s %6s %6s %6s %7s %7s", "무기", "판수", "승률", "K/D", "명중률", "헤드%", "셀/분") }
	for _, w in ipairs(Weapons.List) do
		local s = nil
		if balanceStore then
			pcall(function()
				s = balanceStore:GetAsync("w_" .. w.Id)
			end)
		end
		s = s or localBalance[w.Id]
		if s and (s.Matches or 0) > 0 then
			local kd = (s.Kills or 0) / math.max(1, s.Deaths or 0)
			local acc = (s.Hits or 0) / math.max(1, s.Shots or 0) * 100
			local head = (s.Headshots or 0) / math.max(1, s.Hits or 0) * 100
			local cpm = (s.Cells or 0) / math.max(1, (s.Seconds or 0) / 60)
			table.insert(lines, string.format("%-10s %5d %5.0f%% %6.2f %5.0f%% %6.0f%% %7.0f", w.Id, s.Matches,
				(s.Wins or 0) / s.Matches * 100, kd, acc, head, cpm))
		else
			table.insert(lines, string.format("%-10s %5d  (데이터 없음)", w.Id, 0))
		end
	end
	table.insert(lines, "")
	table.insert(lines, "판단 기준(예시): 승률 45~55%, K/D 0.8~1.25 밖이면 조정 후보")
	return table.concat(lines, "\n")
end

------------------------------------------------------------------------
-- 피드백
------------------------------------------------------------------------
local CATEGORIES = { Bug = "버그", Balance = "밸런스", Fun = "재미", Other = "기타" }

function Telemetry.SubmitFeedback(player, rating, category, text)
	if type(rating) ~= "number" or rating < 1 or rating > 5 then
		return { ok = false, msg = "별점을 골라주세요" }
	end
	if not CATEGORIES[category] then
		category = "Other"
	end
	if type(text) ~= "string" then
		text = ""
	end
	text = string.sub(text, 1, 500)
	local now = os.time()
	if lastFeedback[player] and now - lastFeedback[player] < Config.CBT.FeedbackCooldown then
		return { ok = false, msg = "잠시 후 다시 보내주세요" }
	end
	lastFeedback[player] = now
	local entry = {
		t = now, u = player.UserId, n = player.Name, r = math.floor(rating), c = category, m = text,
		b = Config.Build, phase = player:GetAttribute("InMatch") and "match" or "lobby",
	}
	Telemetry.Custom(player, "Feedback", entry.r, category, Config.Build)
	print(string.format("[SplashFront][피드백] %s ★%d [%s] %s", player.Name, entry.r, CATEGORIES[category], text))
	if feedbackStore then
		local key = "day_" .. os.date("!%Y%m%d", now)
		task.spawn(function()
			pcall(function()
				feedbackStore:UpdateAsync(key, function(old)
					old = type(old) == "table" and old or {}
					table.insert(old, entry)
					while #old > 300 do
						table.remove(old, 1)
					end
					return old
				end)
			end)
		end)
	end
	return { ok = true, msg = "피드백 고마워요! 테스트에 큰 도움이 됩니다" }
end

function Telemetry.FeedbackList()
	local list = {}
	if feedbackStore then
		for d = 0, 1 do
			local key = "day_" .. os.date("!%Y%m%d", os.time() - d * 86400)
			pcall(function()
				local v = feedbackStore:GetAsync(key)
				if type(v) == "table" then
					for _, e in ipairs(v) do
						table.insert(list, e)
					end
				end
			end)
		end
	end
	table.sort(list, function(a, b)
		return a.t > b.t
	end)
	local lines = {}
	local sum, n = 0, 0
	for _, e in ipairs(list) do
		sum = sum + e.r
		n = n + 1
	end
	if n == 0 then
		return "최근 2일 피드백 없음 (DataStore가 꺼져 있으면 서버 출력창에만 기록됩니다)"
	end
	table.insert(lines, string.format("최근 2일 피드백 %d건 · 평균 ★%.1f", n, sum / n))
	for i, e in ipairs(list) do
		if i > 20 then
			break
		end
		table.insert(lines, string.format("%s  ★%d [%s] %s: %s", os.date("!%m/%d %H:%M", e.t + 9 * 3600), e.r,
			CATEGORIES[e.c] or e.c, e.n, e.m))
	end
	return table.concat(lines, "\n")
end

------------------------------------------------------------------------
function Telemetry.Init(remotes)
	remotes.Feedback.OnServerInvoke = function(player, rating, category, text)
		return Telemetry.SubmitFeedback(player, rating, category, text)
	end
	remotes.Telemetry.OnServerEvent:Connect(function(player, key)
		-- 클라이언트에서 오는 건 상점 열기 같은 UI 단계만 허용
		if key == "OpenedShop" then
			Telemetry.Funnel(player, key)
		end
	end)
	Players.PlayerAdded:Connect(function(player)
		joinTime[player] = os.clock()
		Telemetry.Funnel(player, "Joined")
	end)
	for _, p in ipairs(Players:GetPlayers()) do
		joinTime[p] = os.clock()
	end
	Players.PlayerRemoving:Connect(function(player)
		if joinTime[player] then
			Telemetry.Custom(player, "SessionMinutes", math.floor((os.clock() - joinTime[player]) / 60 + 0.5), Config.Build)
		end
		joinTime[player] = nil
		funnelDone[player] = nil
		lastFeedback[player] = nil
	end)
end

return Telemetry
