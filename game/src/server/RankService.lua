-- 시즌 레이팅 + 글로벌 리더보드(OrderedDataStore)
local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage.Shared.Config)
local DataService = require(script.Parent.DataService)

local RankService = {}

local ordered = nil
local meta = nil -- userId -> { n = 이름, w = 승수, r = 레이팅 } (TOP 50 창에 승수 표시용)
pcall(function()
	ordered = DataStoreService:GetOrderedDataStore("SplashFront_Rating_" .. Config.DataVersion .. "_" .. Config.Season)
	meta = DataStoreService:GetDataStore("SplashFront_RankMeta_" .. Config.DataVersion .. "_" .. Config.Season)
end)

local cache = { At = -1e9, Rows = nil }
local CACHE_SECONDS = 90

-- 경기가 끝날 때마다 이름·승수·레이팅을 기록
function RankService.RecordMeta(player)
	local p = DataService.Get(player)
	if not p or not meta then
		return
	end
	task.spawn(function()
		pcall(function()
			meta:SetAsync("u" .. player.UserId, { n = player.DisplayName, w = p.Wins or 0, r = p.Rating })
		end)
	end)
end

local function serverRows()
	local list = {}
	for _, pl in ipairs(Players:GetPlayers()) do
		local r = pl:GetAttribute("Rating") or Config.Rating.Start
		table.insert(list, { UserId = pl.UserId, Name = pl.DisplayName, Rating = r, Tier = Config.GetTier(r).Name, Wins = pl:GetAttribute("Wins") or 0 })
	end
	table.sort(list, function(a, b)
		return a.Rating > b.Rating
	end)
	for i, row in ipairs(list) do
		row.Rank = i
	end
	return list
end

-- 상위 count명 (기본 50). DataStore를 못 쓰면 현재 서버 플레이어로 대신
function RankService.GetTop(count)
	count = math.clamp(count or 50, 1, 100)
	if cache.Rows and os.clock() - cache.At < CACHE_SECONDS then
		return cache.Rows, cache.Global
	end
	local rows = nil
	if ordered then
		pcall(function()
			local entries = ordered:GetSortedAsync(false, count):GetCurrentPage()
			local out = {}
			local pending = #entries
			for i, entry in ipairs(entries) do
				local userId = tonumber(string.sub(entry.key, 2)) or 0
				out[i] = { Rank = i, UserId = userId, Name = "?", Rating = entry.value, Tier = Config.GetTier(entry.value).Name, Wins = 0 }
				task.spawn(function()
					local ok, m = pcall(function()
						return meta and meta:GetAsync(entry.key)
					end)
					if ok and type(m) == "table" then
						out[i].Name = m.n or out[i].Name
						out[i].Wins = m.w or 0
					else
						pcall(function()
							out[i].Name = Players:GetNameFromUserIdAsync(userId)
						end)
					end
					pending = pending - 1
				end)
			end
			local t0 = os.clock()
			while pending > 0 and os.clock() - t0 < 8 do
				task.wait(0.1)
			end
			if #out > 0 then
				rows = out
			end
		end)
	end
	local global = rows ~= nil
	rows = rows or serverRows()
	cache = { At = os.clock(), Rows = rows, Global = global }
	return rows, global
end

function RankService.Init(remotes)
	remotes.Leaderboard.OnServerInvoke = function(player)
		local rows, global = RankService.GetTop(50)
		return { Rows = rows, Global = global, Season = Config.Season }
	end
end

-- performance: 0~1 (팀 내 기여 순위). 반환: 레이팅 변화량
function RankService.Apply(player, won, performance)
	local p = DataService.Get(player)
	if not p then
		return 0
	end
	local delta = won and Config.Rating.Win or Config.Rating.Lose
	delta = delta + math.floor(Config.Rating.PerformanceMax * (performance or 0) + 0.5)
	p.Rating = math.max(0, p.Rating + delta)
	DataService.Publish(player)
	if ordered then
		task.spawn(function()
			pcall(function()
				ordered:SetAsync("u" .. player.UserId, p.Rating)
			end)
		end)
	end
	return delta
end

-- 로비 랭킹 보드: 글로벌 TOP 10(데이터스토어, 60초 캐시)에 지금 접속 중인 플레이어의 최신 레이팅을 바로 합쳐서 보여 주고,
-- 최근 경기 결과(맵·승리 팀·MVP)를 함께 표시. 경기가 끝나면 즉시 갱신
local boardLabel = nil
local recent = {}       -- 최근 경기 { Map, Mode, Winner, MVP, Kills, Cells, At }
local globalTop = { At = -1e9, Rows = {} }
local nameCache = {}

