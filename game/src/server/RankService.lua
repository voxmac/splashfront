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

function RankService.StartBoard(textLabel)
	task.spawn(function()
		while true do
			local lines = { "  시즌 " .. Config.Season .. " 랭킹 TOP 10", "" }
			local ok = false
			if ordered then
				ok = pcall(function()
					local pages = ordered:GetSortedAsync(false, 10)
					local entries = pages:GetCurrentPage()
					for i, entry in ipairs(entries) do
						local userId = tonumber(string.sub(entry.key, 2))
						local name = "?"
						pcall(function()
							name = Players:GetNameFromUserIdAsync(userId)
						end)
						local tier = Config.GetTier(entry.value).Name
						table.insert(lines, string.format("  %2d. %s  %d (%s)", i, name, entry.value, tier))
					end
				end)
			end
			if not ok then
				-- DataStore를 쓸 수 없을 때(스튜디오 등)는 현재 서버 플레이어로 표시
				local list = {}
				for _, pl in ipairs(Players:GetPlayers()) do
					table.insert(list, { pl.Name, pl:GetAttribute("Rating") or Config.Rating.Start })
				end
				table.sort(list, function(a, b)
					return a[2] > b[2]
				end)
				for i, row in ipairs(list) do
					if i > 10 then
						break
					end
					table.insert(lines, string.format("  %2d. %s  %d (%s)", i, row[1], row[2], Config.GetTier(row[2]).Name))
				end
				table.insert(lines, "")
				table.insert(lines, "  (서버 내 순위 · 글로벌 랭킹은 게시 후 표시)")
			end
			textLabel.Text = table.concat(lines, "\n")
			task.wait(60)
		end
	end)
end

return RankService
