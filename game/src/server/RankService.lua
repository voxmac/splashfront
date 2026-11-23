-- 시즌 레이팅 + 글로벌 리더보드(OrderedDataStore)
local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage.Shared.Config)
local DataService = require(script.Parent.DataService)

local RankService = {}

local ordered = nil
pcall(function()
	ordered = DataStoreService:GetOrderedDataStore("SplashFront_Rating_" .. Config.DataVersion .. "_" .. Config.Season)
end)

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
			local lines = { "  🏆 시즌 " .. Config.Season .. " 랭킹 TOP 10", "" }
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