local function fetchGlobal()
	if not ordered or os.clock() - globalTop.At < 60 then
		return
	end
	globalTop.At = os.clock()
	pcall(function()
		local entries = ordered:GetSortedAsync(false, 10):GetCurrentPage()
		local rows = {}
		for _, entry in ipairs(entries) do
			local userId = tonumber(string.sub(entry.key, 2)) or 0
			if not nameCache[userId] then
				pcall(function()
					nameCache[userId] = Players:GetNameFromUserIdAsync(userId)
				end)
			end
			table.insert(rows, { UserId = userId, Name = nameCache[userId] or "?", Rating = entry.value })
		end
		globalTop.Rows = rows
	end)
end

local function mergedTop(n)
	local byId = {}
	for _, r in ipairs(globalTop.Rows) do
		byId[r.UserId] = { UserId = r.UserId, Name = r.Name, Rating = r.Rating, Online = false }
	end
	for _, pl in ipairs(Players:GetPlayers()) do
		byId[pl.UserId] = { UserId = pl.UserId, Name = pl.DisplayName, Rating = pl:GetAttribute("Rating") or Config.Rating.Start, Online = true,
			Wins = pl:GetAttribute("Wins") or 0 }
	end
	local list = {}
	for _, r in pairs(byId) do
		table.insert(list, r)
	end
	table.sort(list, function(a, b)
		return a.Rating > b.Rating
	end)
	while #list > n do
		table.remove(list)
	end
	return list
end

local function esc(t)
	return (tostring(t):gsub("&", "&amp;"):gsub("<", "&lt;"):gsub(">", "&gt;"))
end

function RankService.RefreshBoard()
	if not boardLabel then
		return
	end
	fetchGlobal()
	local lines = { string.format('<font color="#F0FF28"><b>시즌 %s 랭킹 TOP 10</b></font>   <font color="#8FA0C8" size="20">실시간</font>', Config.Season) }
	for i, r in ipairs(mergedTop(10)) do
		local medal = (i == 1 and "#FFD84A") or (i == 2 and "#D8E0F0") or (i == 3 and "#E09A5A") or "#FFFFFF"
		table.insert(lines, string.format('<font color="%s">%2d.</font> %s  <font color="#7FE8FF">%d</font> <font color="#A8B4D8" size="22">%s</font>%s',
			medal, i, esc(r.Name), r.Rating, Config.GetTier(r.Rating).Name, r.Online and '  <font color="#3CFF8C" size="20">● 접속 중</font>' or ""))
	end
	table.insert(lines, "")
	table.insert(lines, '<font color="#FF4FD0"><b>최근 경기</b></font>')
	if #recent == 0 then
		table.insert(lines, '<font color="#8FA0C8" size="22">아직 끝난 경기가 없어요 — 발판에 올라 첫 경기를 시작하세요</font>')
	end
	for i = 1, math.min(3, #recent) do
		local m = recent[i]
		local ago = math.floor((os.time() - m.At) / 60)
		table.insert(lines, string.format('<font size="24">%s · %s  승리 <font color="#FFD84A">%s</font>  MVP <font color="#7FE8FF">%s</font> (%d킬)  <font color="#8FA0C8">%s</font></font>',
			esc(m.Map), esc(m.Mode), esc(m.Winner or "-"), esc(m.MVP or "-"), m.Kills or 0, ago < 1 and "방금" or (ago .. "분 전")))
	end
	boardLabel.Text = table.concat(lines, "\n")
end

-- MatchService가 경기 끝날 때 부름
function RankService.NoteMatch(info)
	info.At = os.time()
	table.insert(recent, 1, info)
	while #recent > 5 do
		table.remove(recent)
	end
	cache.At = -1e9 -- TOP 50 창도 새로 읽게
	globalTop.At = -1e9
	task.delay(3, RankService.RefreshBoard) -- 레이팅 저장 직후 반영
end

function RankService.StartBoard(textLabel)
	boardLabel = textLabel
	textLabel.RichText = true
	textLabel.TextSize = 27
	textLabel.LineHeight = 1.05
	Players.PlayerAdded:Connect(function()
		task.delay(6, RankService.RefreshBoard)
	end)
	Players.PlayerRemoving:Connect(function()
		task.delay(1, RankService.RefreshBoard)
	end)
	task.spawn(function()
		while true do
			pcall(RankService.RefreshBoard)
			task.wait(10)
		end
	end)
end

return RankService
