-- 일일·주간 퀘스트: 한국 시간 자정(일일)·월요일 0시(주간)에 바뀜. 같은 날엔 모든 플레이어가 같은 퀘스트
-- 진행도는 프로필(p.Quests)에 저장, 달성하면 자동으로 코인·경험치 지급
-- 클라이언트에는 속성 "Quests"(JSON)로 보냄
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage.Shared.Config)
local DataService = require(script.Parent.DataService)

local QuestService = {}

local remotes = nil
local KST = 9 * 3600

local function dayKey()
	return math.floor((os.time() + KST) / 86400)
end
local function weekKey()
	-- 1970-01-01은 목요일 → +3일 하면 월요일 시작 주
	return math.floor((os.time() + KST + 3 * 86400) / (7 * 86400))
end
local function secondsLeft(period)
	local t = os.time() + KST
	if period == "Daily" then
		return 86400 - (t % 86400)
	end
	local w = 7 * 86400
	return w - ((t + 3 * 86400) % w)
end

-- 기간 키를 씨앗으로 퀘스트 N개를 고름 (모두 같은 결과)
local function pick(period, key)
	local pool = Config.Quests[period]
	local idx = {}
	for i = 1, #pool do
		idx[i] = i
	end
	local rng = Random.new(key * 7919 + (period == "Daily" and 1 or 2))
	for i = #idx, 2, -1 do
		local j = rng:NextInteger(1, i)
		idx[i], idx[j] = idx[j], idx[i]
	end
	local out = {}
	for i = 1, math.min(Config.Quests.PerPeriod, #idx) do
		table.insert(out, pool[idx[i]])
	end
	return out
end

local function ensure(p)
	p.Quests = type(p.Quests) == "table" and p.Quests or {}
	local q = p.Quests
	for _, period in ipairs({ "Daily", "Weekly" }) do
		local key = (period == "Daily") and dayKey() or weekKey()
		local cur = q[period]
		if type(cur) ~= "table" or cur.Key ~= key then
			local list = {}
			for _, def in ipairs(pick(period, key)) do
				table.insert(list, { Id = def.Id, P = 0, Done = false })
			end
			q[period] = { Key = key, List = list }
		end
	end
	return q
end

local function defOf(period, id)
	for _, d in ipairs(Config.Quests[period]) do
		if d.Id == id then
			return d
		end
	end
	return nil
end

function QuestService.Publish(player)
	local p = DataService.Get(player)
	if not p then
		return
	end
	local q = ensure(p)
	local view = {}
	for _, period in ipairs({ "Daily", "Weekly" }) do
		for _, it in ipairs(q[period].List) do
			local d = defOf(period, it.Id)
			if d then
				table.insert(view, { Period = period, Name = d.Name, P = math.min(it.P, d.Goal), Goal = d.Goal, Reward = d.Reward, Done = it.Done,
					Left = secondsLeft(period) })
			end
		end
	end
	player:SetAttribute("Quests", HttpService:JSONEncode(view))
end

-- 통계 stat을 n만큼 올림 (달성 시 보상)
function QuestService.Add(player, stat, n)
	if not player or not player.Parent or (n or 0) <= 0 then
		return
	end
	local p = DataService.Get(player)
	if not p then
		return
	end
	local q = ensure(p)
	local changed = false
	for _, period in ipairs({ "Daily", "Weekly" }) do
		for _, it in ipairs(q[period].List) do
			local d = defOf(period, it.Id)
			if d and d.Stat == stat and not it.Done then
				it.P = it.P + n
				changed = true
				if it.P >= d.Goal then
					it.Done = true
					DataService.AddCoins(player, d.Reward)
					DataService.AddXP(player, Config.XP.Quest)
					if remotes then
						remotes.Notify:FireClient(player, string.format("[%s] %s 완료! +%d 코인", period == "Daily" and "일일" or "주간", d.Name, d.Reward),
							Color3.fromRGB(120, 255, 170))
					end
				end
			end
		end
	end
	if changed then
		QuestService.Publish(player)
	end
end

function QuestService.Init(remoteFolder)
	remotes = remoteFolder
	-- 날짜가 바뀌면 새 퀘스트로 (1분마다 확인)
	task.spawn(function()
		while true do
			for _, pl in ipairs(Players:GetPlayers()) do
				QuestService.Publish(pl)
			end
			task.wait(60)
		end
	end)
end

return QuestService
