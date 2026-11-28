-- 여러 경기 동시 진행: 로비 서버 ↔ 경기 전용 서버(같은 플레이스의 예약 서버)
-- · 로비에서 대기열이 차면 예약 서버를 만들고 그 인원을 함께 이동 → 그 서버에서 한 판 진행 → 끝나면 다시 로비로
-- · 진행 중인 경기 서버는 MemoryStore에 (모드, 남은 시간, 빈자리)를 5초마다 알림
-- · [배틀 시작] = 빈자리 있는 진행 중 경기 중 남은 시간이 가장 긴 곳으로 바로 입장
-- · Studio에서는 이동이 안 되므로 지금처럼 한 서버 안에서 진행
local RunService = game:GetService("RunService")
local TeleportService = game:GetService("TeleportService")
local MemoryStoreService = game:GetService("MemoryStoreService")

local Router = {}

Router.IsMatchServer = game.PrivateServerId ~= "" and game.PrivateServerOwnerId == 0
Router.Enabled = not RunService:IsStudio()

local active = nil
if Router.Enabled then
	pcall(function()
		active = MemoryStoreService:GetSortedMap("SF_ActiveMatches_v1")
	end)
end

local saveFn = nil -- DataService.Save (순환 require 방지용 주입)
local myCode = nil -- 이 경기 서버의 접속 코드 (처음 도착한 사람이 알려 줌)

function Router.SetSaver(fn)
	saveFn = fn
end

function Router.JoinData(player)
	local ok, jd = pcall(function()
		return player:GetJoinData()
	end)
	local td = ok and jd and jd.TeleportData
	if type(td) == "table" and type(td.SF) == "table" then
		return td.SF
	end
	return nil
end

function Router.Code()
	return myCode
end

function Router.NoteArrival(player)
	local sf = Router.JoinData(player)
	if sf and type(sf.Code) == "string" and not myCode then
		myCode = sf.Code
	end
	return sf
end

-- 이동 전에 모두 저장 (다음 서버가 최신 데이터를 읽도록)
local function saveAll(list)
	local stamp = os.time()
	if not saveFn then
		return stamp
	end
	local pending = #list
	for _, pl in ipairs(list) do
		task.spawn(function()
			pcall(saveFn, pl)
			pending = pending - 1
		end)
	end
	local t0 = os.clock()
	while pending > 0 and os.clock() - t0 < 8 do
		task.wait(0.1)
	end
	return stamp
end

local function teleport(list, code, data)
	local opts = Instance.new("TeleportOptions")
	if code then
		opts.ReservedServerAccessCode = code
	end
	opts:SetTeleportData({ SF = data })
	local ok, err = pcall(function()
		TeleportService:TeleportAsync(game.PlaceId, list, opts)
	end)
	if not ok then
		warn("[SplashFront] 서버 이동 실패:", err)
	end
	return ok
end

-- 로비 → 새 경기 서버
function Router.Launch(q, list, mapId)
	if not Router.Enabled or Router.IsMatchServer or #list == 0 then
		return false
	end
	local ok, code = pcall(function()
		return TeleportService:ReserveServer(game.PlaceId)
	end)
	if not ok or type(code) ~= "string" then
		warn("[SplashFront] 경기 서버 예약 실패:", code)
		return false
	end
	local sides = {}
	for _, pl in ipairs(list) do
		sides[tostring(pl.UserId)] = pl:GetAttribute("QueueSide")
	end
	local stamp = saveAll(list)
	return teleport(list, code, {
		Kind = "Match", Queue = q.Id, Map = mapId, Sides = sides, Count = #list, Code = code, SavedAt = stamp,
	})
end

-- 진행 중인 경기 목록에서 빈자리가 있고 남은 시간이 가장 긴 곳
function Router.FindRunning(minLeft)
	if not Router.Enabled or Router.IsMatchServer or not active then
		return nil
	end
	local ok, items = pcall(function()
		return active:GetRangeAsync(Enum.SortDirection.Descending, 100)
	end)
	if not ok or type(items) ~= "table" then
		return nil
	end
	local nowT = workspace:GetServerTimeNow()
	local best = nil
	for _, it in ipairs(items) do
		local v = it.value
		if type(v) == "table" and (v.Open or 0) > 0 and type(v.Code) == "string"
			and (v.EndsAt or 0) - nowT > (minLeft or 45) then
			if not best or v.EndsAt > best.EndsAt then
				best = v
			end
		end
	end
	return best
end

-- 로비 → 진행 중인 경기 서버
function Router.JoinRunning(player, entry)
	local stamp = saveAll({ player })
	return teleport({ player }, entry.Code, { Kind = "Join", Code = entry.Code, SavedAt = stamp })
end

-- 경기 서버 → 로비 (공개 서버)
function Router.ToLobby(list)
	if not Router.Enabled or not Router.IsMatchServer then
		return false
	end
	local alive = {}
	for _, pl in ipairs(list) do
		if pl.Parent then
			table.insert(alive, pl)
		end
	end
	if #alive == 0 then
		return true
	end
	local stamp = saveAll(alive)
	local opts = Instance.new("TeleportOptions")
	opts:SetTeleportData({ SF = { Kind = "Lobby", SavedAt = stamp } })
	local ok, err = pcall(function()
		TeleportService:TeleportAsync(game.PlaceId, alive, opts)
	end)
	if not ok then
		warn("[SplashFront] 로비 이동 실패:", err)
	end
	return ok
end

-- 경기 서버 상태 알림 (60초 뒤 자동 만료 → 서버가 죽어도 목록에 남지 않음)
function Router.Publish(info)
	if not Router.IsMatchServer or not active or not myCode then
		return
	end
	info.Code = myCode
	pcall(function()
		active:SetAsync(myCode, info, 60, info.EndsAt or 0)
	end)
end

function Router.Unpublish()
	if not Router.IsMatchServer or not active or not myCode then
		return
	end
	pcall(function()
		active:RemoveAsync(myCode)
	end)
end

function Router.Init()
	TeleportService.TeleportInitFailed:Connect(function(player, result, msg)
		warn("[SplashFront] 이동 실패:", player.Name, result, msg)
		player:SetAttribute("Teleporting", nil)
	end)
	if Router.IsMatchServer then
		game:BindToClose(function()
			Router.Unpublish()
		end)
	end
end

return Router
