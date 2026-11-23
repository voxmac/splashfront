-- 경기 중 제한시간 랜덤 미션
-- 새 미션 추가: MISSIONS 테이블에 { Id, Name, Desc, Duration, Bonus, Begin, Finish } 하나 추가
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage.Shared.Config)
local Combatants = require(script.Parent.Combatants)
local PaintService = require(script.Parent.PaintService)

local MissionService = {}

local api = nil      -- MatchService가 넘겨주는 함수 묶음
local info = nil     -- 맵 정보
local running = false
local current = nil
local generation = 0

local function maxKey(t)
	local best, bestV, tie = nil, 0, false
	for k, v in pairs(t) do
		if v > bestV then
			best, bestV, tie = k, v, false
		elseif v == bestV and v > 0 then
			tie = true
		end
	end
	if tie then
		return nil
	end
	return best
end

local function randomSpot()
	return info.MissionSpots[math.random(1, #info.MissionSpots)]
end

local function marker(position, radius, color)
	local p = Instance.new("Part")
	p.Name = "MissionZone"
	p.Shape = Enum.PartType.Cylinder
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.Material = Enum.Material.ForceField
	p.Color = color
	p.Size = Vector3.new(14, radius * 2, radius * 2)
	p.CFrame = CFrame.new(position + Vector3.new(0, 6, 0)) * CFrame.Angles(0, 0, math.rad(90))
	p.Parent = workspace:FindFirstChild("FX") or workspace
	return p
end

local MISSIONS = {
	{
		Id = "Hotspot", Name = "핫스팟 점령", Duration = 25, Bonus = 4,
		Desc = "빛나는 구역을 가장 많이 칠하라!",
		Begin = function(ctx)
			ctx.Pos = randomSpot()
			ctx.Radius = 12
			ctx.Part = marker(ctx.Pos, ctx.Radius, Color3.fromRGB(255, 230, 80))
		end,
		Finish = function(ctx)
			if ctx.Part then
				ctx.Part:Destroy()
			end
			return maxKey(PaintService.CountInRadius(ctx.Pos + Vector3.new(0, 1, 0), ctx.Radius))
		end,
	},
	{
		Id = "GoldenCan", Name = "골든 캔", Duration = 20, Bonus = 3,
		Desc = "황금 페인트통을 먼저 주워라!",
		Begin = function(ctx)
			ctx.Pos = randomSpot()
			local can = Instance.new("Part")
			can.Name = "GoldenCan"
			can.Shape = Enum.PartType.Cylinder
			can.Size = Vector3.new(3, 2.4, 2.4)
			can.Anchored = true
			can.CanCollide = false
			can.Material = Enum.Material.Neon
			can.Color = Color3.fromRGB(255, 200, 40)
			can.CFrame = CFrame.new(ctx.Pos + Vector3.new(0, 2.5, 0)) * CFrame.Angles(0, 0, math.rad(90))
			local light = Instance.new("PointLight")
			light.Color = can.Color
			light.Range = 16
			light.Brightness = 3
			light.Parent = can
			can.Parent = workspace:FindFirstChild("FX") or workspace
			ctx.Part = can
			ctx.Winner = nil
			can.Touched:Connect(function(hit)
				if ctx.Winner then
					return
				end
				local e = Combatants.FromPart(hit)
				if e and e.Alive then
					ctx.Winner = e.OwnerId
					ctx.Taker = e
					PaintService.PaintAt(ctx.Pos, 16, e.OwnerId, e)
					can:Destroy()
					api.EndMissionEarly(ctx)
				end
			end)
		end,
		Finish = function(ctx)
			if ctx.Part and ctx.Part.Parent then
				ctx.Part:Destroy()
			end
			return ctx.Winner
		end,
	},
	{
		Id = "Hunt", Name = "스플래시 헌트", Duration = 25, Bonus = 3,
		Desc = "먼저 3킬을 달성하라!",
		Begin = function(ctx)
			ctx.Kills = {}
			ctx.Conn = Combatants.Killed:Connect(function(killer)
				if killer and not ctx.Winner then
					ctx.Kills[killer.OwnerId] = (ctx.Kills[killer.OwnerId] or 0) + 1
					if ctx.Kills[killer.OwnerId] >= 3 then
						ctx.Winner = killer.OwnerId
						api.EndMissionEarly(ctx)
					end
				end
			end)
		end,
		Finish = function(ctx)
			ctx.Conn.Disconnect()
			return ctx.Winner
		end,
	},
	{
		Id = "PaintRush", Name = "페인트 러시", Duration = 20, Bonus = 3,
		Desc = "20초 동안 가장 많이 칠하라!",
		Begin = function(ctx)
			ctx.Cells = {}
			ctx.Conn = Combatants.Painted:Connect(function(e, n)
				ctx.Cells[e.OwnerId] = (ctx.Cells[e.OwnerId] or 0) + n
			end)
		end,
		Finish = function(ctx)
			ctx.Conn.Disconnect()
			return maxKey(ctx.Cells)
		end,
	},
	{
		Id = "Headhunter", Name = "헤드헌터", Duration = 25, Bonus = 2,
		Desc = "헤드샷으로 먼저 처치하라!",
		Begin = function(ctx)
			ctx.Conn = Combatants.Killed:Connect(function(killer, victim, headshot)
				if killer and headshot and not ctx.Winner then
					ctx.Winner = killer.OwnerId
					ctx.Taker = killer
					api.EndMissionEarly(ctx)
				end
			end)
		end,
		Finish = function(ctx)
			ctx.Conn.Disconnect()
			return ctx.Winner
		end,
	},
}
MissionService.List = MISSIONS

local function finish(ctx)
	if ctx.Done then
		return
	end
	ctx.Done = true
	local ok, winner = pcall(ctx.Def.Finish, ctx)
	if not ok then
		warn("[SplashFront] mission error:", winner)
		winner = nil
	end
	if current == ctx then
		current = nil
	end
	api.SetMission(nil)
	if running and winner then
		api.Cue("mission_result", winner)
		api.AddBonus(winner, ctx.Def.Bonus)
		api.RewardOwner(winner, Config.Rewards.Mission)
		if ctx.Taker then
			ctx.Taker.MissionWins = ctx.Taker.MissionWins + 1
		end
		api.Announce(string.format("%s 성공! %s +%d", ctx.Def.Name, api.OwnerName(winner), ctx.Def.Bonus), api.ColorOf(winner))
	elseif running then
		api.Cue("mission_fail")
		api.Announce(ctx.Def.Name .. " — 아무도 달성하지 못했어요", Color3.fromRGB(200, 200, 200))
	end
end

function MissionService.SetMap(mapInfo)
	info = mapInfo
end

function MissionService.Init(mapInfo, matchApi)
	info = mapInfo
	api = matchApi
	matchApi.EndMissionEarly = function(ctx)
		task.defer(finish, ctx)
	end
end

function MissionService.Start()
	running = true
	generation = generation + 1
	local myGen = generation
	task.spawn(function()
		task.wait(Config.MissionFirstDelay)
		local last = nil
		while running and myGen == generation do
			local def
			repeat
				def = MISSIONS[math.random(1, #MISSIONS)]
			until def ~= last or #MISSIONS == 1
			last = def
			local ctx = { Def = def }
			current = ctx
			local ok, err = pcall(def.Begin, ctx)
			if not ok then
				warn("[SplashFront] mission begin error:", err)
			end
			api.SetMission({
				Name = def.Name, Desc = def.Desc, Bonus = def.Bonus,
				EndsAt = workspace:GetServerTimeNow() + def.Duration, Pos = ctx.Pos,
			})
			api.Cue("mission_start")
			local t = 0
			while t < def.Duration and not ctx.Done and running do
				task.wait(0.25)
				t = t + 0.25
			end
			finish(ctx)
			task.wait(Config.MissionInterval - def.Duration)
		end
	end)
end

function MissionService.Stop()
	running = false
	generation = generation + 1
	if current then
		finish(current)
	end
	current = nil
end

return MissionService
