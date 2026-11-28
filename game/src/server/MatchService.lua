-- 매치 흐름: 로비 대기 → 카운트다운 → 경기(터프/플래그/솔로) → 결과·보상·랭크 → 로비
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage.Shared.Config)
local Weapons = require(ReplicatedStorage.Shared.Weapons)
local Cosmetics = require(ReplicatedStorage.Shared.Cosmetics)
local ModelKit = require(ReplicatedStorage.Shared.ModelKit)
local Combatants = require(script.Parent.Combatants)
local PaintService = require(script.Parent.PaintService)
local CombatService = require(script.Parent.CombatService)
local MissionService = require(script.Parent.MissionService)
local BotService = require(script.Parent.BotService)
local DataService = require(script.Parent.DataService)
local WeaponSkins = require(ReplicatedStorage.Shared.WeaponSkins)
local RankService = require(script.Parent.RankService)
local Telemetry = require(script.Parent.TelemetryService)
local ItemService = require(script.Parent.ItemService)
local QuestService = require(script.Parent.QuestService)
local MapBuilder = require(script.Parent.MapBuilder)
local Router = require(script.Parent.MatchRouter)

local MatchService = {}

local remotes, arena, lobby
local maps = {}
local nextMapIndex = 1
local forcedNextMap = false -- 관리자가 다음 맵을 지정했을 때만 그 맵 (아니면 방장 선택, 선택 없으면 랜덤)
local queueMap = {}    -- queueId -> 방장이 고른 맵 Id ("random" 포함)
local joinAt = {}      -- player -> 대기열 참가 시각 (발판 이탈 검사 유예)
local S = {
	Phase = "Lobby",
	QueueId = nil,
	Mode = nil,
	EndsAt = 0,
	Owners = {},     -- 경기 참가 ownerId 목록 { {OwnerId, Name, Color} }
	Bonus = {},      -- ownerId -> 미션 보너스
	FlagScore = {},  -- ownerId -> 점수 (플래그 모드)
	Flags = {},      -- { Name, Position, Owner, Progress = {ownerId -> 0~1}, Model }
	Mission = nil,
	FinalSplash = false,
}

local function now()
	return workspace:GetServerTimeNow()
end

local function queueDef(id)
	for _, q in ipairs(Config.Queues) do
		if q.Id == id then
			return q
		end
	end
	return nil
end

local function ownerInfo(ownerId)
	for _, o in ipairs(S.Owners) do
		if o.OwnerId == ownerId then
			return o
		end
	end
	return nil
end

function MatchService.ColorOf(ownerId)
	local o = ownerInfo(ownerId)
	return o and o.Color or Config.NeutralColor
end

local function announce(text, color)
	remotes.Notify:FireAllClients(text, color or Color3.new(1, 1, 1))
end

------------------------------------------------------------------------
-- 미션이 쓰는 API
------------------------------------------------------------------------
local missionApi = {
	AddBonus = function(ownerId, pts)
		S.Bonus[ownerId] = (S.Bonus[ownerId] or 0) + pts
		if S.Mode == "Flag" then
			S.FlagScore[ownerId] = (S.FlagScore[ownerId] or 0) + pts * 5
		end
	end,
	RewardOwner = function(ownerId, coins)
		for _, e in ipairs(Combatants.All()) do
			if e.OwnerId == ownerId then
				e.Coins = e.Coins + coins
			end
		end
	end,
	-- 미션 성공 팀원(플레이어) 전원에게 무작위 아이템 1개
	RewardItems = function(ownerId)
		for _, e in ipairs(Combatants.All()) do
			if e.OwnerId == ownerId and e.Player and e.Player.Parent then
				QuestService.Add(e.Player, "Missions", 1)
				DataService.AddXP(e.Player, Config.XP.Mission)
				local it = ItemService.GrantRandom(e.Player)
				if it then
					remotes.Notify:FireClient(e.Player, "미션 보상: " .. it.Name .. " 획득! [F] 사용", Color3.fromRGB(255, 220, 90))
				end
			end
		end
	end,
	SetMission = function(m)
		S.Mission = m
	end,
	Announce = announce,
	Cue = function(name, owner, pos)
		remotes.FX:FireAllClients("Cue", { Name = name, Owner = owner, Pos = pos })
	end,
	OwnerName = function(ownerId)
		local o = ownerInfo(ownerId)
		return o and o.Name or "?"
	end,
	ColorOf = function(ownerId)
		return MatchService.ColorOf(ownerId)
	end,
}

------------------------------------------------------------------------
-- 점수
------------------------------------------------------------------------
local function scores()
	local coverage = PaintService.GetCoverage()
	local kills = {}
	for _, e in ipairs(Combatants.All()) do
		kills[e.OwnerId] = (kills[e.OwnerId] or 0) + e.Kills
	end
	-- 전체 합계 (몫 계산용)
	local sumCov, sumCombat = 0, 0
	for _, o in ipairs(S.Owners) do
		sumCov = sumCov + (coverage[o.OwnerId] or 0)
		sumCombat = sumCombat + (kills[o.OwnerId] or 0) + (S.Bonus[o.OwnerId] or 0) * Config.MissionKillValue
	end
	local W = Config.WinWeights
	local list = {}
	for _, o in ipairs(S.Owners) do
		local cov = coverage[o.OwnerId] or 0
		local bonus = S.Bonus[o.OwnerId] or 0
		local combat = (kills[o.OwnerId] or 0) + bonus * Config.MissionKillValue
		local score
		if S.Mode == "Flag" then
			score = S.FlagScore[o.OwnerId] or 0
		elseif S.Variant == "DM" then
			score = kills[o.OwnerId] or 0 -- 데스매치: 처치 수가 곧 점수
		else
			-- 페인트 몫 80% + 전투(처치·미션) 몫 20% → 0~100점
			local paintShare = (sumCov > 0) and (cov / sumCov) or 0
			local combatShare = (sumCombat > 0) and (combat / sumCombat) or 0
			score = 100 * (W.Paint * paintShare + W.Combat * combatShare)
		end
		table.insert(list, {
			OwnerId = o.OwnerId, Name = o.Name, Color = o.Color, Kills = kills[o.OwnerId] or 0,
			Coverage = math.floor(cov * 10 + 0.5) / 10, Bonus = bonus, Score = math.floor(score * 10 + 0.5) / 10,
		})
	end
	return list
end

local function queueCounts()
	local counts = {}
	for _, q in ipairs(Config.Queues) do
		counts[q.Id] = 0
	end
	for _, pl in ipairs(Players:GetPlayers()) do
		local q = pl:GetAttribute("Queue")
		if q and counts[q] and not pl:GetAttribute("InMatch") then
			counts[q] = counts[q] + 1
		end
	end
	return counts
end

-- 팀전 존(A=1/B=2)별 대기 인원
local function sideCounts(queueId)
	local c = { 0, 0 }
	for _, pl in ipairs(Players:GetPlayers()) do
		if pl:GetAttribute("Queue") == queueId and not pl:GetAttribute("InMatch") then
			local sd = pl:GetAttribute("QueueSide")
			if sd == 1 or sd == 2 then
				c[sd] = c[sd] + 1
			end
		end
	end
	return c
end

local function broadcast()
	local flags = {}
	for _, f in ipairs(S.Flags) do
		local best = 0
		for _, v in pairs(f.Progress) do
			best = math.max(best, v)
		end
		table.insert(flags, { Name = f.Name, Owner = f.Owner, Progress = best })
	end
	local modeDef = S.Mode and Config.Modes[S.Variant or S.Mode]
	if arena.Jumbotron then
		local text = Config.GameName
		if S.Phase == "Playing" then
			local parts = {}
			for _, t in ipairs(scores()) do
				table.insert(parts, string.format("%.0f", t.Score))
			end
			local left = math.max(0, math.floor(S.EndsAt - now()))
			text = string.format("%d:%02d\n%s", math.floor(left / 60), left % 60, table.concat(parts, "  :  "))
		elseif S.Phase == "Results" then
			text = "RESULTS"
		end
		for _, l in ipairs(arena.Jumbotron) do
			l.Text = text
		end
	end
	-- 대기열별 방장(먼저 들어온 사람)·선택 맵
	local queueInfo = {}
	local counts = queueCounts()
	for _, q in ipairs(Config.Queues) do
		local host = MatchService.QueueHost(q.Id)
		if counts[q.Id] == 0 then
			queueMap[q.Id] = nil
		end
		local choice = queueMap[q.Id]
		local mapName = "랜덤"
		if choice == "random" then
			mapName = "랜덤"
		elseif choice then
			for _, m in ipairs(maps) do
				if m.Id == choice then
					mapName = m.Name
				end
			end
		end
		local cap = (q.Mode == "Solo") and 8 or q.TeamSize * 2
		local sides = q.Mode ~= "Solo" and sideCounts(q.Id) or nil
		queueInfo[q.Id] = { Host = host and host.DisplayName or nil, HostId = host and host.UserId or nil, Map = mapName, MapId = choice,
			Capacity = cap, Full = counts[q.Id] >= cap, Sides = sides, TeamSize = q.TeamSize }
		if sides and lobby and lobby.QueuePadList then
			for _, ent in ipairs(lobby.QueuePadList) do
				if ent.Queue == q.Id and ent.Side > 0 then
					local tag = ent.Pad:FindFirstChild("ZoneTag")
					local tx = tag and tag:FindFirstChild("Text")
					local want = "ZONE " .. sides[ent.Side] .. "/" .. q.TeamSize
					if tx and tx.Text ~= want then
						tx.Text = want
					end
				end
			end
		end
		-- 로비 발판 위 안내판
		local pl = lobby and lobby.QueueLabels and lobby.QueueLabels[q.Id]
		if pl then
			local n = counts[q.Id]
			local line2 = (n > 0) and string.format('<font color="#FFE060">대기 %d명</font>', n)
				or (q.Mode == "Solo" and '<font color="#B0B0C8">발판을 밟아 참가</font>' or '<font color="#B0B0C8">같은 ZONE에 선 사람끼리 한 팀</font>')
			local txt = line2 .. (pl.Ranked and '  <font color="#FFC840">랭크</font>' or "")
			if pl.Label.Text ~= txt then
				pl.Label.Text = txt
			end
		end
	end
	-- 상단 TOP 5 (처치 → 칠한 셀 순)
	local board = {}
	if S.Phase == "Playing" or S.Phase == "Results" then
		local all = {}
		for _, e in ipairs(Combatants.All()) do
			table.insert(all, e)
		end
		table.sort(all, function(a, b)
			if a.Kills ~= b.Kills then
				return a.Kills > b.Kills
			end
			return a.Cells > b.Cells
		end)
		for i = 1, math.min(5, #all) do
			local e = all[i]
			table.insert(board, { Name = e.Name, UserId = e.Player and e.Player.UserId or nil, Kills = e.Kills, Streak = e.Streak or 0,
				Color = MatchService.ColorOf(e.OwnerId), OwnerId = e.OwnerId })
		end
	end
	local mapList = {}
	for _, m in ipairs(maps) do
		table.insert(mapList, { Id = m.Id, Name = m.Name })
	end
	remotes.State:FireAllClients({
		Phase = S.Phase,
		QueueId = S.QueueId,
		Mode = S.Mode,
		Variant = S.Variant,
		ModeName = modeDef and modeDef.Name or "",
		MapName = arena.Name,
		MapId = arena.Id,
		NextMapName = maps[nextMapIndex] and maps[nextMapIndex].Name or "",
		EndsAt = S.EndsAt,
		Teams = scores(),
		Mission = S.Mission,
		Flags = flags,
		QueueCounts = counts,
		QueueInfo = queueInfo,
		Board = board,
		Maps = mapList,
		FinalSplash = S.FinalSplash,
		OpenSlots = (function()
			if S.Phase ~= "Playing" or (S.EndsAt or 0) - now() < 30 then
				return 0
			end
			local n = 0
			for _, o in ipairs(Combatants.All()) do
				if o.IsBot then
					n = n + 1
				end
			end
			return n
		end)(),
	})
end

------------------------------------------------------------------------
-- 스폰
------------------------------------------------------------------------
-- 팀 보호구: 가슴·등 플레이트, 어깨 패드, 무릎 패드, 탄약 벨트 (ModelKit.Armor)
local function teamVest(character, color)
	local old = character:FindFirstChild("SF_Armor")
	if old then
		old:Destroy()
	end
	ModelKit.Armor(character, color)
end

-- 총(오른손) + 크루 헬멧 + 잉크 탱크 백팩 (Blender 모델, 업로드 전에는 내장 대체 모델)
-- 손에 든 총: 팔을 앞으로 든 자세(클라이언트 CharacterPose)에서 총구가 정면을 향하도록
-- 손의 -Y(손끝 방향)를 총의 앞(-Z)으로 맞춤
local GUN_GRIP = CFrame.new(0, -0.35, -0.05) * CFrame.Angles(math.rad(-90), 0, 0)
local KNIFE_GRIP = CFrame.new(0, -0.3, -0.05) * CFrame.Angles(math.rad(-90), 0, 0)
local function attachGun(e, model)
	for _, n in ipairs({ "SF_Gun", "SF_Knife" }) do
		local old = model:FindFirstChild(n)
		if old then
			old:Destroy()
		end
	end
	local color = MatchService.ColorOf(e.OwnerId)
	local hand = model:FindFirstChild("RightHand") or model:FindFirstChild("Right Arm")
	-- 칼은 항상 몸에 지님: 칼을 들면 손에, 총을 들면 오른쪽 허벅지 칼집에
	if e.Player then
		local knife = ModelKit.Knife(color, e.Player:GetAttribute("KnifeModel"), WeaponSkins.LookFor(e.Player, "Knife"))
		knife.Name = "SF_Knife"
		local thigh = model:FindFirstChild("RightUpperLeg") or model:FindFirstChild("Right Leg")
		knife:SetAttribute("InHand", e.Melee == true and hand ~= nil)
		if e.Melee and hand then
			ModelKit.WeldTo(knife, hand, KNIFE_GRIP)
		elseif thigh then
			ModelKit.WeldTo(knife, thigh, CFrame.new(thigh.Size.X / 2 + 0.06, 0.1, 0) * CFrame.Angles(math.rad(-90), 0, 0))
		else
			knife:Destroy()
		end
	end
	if hand and not e.Melee then
		local skin = e.Player and Cosmetics.ById[e.Player:GetAttribute("Skin") or ""] or nil
		local look = e.Player and WeaponSkins.LookFor(e.Player, e.WeaponId) or nil
		local gun = ModelKit.Gun(e.WeaponId, color, skin, skin and Cosmetics.MaterialOf(skin.Material) or nil, look)
		gun.Name = "SF_Gun"
		ModelKit.WeldTo(gun, hand, GUN_GRIP)
	end
end

local function attachGear(e, model)
	for _, n in ipairs({ "SF_Helmet", "SF_Backpack" }) do
		local old = model:FindFirstChild(n)
		if old then
			old:Destroy()
		end
	end
	local color = MatchService.ColorOf(e.OwnerId)
	attachGun(e, model)
	local head = model:FindFirstChild("Head")
	if head then
		-- 모자 액세서리는 헬멧과 겹치므로 경기 중에만 숨김 (머리카락은 그대로)
		for _, acc in ipairs(model:GetChildren()) do
			local handle = acc:IsA("Accessory") and acc:FindFirstChild("Handle")
			if handle and handle:FindFirstChild("HatAttachment") then
				handle.Transparency = 1
			end
		end
		local helmet = ModelKit.Helmet(color)
		helmet.Name = "SF_Helmet"
		ModelKit.WeldTo(helmet, head, CFrame.new(0, 0.1, 0))
	end
	local torso = model:FindFirstChild("UpperTorso") or model:FindFirstChild("Torso")
	if torso then
		local pack = ModelKit.Backpack(color)
		pack.Name = "SF_Backpack"
		ModelKit.WeldTo(pack, torso, CFrame.new(0, 0.05, torso.Size.Z / 2))
	end
end

-- 시작·부활 위치: 맵의 칠할 수 있는 바닥 중 무작위 (살아 있는 적과 35스터드 이상 떨어지고 머리 위가 트인 곳)
local spawnUp = RaycastParams.new()
spawnUp.FilterType = Enum.RaycastFilterType.Exclude
-- 솔로: 맵 전체에서 완전 랜덤 / 팀전(2:2·3:3·5:5): 우리 팀 진영(팀 스폰 주변) 안에서만 랜덤
local function randomSpawn(e)
	local cells = arena.Cells and arena.Cells:GetChildren() or {}
	if #cells == 0 then
		return nil
	end
	if S.Mode ~= "Solo" then
		local bases = arena.Spawns and arena.Spawns[e.TeamId]
		if not bases or #bases == 0 then
			return nil
		end
		local R = Config.TeamSpawnRadius or 22
		local mine = {}
		for _, c in ipairs(cells) do
			local p = c.Position
			for _, b in ipairs(bases) do
				local d = Vector3.new(p.X - b.Position.X, 0, p.Z - b.Position.Z).Magnitude
				if d <= R and math.abs(p.Y - b.Position.Y) < 12 then
					table.insert(mine, c)
					break
				end
			end
		end
		if #mine == 0 then
			return nil
		end
		cells = mine
	end
	local enemies = {}
	for _, o in ipairs(Combatants.All()) do
		if o ~= e and o.Alive and o.Model and o.OwnerId ~= e.OwnerId then
			local r = o.Model:FindFirstChild("HumanoidRootPart")
			if r then
				table.insert(enemies, r.Position)
			end
		end
	end
	local ignore = { arena.Cells }
	for _, o in ipairs(Combatants.All()) do
		if o.Model then
			table.insert(ignore, o.Model)
		end
	end
	spawnUp.FilterDescendantsInstances = ignore
	local best, bestD = nil, -1
	for _ = 1, 30 do
		local c = cells[math.random(1, #cells)]
		local pos = c.Position + Vector3.new(0, 3.5, 0)
		local near = math.huge
		for _, ep in ipairs(enemies) do
			near = math.min(near, (ep - pos).Magnitude)
		end
		local open = workspace:Raycast(c.Position + Vector3.new(0, 0.5, 0), Vector3.new(0, 7, 0), spawnUp) == nil
		if open then
			if near >= 35 then
				best = pos
				break
			elseif near > bestD then
				best, bestD = pos, near
			end
		end
	end
	if not best then
		return nil
	end
	local look = Vector3.new(math.random() - 0.5, 0, math.random() - 0.5)
	if S.Mode ~= "Solo" and arena.Spawns then
		-- 팀전: 상대 진영 쪽을 바라보며 등장
		for tid, list in pairs(arena.Spawns) do
			if tid ~= e.TeamId and list[1] then
				local c = list[1].Position
				look = Vector3.new(c.X - best.X, 0, c.Z - best.Z)
				break
			end
		end
	end
	if look.Magnitude < 0.1 then
		look = Vector3.new(0, 0, -1)
	end
	return CFrame.lookAt(best, best + look.Unit)
end

local function spawnCFrame(e)
	local cf = randomSpawn(e)
	if cf then
		return cf
	end
	if S.Mode == "Solo" then
		return arena.SoloSpawns[((e.OwnerId - 1) % #arena.SoloSpawns) + 1]
	end
	local list = arena.Spawns[e.TeamId]
	return list[math.random(1, #list)]
end

local onDied

local function activate(e, model)
	Combatants.SetModel(e, model)
	e.Alive = true
	e.Ink = Config.InkMax
	e.ProtectedUntil = os.clock() + Config.SpawnProtection
	e.SpawnedAt = os.clock()
	local hum = model:FindFirstChildOfClass("Humanoid")
	hum.MaxHealth = Config.MaxHealth
	hum.Health = Config.MaxHealth
	hum.BreakJointsOnDeath = false
	local ff = Instance.new("ForceField")
	ff.Visible = true
	ff.Parent = model
	task.delay(Config.SpawnProtection, function()
		if ff.Parent then
			ff:Destroy()
		end
	end)
	teamVest(model, MatchService.ColorOf(e.OwnerId))
	-- 부활하면 항상 총을 든 상태로 시작
	e.Melee = false
	if e.Player then
		e.Player:SetAttribute("Melee", false)
	end
	local okGear, gearErr = pcall(attachGear, e, model)
	if not okGear then
		warn("[SplashFront] 장비 부착 실패:", gearErr)
	end
	ItemService.OnSpawn(e)
	-- 기획서 4장: 적 색 위에 서 있으면 발밑에서 페인트가 튀어 위치가 드러남
	local root = model:FindFirstChild("HumanoidRootPart")
	if root then
		local att = Instance.new("Attachment")
		att.Name = "FeetAttachment"
		att.Position = Vector3.new(0, -2.8, 0)
		att.Parent = root
		local pe = Instance.new("ParticleEmitter")
		pe.Name = "EnemyInkReveal"
		pe.Enabled = false
		pe.Rate = 18
		pe.Lifetime = NumberRange.new(0.4, 0.7)
		pe.Speed = NumberRange.new(4, 8)
		pe.SpreadAngle = Vector2.new(60, 60)
		pe.Acceleration = Vector3.new(0, -30, 0)
		pe.Size = NumberSequence.new(0.35, 0.05)
		pe.LightEmission = 0.4
		pe.Parent = att
	end
	hum.Died:Connect(function()
		onDied(e, model)
	end)
	Combatants.Sync(e)
end

local function spawnEntity(e)
	if S.Phase ~= "Playing" then
		return
	end
	local cf = spawnCFrame(e)
	if e.IsBot then
		local model = BotService.CreateModel(e, cf, MatchService.ColorOf(e.OwnerId))
		activate(e, model)
	else
		local player = e.Player
		if not player or not player.Parent then
			return
		end
		player:LoadCharacter()
		local character = player.Character
		if not character then
			return
		end
		local root = character:WaitForChild("HumanoidRootPart", 5)
		if root then
			character:PivotTo(cf)
		end
		activate(e, character)
	end
end

onDied = function(e, model)
	if not e.Alive or e.Model ~= model then
		return
	end
	e.Alive = false
	e.Deaths = e.Deaths + 1
	e.Streak = 0
	local killer = e.LastAttacker
	local root = model:FindFirstChild("HumanoidRootPart")
	if killer and killer ~= e then
		killer.Kills = killer.Kills + 1
		if S.Variant == "DM" then
			-- 데스매치: 처치 1번 = 크로마 봄 게이지 20%
			killer.Special = math.min(Config.SpecialCells, killer.Special + Config.SpecialCells * (Config.DMKillSpecial or 0.2))
			Combatants.Sync(killer)
		end
		killer.Streak = (killer.Streak or 0) + 1
		local t = os.clock()
		if t - (killer.LastKillAt or -99) <= Config.MultiKillWindow then
			killer.Multi = (killer.Multi or 1) + 1
		else
			killer.Multi = 1
		end
		killer.LastKillAt = t
		if killer.Player then
			local head = e.LastHeadshot == true
			local coins = Config.Rewards.Kill + (head and Config.Rewards.Headshot or 0)
			local xp = Config.XP.Kill + (head and Config.XP.Headshot or 0)
			DataService.AddXP(killer.Player, xp)
			QuestService.Add(killer.Player, "Kills", 1)
			if head then
				QuestService.Add(killer.Player, "Headshots", 1)
			end
			remotes.FX:FireClient(killer.Player, "Elim", {
				Victim = e.Name, VictimColor = MatchService.ColorOf(e.OwnerId), Head = head, Multi = killer.Multi,
				Streak = killer.Streak, Coins = coins, XP = xp,
			})
		end
		Combatants.Killed:Fire(killer, e, e.LastHeadshot)
		if root then
			PaintService.PaintBelow(root.Position, 6, killer.OwnerId, killer)
		end
	end
	remotes.FX:FireAllClients("Kill", {
		Killer = killer and killer.Name or nil,
		KillerColor = killer and MatchService.ColorOf(killer.OwnerId) or nil,
		Victim = e.Name,
		VictimColor = MatchService.ColorOf(e.OwnerId),
		Head = e.LastHeadshot,
		Effect = killer and ((killer.Player and (WeaponSkins.LookFor(killer.Player, killer.Melee and "Knife" or killer.WeaponId) or {}).Finisher) or killer.KillEffect) or nil,
		Weapon = killer and (killer.Melee and Weapons.Knife.Name or Weapons.Get(killer.WeaponId).Name) or nil,
		WeaponId = killer and (killer.Melee and "Knife" or killer.WeaponId) or nil,
		KillerStreak = killer and killer.Streak or 0,
		WeaponClass = killer and (killer.Melee and Weapons.Knife.Class or Weapons.Get(killer.WeaponId).Class) or nil,
		Pos = root and root.Position or nil,
		KillerPlayer = killer and killer.Player or nil,
		VictimPlayer = e.Player,
	})
	e.LastAttacker = nil
	e.LastHeadshot = false
	task.delay(Config.RespawnTime, function()
		if S.Phase == "Playing" and Combatants.FromModel(model) == e then
			if e.IsBot and model.Parent then
				model:Destroy()
			end
			spawnEntity(e)
		end
	end)
end

------------------------------------------------------------------------
-- 깃발 (플래그 러시)
------------------------------------------------------------------------
-- 깃발 위치를 매 경기 무작위로: 칠할 수 있는 바닥 칸 중에서 서로 최대한 멀리 떨어지게 고름
-- (양 팀 스폰과 너무 가까운 곳 제외, 두 팀에서의 거리가 비슷하도록 여러 번 뽑아 가장 좋은 배치 선택)
local function pickFlagPositions(count)
	local cells = arena.Cells and arena.Cells:GetChildren() or {}
	local spawnsA = arena.Spawns and arena.Spawns[1] or {}
	local spawnsB = arena.Spawns and arena.Spawns[2] or {}
	if #cells < 20 or #spawnsA == 0 or #spawnsB == 0 then
		return nil
	end
	local function center(list)
		local sum = Vector3.zero
		for _, cf in ipairs(list) do
			sum = sum + cf.Position
		end
		return sum / #list
	end
	local baseA, baseB = center(spawnsA), center(spawnsB)
	local function flat(v)
		return Vector3.new(v.X, 0, v.Z)
	end
	local span = (flat(baseA) - flat(baseB)).Magnitude
	-- 높이: 대부분의 칸이 있는 높이 근처만 (외딴 지붕 등 못 가는 곳 제외)
	local ys = {}
	for _, c in ipairs(cells) do
		table.insert(ys, c.Position.Y)
	end
	table.sort(ys)
	local midY = ys[math.floor(#ys / 2) + 1]
	local keep = math.max(18, span * 0.12) -- 스폰 중심과 이 거리 이상 떨어진 곳만
	-- 리스폰 지역 제외: 모든 스폰 지점에서 (팀 리스폰 반경 + 여유) 안쪽은 깃발 후보에서 뺌
	local respawnR = (Config.TeamSpawnRadius or 22) + 16
	local allSpawns = {}
	for _, list in pairs(arena.Spawns or {}) do
		for _, cf in ipairs(list) do
			table.insert(allSpawns, flat(cf.Position))
		end
	end
	local function nearSpawn(pos)
		local fp = flat(pos)
		for _, sp in ipairs(allSpawns) do
			if (fp - sp).Magnitude < respawnR then
				return true
			end
		end
		return false
	end
	local cands = {}
	for _, c in ipairs(cells) do
		local pos = c.Position
		if math.abs(pos.Y - midY) <= 14 and (flat(pos) - flat(baseA)).Magnitude > keep and (flat(pos) - flat(baseB)).Magnitude > keep
			and not nearSpawn(pos) then
			table.insert(cands, c)
		end
	end
	if #cands < count * 4 then
		return nil
	end
	-- 깃대(12칸)가 천장·지붕에 걸리지 않는 열린 곳만
	local skyParams = RaycastParams.new()
	skyParams.FilterType = Enum.RaycastFilterType.Exclude
	skyParams.FilterDescendantsInstances = { arena.Cells, workspace:FindFirstChild("FX") }
	local skyCache = {}
	local function openSky(c)
		local v = skyCache[c]
		if v == nil then
			v = workspace:Raycast(c.Position + Vector3.new(0, 1, 0), Vector3.new(0, 16, 0), skyParams) == nil
			skyCache[c] = v
		end
		return v
	end
	local rng = Random.new()
	local best, bestScore = nil, -math.huge
	for _ = 1, 24 do
		local first = cands[rng:NextInteger(1, #cands)]
		for _ = 1, 20 do
			if openSky(first) then
				break
			end
			first = cands[rng:NextInteger(1, #cands)]
		end
		local chosen = { first }
		while #chosen < count do
			-- 지금까지 고른 깃발들과의 최소 거리가 큰 후보들 중 상위에서 무작위
			local scored = {}
			for i = 1, math.min(#cands, 400) do
				local c = cands[rng:NextInteger(1, #cands)]
				local md = openSky(c) and math.huge or -1
				if md > 0 then
					for _, o in ipairs(chosen) do
						md = math.min(md, (flat(c.Position) - flat(o.Position)).Magnitude)
					end
				end
				scored[i] = { c, md }
			end
			table.sort(scored, function(a, b)
				return a[2] > b[2]
			end)
			table.insert(chosen, scored[rng:NextInteger(1, math.max(1, math.floor(#scored * 0.08)))][1])
		end
		local minPair, da, db = math.huge, 0, 0
		for i, c in ipairs(chosen) do
			da = da + (flat(c.Position) - flat(baseA)).Magnitude
			db = db + (flat(c.Position) - flat(baseB)).Magnitude
			for j = i + 1, #chosen do
				minPair = math.min(minPair, (flat(c.Position) - flat(chosen[j].Position)).Magnitude)
			end
		end
		local score = minPair - math.abs(da - db) * 0.6
		if score > bestScore then
			best, bestScore = chosen, score
		end
	end
	if not best then
		return nil
	end
	-- 이름은 A(팀1 쪽) → C(가운데) → B(팀2 쪽) 순으로
	local axis = flat(baseB - baseA).Unit
	table.sort(best, function(a, b)
		return (a.Position - baseA):Dot(axis) < (b.Position - baseA):Dot(axis)
	end)
	local out = {}
	for i, c in ipairs(best) do
		out[i] = c.Position + Vector3.new(0, c.Size.Y / 2, 0)
	end
	return out
end

local function buildFlags()
	local fx = workspace:FindFirstChild("FX")
	local picked = pickFlagPositions(#arena.FlagPoints)
	local names = {}
	for _, def in ipairs(arena.FlagPoints) do
		table.insert(names, def.Name)
	end
	-- 원래 정의 순서(A, C, B)를 축 순서(팀1 → 팀2)에 맞게: A, C, B
	local axisNames = { "A", "C", "B" }
	for i, def0 in ipairs(arena.FlagPoints) do
		local def = def0
		if picked and picked[i] then
			def = { Name = (#arena.FlagPoints == 3) and axisNames[i] or names[i], Position = picked[i] }
		end
		local model = Instance.new("Model")
		model.Name = "Flag_" .. def.Name
		local base = Instance.new("Part")
		base.Name = "Base"
		base.Shape = Enum.PartType.Cylinder
		base.Anchored = true
		base.CanCollide = false
		base.Material = Enum.Material.Neon
		base.Color = Color3.fromRGB(255, 255, 255)
		base.Transparency = 0.5
		base.Size = Vector3.new(0.3, Config.Flag.Radius * 2, Config.Flag.Radius * 2)
		base.CFrame = CFrame.new(def.Position + Vector3.new(0, 0.3, 0)) * CFrame.Angles(0, 0, math.rad(90))
		base.Parent = model
		local pole = Instance.new("Part")
		pole.Name = "Pole"
		pole.Anchored = true
		pole.Size = Vector3.new(0.5, 12, 0.5)
		pole.Position = def.Position + Vector3.new(0, 6, 0)
		pole.Color = Color3.fromRGB(230, 230, 230)
		pole.Material = Enum.Material.Metal
		pole.Parent = model
		local cloth = Instance.new("Part")
		cloth.Name = "Cloth"
		cloth.Anchored = true
		cloth.CanCollide = false
		cloth.Size = Vector3.new(0.2, 3, 5)
		cloth.Position = def.Position + Vector3.new(0, 10.5, 2.6)
		cloth.Color = Config.NeutralColor
		cloth.Material = Enum.Material.Fabric
		cloth.Parent = model
		local bb = Instance.new("BillboardGui")
		bb.Size = UDim2.fromOffset(120, 50)
		bb.StudsOffset = Vector3.new(0, 14, 0)
		bb.AlwaysOnTop = true
		bb.Adornee = pole
		bb.Parent = model
		local t = Instance.new("TextLabel")
		t.Name = "Label"
		t.Size = UDim2.fromScale(1, 1)
		t.BackgroundTransparency = 1
		t.TextColor3 = Color3.new(1, 1, 1)
		t.TextStrokeTransparency = 0.2
		t.Font = Enum.Font.GothamBlack
		t.TextScaled = true
		t.Text = "깃발 " .. def.Name
		t.Parent = bb
		model.Parent = fx
		table.insert(S.Flags, { Name = def.Name, Position = def.Position, Owner = 0, Progress = {}, Model = model })
	end
end

local function flagTick(dt)
	for _, f in ipairs(S.Flags) do
		local present = {}
		local nPresent = 0
		for _, e in ipairs(Combatants.All()) do
			if e.Alive and e.Model then
				local r = e.Model:FindFirstChild("HumanoidRootPart")
				if r then
					local d = r.Position - f.Position
					if Vector3.new(d.X, 0, d.Z).Magnitude <= Config.Flag.Radius and math.abs(d.Y) < 7 then
						if not present[e.TeamId] then
							present[e.TeamId] = true
							nPresent = nPresent + 1
						end
					end
				end
			end
		end
		if nPresent == 1 then
			local team = next(present)
			if team ~= f.Owner then
				local ground = PaintService.OwnerBelow(f.Position + Vector3.new(0, 2, 0))
				local t = Config.Flag.PlantTime
				if ground ~= 0 and ground ~= team then
					t = Config.Flag.PlantTimeEnemyGround
				end
				f.Progress[team] = (f.Progress[team] or 0) + dt / t
				if f.Progress[team] >= 1 then
					f.Owner = team
					f.Progress = {}
					local color = MatchService.ColorOf(team)
					f.Model.Cloth.Color = color
					f.Model.Base.Color = color
					PaintService.PaintAt(f.Position + Vector3.new(0, 1, 0), Config.Flag.Radius, team, nil)
					announce(string.format("%s 팀이 깃발 %s를 꽂았다!", missionApi.OwnerName(team), f.Name), color)
					remotes.FX:FireAllClients("Cue", { Name = "flag", Owner = team })
				end
			end
		elseif nPresent == 0 then
			for k, v in pairs(f.Progress) do
				f.Progress[k] = math.max(0, v - dt * 0.25)
			end
		end
	end
end

------------------------------------------------------------------------
-- 경기 시작 / 종료
------------------------------------------------------------------------
-- 색상환에서 충분히 떨어진 두 팀 색을 무작위로 고름
local function pickTeams()
	local pal = Config.TeamPalette or Config.Teams
	for _ = 1, 60 do
		local a = pal[math.random(1, #pal)]
		local b = pal[math.random(1, #pal)]
		if a ~= b then
			local h1 = a.Color:ToHSV()
			local h2 = b.Color:ToHSV()
			local d = math.abs(h1 - h2)
			d = math.min(d, 1 - d)
			if d >= (Config.TeamMinHueGap or 0.2) then
				return { { Id = 1, Name = a.Name, Color = a.Color }, { Id = 2, Name = b.Name, Color = b.Color } }
			end
		end
	end
	return Config.Teams
end

local function mapIndexFor(q)
	local choice = queueMap[q.Id]
	queueMap[q.Id] = nil
	if choice == "random" then
		return math.random(1, #maps), false
	end
	for i, m in ipairs(maps) do
		if m.Id == choice then
			return i, false
		end
	end
	-- 방장이 고르지 않으면 랜덤 (관리자가 다음 맵을 지정했으면 그 맵)
	if forcedNextMap then
		forcedNextMap = false
		return nextMapIndex, false
	end
	return math.random(1, #maps), false
end

local function startMatch(q)
	local mode = q.Mode
	local capacity = (mode == "Solo") and 8 or q.TeamSize * 2

	-- 참가자 선정
	local humans = {}
	for _, pl in ipairs(Players:GetPlayers()) do
		if pl:GetAttribute("Queue") == q.Id and not pl:GetAttribute("InMatch") and #humans < capacity then
			table.insert(humans, pl)
		end
	end
	if #humans == 0 then
		return false
	end

	Combatants.Clear()
	local mapIndex, rotate = mapIndexFor(q)
	MatchService.ApplyMap(maps[mapIndex])
	if rotate then
		nextMapIndex = nextMapIndex % #maps + 1
	end
	PaintService.SetRadiusMultiplier(1)
	S.QueueId = q.Id
	S.Mode = mode
	S.Variant = q.Variant
	PaintService.SetEnabled(q.Variant ~= "DM")
	S.Bonus = {}
	S.FlagScore = {}
	S.Flags = {}
	S.Mission = nil
	S.FinalSplash = false
	S.Owners = {}
	S.HasBots = false
	local fx = workspace:FindFirstChild("FX")
	if fx then
		fx:ClearAllChildren()
	end

	local slots = {}
	if mode == "Solo" then
		for i = 1, capacity do
			table.insert(S.Owners, { OwnerId = i, Name = "", Color = Config.SoloColors[i] })
			slots[i] = { OwnerId = i, TeamId = i }
		end
	else
		local teams = pickTeams()
		for _, t in ipairs(teams) do
			table.insert(S.Owners, { OwnerId = t.Id, Name = t.Name, Color = t.Color })
		end
		-- 경기장 팀 배너를 이번 판 색·이름으로
		for i, b in pairs(arena.TeamBanners or {}) do
			local t = teams[i]
			if t then
				if b.Part then
					b.Part.Color = t.Color
				else
					b.Label.TextColor3 = t.Color
				end
				b.Label.Text = t.Name
			end
		end
		-- 로비에서 선 존(A=1팀, B=2팀) 그대로 팀 구성. 존 정보가 없으면 인원이 적은 쪽으로 → 남는 자리는 봇
		local per = { 0, 0 }
		for i, pl in ipairs(humans) do
			local team = pl:GetAttribute("QueueSide")
			if team ~= 1 and team ~= 2 or per[team] >= q.TeamSize then
				team = (per[1] <= per[2]) and 1 or 2
			end
			per[team] = per[team] + 1
			slots[i] = { OwnerId = team, TeamId = team }
		end
		local i = #humans
		for team = 1, 2 do
			while per[team] < q.TeamSize do
				per[team] = per[team] + 1
				i = i + 1
				slots[i] = { OwnerId = team, TeamId = team }
			end
		end
	end
	local palette = {}
	for _, o in ipairs(S.Owners) do
		palette[o.OwnerId] = o.Color
	end
	PaintService.SetPalette(palette)
	CombatService.SetColorResolver(MatchService.ColorOf)

	local entities = {}
	for i, pl in ipairs(humans) do
		local profile = DataService.Get(pl)
		local e = Combatants.New({
			Id = "P" .. pl.UserId, Name = pl.DisplayName, Player = pl,
			OwnerId = slots[i].OwnerId, TeamId = slots[i].TeamId,
			WeaponId = profile and profile.Equipped or Weapons.Default,
		})
		e.PatternMaterial = Cosmetics.PaintStyle(profile and profile.EquippedPattern)
		-- 처치 이펙트: 아이템 Id가 아니라 연출 종류(Effect)를 넘겨야 클라이언트가 재생함
		local fx = profile and Cosmetics.ById[profile.EquippedEffect or ""]
		e.KillEffect = fx and fx.Effect or nil
		local played = pl:GetAttribute("SessionMatches") or 0
		Telemetry.Funnel(pl, played == 0 and "MatchStarted" or "SecondMatch")
		pl:SetAttribute("SessionMatches", played + 1)
		pl:SetAttribute("InMatch", true)
		pl:SetAttribute("OwnerId", e.OwnerId)
		pl:SetAttribute("TeamId", e.TeamId)
		pl:SetAttribute("TeamColor", MatchService.ColorOf(e.OwnerId))
		pl:SetAttribute("Weapon", e.WeaponId)
		table.insert(entities, e)
		if mode == "Solo" then
			S.Owners[i].Name = pl.DisplayName
		end
	end
	local filled = #humans
	if Config.FillWithBots then
		for i = filled + 1, capacity do
			local e = Combatants.New({
				Id = "B" .. i, Name = BotService.NextName(), IsBot = true,
				OwnerId = slots[i].OwnerId, TeamId = slots[i].TeamId, WeaponId = BotService.RandomWeapon(),
			})
			S.HasBots = true
			table.insert(entities, e)
			if mode == "Solo" then
				S.Owners[i].Name = e.Name
			end
		end
	end
	if mode == "Solo" then
		-- 빈 슬롯(봇 미사용 시)은 점수판에서 제외
		local used = {}
		for _, e in ipairs(entities) do
			used[e.OwnerId] = true
		end
		local trimmed = {}
		for _, o in ipairs(S.Owners) do
			if used[o.OwnerId] then
				table.insert(trimmed, o)
			end
		end
		S.Owners = trimmed
	end

	if mode == "Flag" then
		buildFlags()
	end

	S.Phase = "Playing"
	S.StartedAt = now()
	S.EndsAt = now() + Config.MatchLength
	CombatService.SetActive(true)
	for _, e in ipairs(entities) do
		task.spawn(spawnEntity, e)
	end
	BotService.Start()
	if S.Variant ~= "DM" then
		MissionService.Start() -- 데스매치는 미션 없이 순수 전투
	end
	for _, pl in ipairs(humans) do
		remotes.FX:FireClient(pl, "Cue", { Name = "countdown_go" })
	end
	local md = Config.Modes[S.Variant or mode]
	announce(md.Name .. " 시작! " .. md.Desc, Color3.fromRGB(255, 255, 255))
	return true
end

local function endMatch()
	S.Phase = "Results"
	CombatService.SetActive(false)
	MissionService.Stop()
	local final = scores()
	table.sort(final, function(a, b)
		return a.Score > b.Score
	end)
	local winner = nil
	if #final >= 2 and final[1].Score > final[2].Score then
		winner = final[1].OwnerId
	elseif #final == 1 then
		winner = final[1].OwnerId
	end

	local q = queueDef(S.QueueId)
	local ranked = q and q.Ranked and (not S.HasBots or Config.RankedAllowBots)

	-- 팀 내 기여 순위
	local all = Combatants.All()
	local byOwner = {}
	for _, e in ipairs(all) do
		byOwner[e.OwnerId] = byOwner[e.OwnerId] or {}
		table.insert(byOwner[e.OwnerId], e)
	end
	local perf = {}
	for _, list in pairs(byOwner) do
		table.sort(list, function(a, b)
			return (a.Cells + a.Kills * 30) > (b.Cells + b.Kills * 30)
		end)
		for i, e in ipairs(list) do
			perf[e] = (#list > 1) and (1 - (i - 1) / (#list - 1)) or 1
		end
	end

	local rows = {}
	local statRows = {}
	local seconds = math.max(1, now() - (S.StartedAt or now()))
	for _, e in ipairs(all) do
		local won = (winner ~= nil and e.OwnerId == winner)
		local coins = (won and Config.Rewards.Win or Config.Rewards.Lose)
			+ e.Kills * Config.Rewards.Kill
			+ math.floor(e.Cells / 100) * Config.Rewards.Per100Cells
			+ (e.Headshots or 0) * Config.Rewards.Headshot
			+ e.Coins
		local ratingDelta = nil
		if e.Player and e.Player.Parent then
			coins = DataService.AddCoins(e.Player, coins)
			local p = DataService.Get(e.Player)
			if p then
				p.Matches = p.Matches + 1
				p.Kills = p.Kills + e.Kills
				p.Cells = p.Cells + e.Cells
				if won then
					p.Wins = p.Wins + 1
				end
			end
			if ranked then
				ratingDelta = RankService.Apply(e.Player, won, perf[e])
			end
			RankService.RecordMeta(e.Player)
			DataService.AddXP(e.Player, (won and Config.XP.Win or Config.XP.Lose) + math.floor(e.Cells / Config.XP.PerCells))
			QuestService.Add(e.Player, "Matches", 1)
			QuestService.Add(e.Player, "Cells", e.Cells)
			if won then
				QuestService.Add(e.Player, "Wins", 1)
			end
			Telemetry.Funnel(e.Player, "MatchFinished")
			Telemetry.Economy(e.Player, true, coins, p and p.Coins or 0, "Gameplay", "MatchReward")
			Telemetry.Custom(e.Player, "MatchEnd", e.Cells, S.Mode .. "/" .. tostring(S.QueueId), e.WeaponId, won and "win" or "lose")
			e.Player:SetAttribute("FirstMatch", false)
			table.insert(statRows, {
				WeaponId = e.WeaponId, Won = won, Kills = e.Kills, Deaths = e.Deaths, Shots = e.Shots or 0,
				Hits = e.Hits or 0, Headshots = e.Headshots or 0, Cells = e.Cells, Seconds = seconds,
			})
			DataService.Publish(e.Player)
		end
		table.insert(rows, {
			Name = e.Name, IsBot = e.IsBot, Player = e.Player, OwnerId = e.OwnerId,
			Score = e.Cells + e.Kills * 30, Weapon = Weapons.Get(e.WeaponId).Name,
			Color = MatchService.ColorOf(e.OwnerId), Kills = e.Kills, Deaths = e.Deaths,
			Cells = e.Cells, Coins = e.IsBot and 0 or coins, RatingDelta = ratingDelta, Won = won,
		})
	end
	table.sort(rows, function(a, b)
		return (a.Cells + a.Kills * 30) > (b.Cells + b.Kills * 30)
	end)
	Telemetry.RecordMatch(statRows)

	-- MVP(전체 최고 점수) 횟수 누적 · 랭킹 보드에 표시
	local top = rows[1]
	if top and top.Player and top.Player.Parent then
		local tp = DataService.Get(top.Player)
		if tp then
			tp.MVPs = (tp.MVPs or 0) + 1
			DataService.Publish(top.Player)
			RankService.RecordMeta(top.Player)
		end
	end
	local winnerInfo = winner and ownerInfo(winner)
	pcall(function()
		local mvp = rows[1]
		RankService.NoteMatch({ Map = arena.Name or "?", Mode = tostring(S.QueueId or S.Mode), Winner = winnerInfo and winnerInfo.Name or nil,
			MVP = mvp and mvp.Name or nil, Kills = mvp and mvp.Kills or 0, Cells = mvp and mvp.Cells or 0 })
	end)
	remotes.Results:FireAllClients({
		Mode = S.Mode,
		Variant = S.Variant,
		Teams = final,
		WinnerName = winnerInfo and winnerInfo.Name or nil,
		WinnerColor = winnerInfo and winnerInfo.Color or nil,
		Rows = rows,
		Ranked = ranked,
	})
	broadcast()
	task.wait(Config.ResultsTime)
	if Router.IsMatchServer then
		-- 경기 서버: 결과를 본 뒤 바로 전환 화면 → 로비 서버로 (이 서버의 로비는 보이지 않게)
		for _, pl in ipairs(Players:GetPlayers()) do
			pl:SetAttribute("Teleporting", true)
		end
		task.wait(0.4)
	end

	-- 정리 후 로비로
	BotService.Stop()
	local fx = workspace:FindFirstChild("FX")
	if fx then
		fx:ClearAllChildren()
	end
	S.Flags = {}
	for _, e in ipairs(all) do
		if e.Player and e.Player.Parent then
			e.Player:SetAttribute("InMatch", false)
			e.Player:SetAttribute("Queue", nil)
			e.Player:SetAttribute("QueueSide", nil)
			e.Player:SetAttribute("OwnerId", nil)
			e.Player:SetAttribute("TeamColor", nil)
			e.Player:SetAttribute("SpawnZone", false)
			ItemService.Clear(e.Player)
			e.Player:LoadCharacter()
			DataService.Save(e.Player)
		end
	end
	Combatants.Clear()
	MapBuilder.ApplyLighting("Lobby") -- 로비로 돌아오면 격납고 조명
	S.Phase = "Lobby"
	S.Mode = nil
	S.Variant = nil
	PaintService.SetEnabled(true)
	S.QueueId = nil
	S.Mission = nil
	S.Owners = {}
	broadcast()
end

------------------------------------------------------------------------
-- 루프
------------------------------------------------------------------------
local function pickQueue()
	local counts = queueCounts()
	local best, bestN = nil, 0
	for _, q in ipairs(Config.Queues) do
		if counts[q.Id] > bestN then
			best, bestN = q, counts[q.Id]
		end
	end
	return best
end

-- 대기열의 방장 = 가장 먼저 들어온 사람
function MatchService.QueueHost(queueId)
	local best, bestT = nil, math.huge
	for _, pl in ipairs(Players:GetPlayers()) do
		if pl:GetAttribute("Queue") == queueId and not pl:GetAttribute("InMatch") then
			local t = pl:GetAttribute("QueueTime") or 0
			if t < bestT then
				best, bestT = pl, t
			end
		end
	end
	return best
end

-- 큐 + 존에 해당하는 발판 (솔로는 side 0)
local function padOf(queueId, side)
	for _, ent in ipairs(lobby and lobby.QueuePadList or {}) do
		if ent.Queue == queueId and ent.Side == (side or 0) then
			return ent.Pad
		end
	end
	return nil
end

local function setQueue(player, queueId, viaPad, side)
	if player:GetAttribute("InMatch") or player:GetAttribute("Teleporting") then
		return
	end
	local q = queueId ~= nil and queueDef(queueId)
	if queueId ~= nil and not q then
		return
	end
	if q and q.Mode ~= "Solo" then
		local c = sideCounts(queueId)
		if player:GetAttribute("Queue") == queueId then
			local cur = player:GetAttribute("QueueSide")
			if cur == 1 or cur == 2 then
				c[cur] = c[cur] - 1
			end
		end
		if side ~= 1 and side ~= 2 then
			side = (c[1] <= c[2]) and 1 or 2
		end
		if c[side] >= q.TeamSize then
			local other = 3 - side
			if viaPad or c[other] >= q.TeamSize then
				remotes.Notify:FireClient(player, (side == 1 and "블루" or "오렌지") .. " ZONE이 꽉 찼어요" .. (c[other] < q.TeamSize and " · 옆 ZONE에 서 주세요" or ""),
					Color3.fromRGB(255, 180, 120))
				return
			end
			side = other
		end
	else
		side = nil
	end
	if player:GetAttribute("Queue") == queueId and player:GetAttribute("QueueSide") == side then
		return
	end
	player:SetAttribute("Queue", queueId)
	player:SetAttribute("QueueSide", side)
	if queueId then
		player:SetAttribute("QueueTime", os.clock())
		joinAt[player] = os.clock()
		Telemetry.Funnel(player, "Queued")
		-- UI로 참가하면 해당 발판 위로 이동 (발판을 벗어나면 취소되는 규칙과 맞춤)
		local pad = padOf(queueId, side)
		local char = player.Character
		if not viaPad and pad and char and char:FindFirstChild("HumanoidRootPart") then
			local a = math.random() * math.pi * 2
			char:PivotTo(CFrame.new(pad.Position + Vector3.new(math.cos(a) * 2, 3.5, math.sin(a) * 2)))
		end
	else
		player:SetAttribute("QueueTime", nil)
		player:SetAttribute("QueueSide", nil)
		joinAt[player] = nil
	end
end

-- 진행 중인 경기의 빈자리(봇 자리)에 바로 들어가기. 성공하면 true
function MatchService.JoinInProgress(player)
	if S.Phase ~= "Playing" or player:GetAttribute("InMatch") or not player.Parent then
		return false
	end
	if (S.EndsAt or 0) - now() < 30 then
		return false -- 끝나기 직전에는 들어가지 않음
	end
	-- 1) 빈자리(나간 사람 자리 등 정원보다 적은 팀) → 2) 사람이 적은 팀의 봇 자리
	local q = queueDef(S.QueueId)
	local cap = (S.Mode == "Solo") and 1 or ((q and q.TeamSize) or 3)
	local total, humansOn = {}, {}
	for _, o in ipairs(Combatants.All()) do
		total[o.OwnerId] = (total[o.OwnerId] or 0) + 1
		if not o.IsBot then
			humansOn[o.OwnerId] = (humansOn[o.OwnerId] or 0) + 1
		end
	end
	local slotOwner, slotTeam, slotName = nil, nil, nil
	for _, o in ipairs(S.Owners) do
		local n = total[o.OwnerId] or 0
		if n < cap and (slotOwner == nil or n < (total[slotOwner] or 0)) then
			slotOwner = o.OwnerId
		end
	end
	if not slotOwner and S.Mode == "Solo" and #S.Owners < 8 then
		-- 솔로: 쓰지 않은 색 자리를 새로 열어 줌
		local usedId = {}
		for _, o in ipairs(S.Owners) do
			usedId[o.OwnerId] = true
		end
		for i = 1, 8 do
			if not usedId[i] then
				table.insert(S.Owners, { OwnerId = i, Name = player.DisplayName, Color = Config.SoloColors[i] })
				local palette = {}
				for _, o in ipairs(S.Owners) do
					palette[o.OwnerId] = o.Color
				end
				PaintService.SetPalette(palette)
				slotOwner = i
				break
			end
		end
	end
	if slotOwner then
		slotTeam = slotOwner
		slotName = "빈자리"
	else
		local bot = nil
		for _, o in ipairs(Combatants.All()) do
			if o.IsBot and (not bot or (humansOn[o.OwnerId] or 0) < (humansOn[bot.OwnerId] or 0)) then
				bot = o
			end
		end
		if not bot then
			return false -- 빈자리 없음
		end
		-- 봇 내보내기
		bot.Alive = false
		Combatants.Remove(bot)
		pcall(function()
			if bot.Model then
				bot.Model:Destroy()
			end
		end)
		slotOwner, slotTeam, slotName = bot.OwnerId, bot.TeamId, bot.Name .. " 자리"
	end
	local profile = DataService.Get(player)
	local e = Combatants.New({
		Id = "P" .. player.UserId, Name = player.DisplayName, Player = player,
		OwnerId = slotOwner, TeamId = slotTeam,
		WeaponId = profile and profile.Equipped or Weapons.Default,
	})
	e.PatternMaterial = Cosmetics.PaintStyle(profile and profile.EquippedPattern)
	local fx = profile and Cosmetics.ById[profile.EquippedEffect or ""]
	e.KillEffect = fx and fx.Effect or nil
	if S.Mode == "Solo" then
		for _, o in ipairs(S.Owners) do
			if o.OwnerId == e.OwnerId then
				o.Name = player.DisplayName
			end
		end
	end
	local played = player:GetAttribute("SessionMatches") or 0
	player:SetAttribute("SessionMatches", played + 1)
	player:SetAttribute("Queue", S.QueueId)
	player:SetAttribute("QueueSide", nil)
	player:SetAttribute("InMatch", true)
	player:SetAttribute("OwnerId", e.OwnerId)
	player:SetAttribute("TeamId", e.TeamId)
	player:SetAttribute("TeamColor", MatchService.ColorOf(e.OwnerId))
	player:SetAttribute("Weapon", e.WeaponId)
	Telemetry.Funnel(player, "MatchStarted")
	task.spawn(spawnEntity, e)
	remotes.FX:FireClient(player, "Cue", { Name = "countdown_go" })
	remotes.Notify:FireClient(player, "진행 중인 배틀에 합류했어요! (" .. slotName .. ")", Color3.fromRGB(140, 255, 200))
	announce(player.DisplayName .. " 님이 배틀에 합류했어요", Color3.fromRGB(200, 230, 255))
	return true
end

-- 진행 중인 경기에서 더 들어올 수 있는 자리 수 (빈자리 + 봇 자리)
local function openSlots()
	if S.Phase ~= "Playing" then
		return 0
	end
	local q = queueDef(S.QueueId)
	local cap = (S.Mode == "Solo") and 1 or ((q and q.TeamSize) or 3)
	local total, bots = {}, 0
	for _, o in ipairs(Combatants.All()) do
		total[o.OwnerId] = (total[o.OwnerId] or 0) + 1
		if o.IsBot then
			bots = bots + 1
		end
	end
	local empty = 0
	for _, o in ipairs(S.Owners) do
		empty = empty + math.max(0, cap - (total[o.OwnerId] or 0))
	end
	if S.Mode == "Solo" then
		empty = empty + math.max(0, 8 - #S.Owners)
	end
	return empty + bots
end

-- [배틀 시작] 빠른 참가: 진행 중인 배틀의 빈자리 → 없으면 사람이 기다리는 대기열(자리 남은 팀전) → 없으면 3vs3 대기
local function quickJoin(player)
	if player:GetAttribute("InMatch") or player:GetAttribute("Teleporting") then
		return
	end
	if MatchService.JoinInProgress(player) then
		return
	end
	if Router.IsMatchServer then
		return -- 경기 서버에서는 이 경기에만 합류
	end
	-- 다른 서버에서 진행 중인 경기: 빈자리 있고 남은 시간이 가장 긴 곳으로 바로 입장
	local entry = Router.FindRunning(45)
	if entry then
		local left = math.max(0, math.floor(entry.EndsAt - now()))
		local q = queueDef(entry.Queue)
		remotes.Notify:FireClient(player, "진행 중인 배틀에 입장합니다 · " .. ((q and q.Id) or "") .. " · 남은 시간 "
			.. string.format("%d:%02d", left // 60, left % 60), Color3.fromRGB(140, 255, 200))
		player:SetAttribute("Teleporting", true)
		if Router.JoinRunning(player, entry) then
			return
		end
		player:SetAttribute("Teleporting", nil)
	end
	local counts = queueCounts()
	local pick, best = nil, 0
	for _, q in ipairs(Config.Queues) do
		local cap = (q.Mode == "Solo") and 8 or q.TeamSize * 2
		local n = counts[q.Id] or 0
		if q.Mode ~= "Solo" and n > best and n < cap then
			pick, best = q, n
		end
	end
	setQueue(player, pick and pick.Id or "3v3", false)
	if player:GetAttribute("Queue") then
		remotes.Notify:FireClient(player, "배틀 대기 중 · 정원이 차거나 카운트다운이 끝나면 시작해요 (취소: 배틀 취소 버튼)",
			Color3.fromRGB(255, 255, 255))
	end
end

-- 방장만 맵을 고를 수 있음 (mapId = 맵 Id 또는 "random", nil이면 순환)
local function setHostMap(player, mapId)
	local qid = player:GetAttribute("Queue")
	if not qid or player:GetAttribute("InMatch") or MatchService.QueueHost(qid) ~= player then
		return
	end
	if mapId ~= nil and mapId ~= "random" then
		local ok = false
		for _, m in ipairs(maps) do
			if m.Id == mapId then
				ok = true
			end
		end
		if not ok then
			return
		end
	end
	queueMap[qid] = mapId
end

-- 방장: 발판에 정원이 모두 모였으면 카운트다운을 건너뛰고 바로 시작
local function startNow(player)
	local qid = player:GetAttribute("Queue")
	local q = qid and queueDef(qid)
	if not q or MatchService.QueueHost(qid) ~= player then
		return
	end
	local cap = (q.Mode == "Solo") and 8 or q.TeamSize * 2
	if queueCounts()[qid] < cap then
		remotes.Notify:FireClient(player, "정원이 모두 모여야 바로 시작할 수 있어요", Color3.fromRGB(255, 200, 90))
		return
	end
	if S.Phase == "Countdown" and S.QueueId == qid then
		S.EndsAt = math.min(S.EndsAt, now() + 1)
		announce("방장이 바로 시작을 눌렀어요!", Color3.fromRGB(140, 255, 200))
	end
end

-- 경기 도중 로비로 나가기 (보상 없음, 자리는 남은 인원으로 계속)
function MatchService.LeaveMatch(player)
	if not player:GetAttribute("InMatch") then
		return
	end
	if Router.IsMatchServer then
		player:SetAttribute("Teleporting", true)
	end
	-- 어떤 단계(경기·결과)에서든 확실히 로비로: 각 정리 단계가 실패해도 다음 단계는 계속
	local e = Combatants.FromPlayer(player)
	pcall(function()
		if e then
			e.Alive = false
			Combatants.Remove(e)
		end
	end)
	for _, a in ipairs({ "Queue", "QueueTime", "QueueSide", "OwnerId", "TeamId", "TeamColor" }) do
		player:SetAttribute(a, nil)
	end
	player:SetAttribute("SpawnZone", false)
	player:SetAttribute("InMatch", false)
	pcall(ItemService.Clear, player)
	pcall(function()
		if player.Character then
			player.Character:Destroy()
		end
	end)
	local ok, err = pcall(function()
		player:LoadCharacter()
	end)
	if not ok then
		warn("[SplashFront] 로비 부활 실패:", err)
		task.delay(1, function()
			if player.Parent then
				pcall(function()
					player:LoadCharacter()
				end)
			end
		end)
	end
	Telemetry.Custom(player, "LeftMatch", 1, S.Mode or "", tostring(S.QueueId), "")
	remotes.Notify:FireClient(player, "경기에서 나와 로비로 돌아왔어요", Color3.fromRGB(200, 220, 255))
	if Router.IsMatchServer then
		task.spawn(Router.ToLobby, { player })
	end
end

-- 경기 중 무기 교체: 부활 직후이거나 우리 스폰 근처일 때만
local function nearOwnSpawn(e)
	local r = e.Model and e.Model:FindFirstChild("HumanoidRootPart")
	if not r then
		return false
	end
	local list = (S.Mode == "Solo") and arena.SoloSpawns or arena.Spawns[e.TeamId]
	for _, cf in ipairs(list or {}) do
		if (cf.Position - r.Position).Magnitude <= Config.WeaponSwitchRadius then
			return true
		end
	end
	return false
end

local function canSwitch(e)
	if not e.Alive or S.Phase ~= "Playing" then
		return false
	end
	return (os.clock() - (e.SpawnedAt or 0)) <= Config.WeaponSwitchGrace or nearOwnSpawn(e)
end

-- 칼: "equip"(true/false) = 총 ↔ 칼 전환, "swing"(대상 모델, 강공격 여부) = 근접 공격
-- 서버가 거리·방향·쿨타임을 직접 검사해서 인정
local function onMelee(player, action, a, b)
	local e = Combatants.FromPlayer(player)
	if not e or not e.Alive or not e.Model then
		return
	end
	local K = Weapons.Knife
	if action == "equip" then
		local on = a == true
		if e.Melee == on then
			return
		end
		e.Melee = on
		player:SetAttribute("Melee", on)
		pcall(attachGun, e, e.Model)
		return
	end
	if action ~= "swing" or not e.Melee then
		return
	end
	local heavy = b == true
	local now = os.clock()
	local interval = heavy and K.HeavyInterval or K.Interval
	if now - (e.LastMelee or 0) < interval * 0.8 then
		return
	end
	e.LastMelee = now
	remotes.FX:FireAllClients("Slash", { Model = e.Model, Heavy = heavy, Color = MatchService.ColorOf(e.OwnerId), Shooter = player })
	if typeof(a) ~= "Instance" then
		return -- 허공 베기
	end
	local victim = Combatants.FromModel(a)
	local root = e.Model:FindFirstChild("HumanoidRootPart")
	local vroot = victim and victim.Model and victim.Model:FindFirstChild("HumanoidRootPart")
	if not victim or not victim.Alive or not root or not vroot or not Combatants.IsEnemy(e, victim) then
		return
	end
	local diff = vroot.Position - root.Position
	if diff.Magnitude > K.Range + 3 then
		return -- 지연을 감안해도 너무 멂
	end
	local dmg = heavy and K.HeavyDamage or K.Damage
	-- 등 뒤 공격: 상대가 바라보는 방향과 같은 쪽에서 찌르면 더 큰 피해
	local flat = Vector3.new(diff.X, 0, diff.Z)
	if flat.Magnitude > 0.1 and vroot.CFrame.LookVector:Dot(flat.Unit) > 0.5 then
		dmg = dmg * K.BackMul
	end
	CombatService.Damage(e, victim, dmg, false, vroot.Position)
	PaintService.PaintBelow(vroot.Position, 3, e.OwnerId, e)
end

local function switchWeapon(player, weaponId)
	local e = Combatants.FromPlayer(player)
	local w = Weapons.ById[weaponId]
	local p = DataService.Get(player)
	if not e or not w or not p or e.WeaponId == w.Id then
		return
	end
	if not p.Owned[w.Id] then
		remotes.Notify:FireClient(player, "보유하지 않은 무기예요 · 로비 상점에서 구매", Color3.fromRGB(255, 140, 140))
		return
	end
	if not canSwitch(e) then
		remotes.Notify:FireClient(player, "무기 교체는 스폰 지점에서만 가능해요", Color3.fromRGB(255, 200, 90))
		return
	end
	e.WeaponId = w.Id
	e.Ink = Config.InkMax
	e.Melee = false
	player:SetAttribute("Melee", false)
	p.Equipped = w.Id
	DataService.Publish(player)
	player:SetAttribute("Weapon", w.Id)
	if e.Model then
		pcall(attachGun, e, e.Model)
		ItemService.OnSpawn(e)
	end
	Combatants.Sync(e)
	remotes.Notify:FireClient(player, "무기 교체: " .. w.Name .. " (" .. w.Class .. ")", Color3.fromRGB(140, 255, 200))
end

-- 이번 경기에 쓸 맵으로 모든 서비스를 전환
function MatchService.ApplyMap(info)
	arena = info
	MapBuilder.ApplyLighting(info.Lighting or "Day")
	PaintService.Init(info.Cells)
	BotService.SetCells(info.Cells)
	MissionService.SetMap(info)
	local v = ReplicatedStorage:FindFirstChild("ActiveCells")
	if v then
		v.Value = info.Cells
	end
end

function MatchService.SetNextMap(query)
	for i, m in ipairs(maps) do
		if tostring(query) == tostring(i) or m.Id == query or m.Name == query then
			nextMapIndex = i
			forcedNextMap = true
			return m.Name
		end
	end
	nextMapIndex = nextMapIndex % #maps + 1
	forcedNextMap = true
	return maps[nextMapIndex].Name
end

function MatchService.Init(remoteFolder, mapList, lobbyInfo)
	Router.SetSaver(DataService.Save)
	Router.Init()
	remotes = remoteFolder
	maps = mapList
	arena = maps[1]
	lobby = lobbyInfo
	MissionService.Init(arena, missionApi)
	BotService.SetCells(arena.Cells)
	BotService.SetGoalProvider(function(e)
		if S.Mode == "Flag" then
			local best, bestD = nil, math.huge
			local root = e.Model and e.Model:FindFirstChild("HumanoidRootPart")
			for _, f in ipairs(S.Flags) do
				if f.Owner ~= e.TeamId and root then
					local d = (f.Position - root.Position).Magnitude
					if d < bestD then
						best, bestD = f.Position, d
					end
				end
			end
			return best
		end
		if S.Mission and S.Mission.Pos then
			return S.Mission.Pos
		end
		return nil
	end)

	remotes.Queue.OnServerEvent:Connect(function(player, a, b)
		if a == "map" then
			setHostMap(player, b)
		elseif a == "startNow" then
			startNow(player)
		elseif a == "leaveMatch" then
			MatchService.LeaveMatch(player)
		elseif a == "quick" then
			quickJoin(player)
		elseif a == nil or type(a) == "string" then
			setQueue(player, a, false)
		end
	end)
	remotes.SwitchWeapon.OnServerEvent:Connect(switchWeapon)
	remotes.Melee.OnServerEvent:Connect(onMelee)
	for _, ent in ipairs(lobby.QueuePadList) do
		local id, side = ent.Queue, ent.Side
		ent.Pad.Touched:Connect(function(hit)
			local pl = Players:GetPlayerFromCharacter(hit.Parent)
			if not pl or pl:GetAttribute("InMatch") then
				return
			end
			local want = side > 0 and side or nil
			if pl:GetAttribute("Queue") == id and pl:GetAttribute("QueueSide") == want then
				return
			end
			setQueue(pl, id, true, want)
			if pl:GetAttribute("Queue") == id then
				local zone = side == 1 and " 블루 ZONE" or side == 2 and " 오렌지 ZONE" or ""
				remotes.Notify:FireClient(pl, "대기열 참가: " .. id .. zone .. " · 발판에서 내려오면 취소돼요", Color3.fromRGB(255, 255, 255))
			end
		end)
	end
	-- 발판을 벗어나면 대기 취소
	task.spawn(function()
		while true do
			task.wait(0.3)
			for _, pl in ipairs(Players:GetPlayers()) do
				local qid = pl:GetAttribute("Queue")
				if qid and not Router.IsMatchServer and not pl:GetAttribute("InMatch") and os.clock() - (joinAt[pl] or 0) > Config.PadLeaveGrace then
					local pad = padOf(qid, pl:GetAttribute("QueueSide"))
					local char = pl.Character
					local r = char and char:FindFirstChild("HumanoidRootPart")
					local hum = char and char:FindFirstChildOfClass("Humanoid")
					if pad and r and hum and hum.Health > 0 then
						local d = r.Position - pad.Position
						local radius = math.max(pad.Size.Y, pad.Size.Z) / 2 + 0.8
						local onPad = Vector3.new(d.X, 0, d.Z).Magnitude <= radius and d.Y > -2 and d.Y < 9
						if not onPad then
							setQueue(pl, nil)
							remotes.Notify:FireClient(pl, "발판을 벗어나 대기가 취소됐어요", Color3.fromRGB(255, 180, 120))
						end
					end
				end
			end
		end
	end)

	Players.PlayerRemoving:Connect(function(pl)
		joinAt[pl] = nil
		local e = Combatants.FromPlayer(pl)
		if e then
			e.Alive = false
			Combatants.Remove(e)
		end
	end)
end

function MatchService.Run()
	task.spawn(function()
		while true do
			broadcast()
			task.wait(0.5)
		end
	end)

	-- 바닥 색 처리: 적 색 노출 파티클(전원) + 봇 이동속도(플레이어는 클라이언트가 처리)
	task.spawn(function()
		while true do
			if S.Phase == "Playing" then
				for _, e in ipairs(Combatants.All()) do
					if e.Alive and e.Model then
						local r = e.Model:FindFirstChild("HumanoidRootPart")
						local h = e.Model:FindFirstChildOfClass("Humanoid")
						local o = r and PaintService.OwnerBelow(r.Position) or 0
						local fa = r and r:FindFirstChild("FeetAttachment")
						local pe = fa and fa:FindFirstChild("EnemyInkReveal")
						if pe then
							local onEnemy = o ~= 0 and o ~= e.OwnerId
							pe.Enabled = onEnemy
							if onEnemy then
								pe.Color = ColorSequence.new(MatchService.ColorOf(o))
							end
						end
						if e.Player then
							local can = canSwitch(e)
							if e.Player:GetAttribute("SpawnZone") ~= can then
								e.Player:SetAttribute("SpawnZone", can)
							end
						end
						if e.IsBot and r and h then
							if o == e.OwnerId then
								h.WalkSpeed = Config.WalkSpeedOwn
							elseif o ~= 0 then
								h.WalkSpeed = Config.WalkSpeedEnemy
							else
								h.WalkSpeed = Config.WalkSpeed
							end
						end
					end
				end
			end
			task.wait(0.25)
		end
	end)

	-- 경기 진행 (끝나면 endMatch → 결과 → 로비 상태)
	local function runPlaying()
		-- 3) 경기
		local last = os.clock()
		while S.Phase == "Playing" do
			task.wait(0.25)
			local dt = os.clock() - last
			last = os.clock()
			local left = S.EndsAt - now()
			if S.Variant == "DM" then
			for _, e in ipairs(Combatants.All()) do
				if e.Kills >= Config.DMKillTarget then
					left = 0
				end
			end
		end
		if S.Variant ~= "DM" and not S.FinalSplash and left <= Config.FinalSplashTime then
				S.FinalSplash = true
				PaintService.SetRadiusMultiplier(Config.FinalSplashMul)
				announce("파이널 스플래쉬! 페인트 범위 1.5배", Color3.fromRGB(255, 220, 60))
				remotes.FX:FireAllClients("Cue", { Name = "final_splash", Volume = 0.8 })
			end
			if S.Mode == "Flag" then
				flagTick(dt)
				for _, f in ipairs(S.Flags) do
					if f.Owner ~= 0 then
						S.FlagScore[f.Owner] = (S.FlagScore[f.Owner] or 0) + Config.Flag.PointsPerSecond * dt
					end
				end
				for _, v in pairs(S.FlagScore) do
					if v >= Config.Flag.WinScore then
						left = 0
					end
				end
			end
			-- 낙사 판정 (스카이 루프탑 등 낭떠러지 맵)
			if arena.KillY then
				for _, e in ipairs(Combatants.All()) do
					if e.Alive and e.Model then
						local r = e.Model:FindFirstChild("HumanoidRootPart")
						local h = e.Model:FindFirstChildOfClass("Humanoid")
						if r and h and h.Health > 0 and r.Position.Y < arena.KillY then
							if os.clock() - e.LastDamaged > 6 then
								e.LastAttacker = nil
							end
							h.Health = 0
						end
					end
				end
			end
			local anyHuman = false
			for _, e in ipairs(Combatants.All()) do
				if not e.IsBot then
					anyHuman = true
				end
			end
			if left <= 0 or not anyHuman then
				endMatch()
			end
		end
	end

	-- 로비 서버: 대기열이 차면 경기 전용 서버로 함께 이동 (실패하거나 Studio면 이 서버에서 진행)
	local function launchRemote(q)
		if not Router.Enabled or Router.IsMatchServer then
			return false
		end
		local capacity = (q.Mode == "Solo") and 8 or q.TeamSize * 2
		local humans = {}
		for _, pl in ipairs(Players:GetPlayers()) do
			if pl:GetAttribute("Queue") == q.Id and not pl:GetAttribute("InMatch") and #humans < capacity then
				table.insert(humans, pl)
			end
		end
		if #humans == 0 then
			return false
		end
		local mi = mapIndexFor(q)
		local mapId = maps[mi] and maps[mi].Id
		for _, pl in ipairs(humans) do
			pl:SetAttribute("Teleporting", true)
			remotes.Notify:FireClient(pl, "배틀 서버로 이동 중이에요…", Color3.fromRGB(140, 255, 200))
		end
		if Router.Launch(q, humans, mapId) then
			for _, pl in ipairs(humans) do
				pl:SetAttribute("Queue", nil)
				pl:SetAttribute("QueueSide", nil)
				pl:SetAttribute("QueueTime", nil)
				joinAt[pl] = nil
			end
			task.delay(30, function()
				for _, pl in ipairs(humans) do
					if pl.Parent then
						pl:SetAttribute("Teleporting", nil) -- 이동이 안 됐으면 다시 참가할 수 있게
					end
				end
			end)
			return true
		end
		for _, pl in ipairs(humans) do
			pl:SetAttribute("Teleporting", nil)
		end
		queueMap[q.Id] = mapId
		return false
	end

	-- 경기 서버: 함께 이동해 온 인원이 모이면 바로 한 판 → 결과 후 모두 로비 서버로
	local function runMatchServer()
		S.Phase = "Countdown"
		local qid, expected, firstT = nil, 1, nil
		while true do
			task.wait(0.5)
			for _, pl in ipairs(Players:GetPlayers()) do
				local sf = Router.NoteArrival(pl)
				if sf and not pl:GetAttribute("Queue") and not pl:GetAttribute("InMatch")
					and DataService.Get(pl) and pl.Character then
					if sf.Kind == "Match" and type(sf.Queue) == "string" and queueDef(sf.Queue) then
						qid = qid or sf.Queue
						expected = math.max(expected, tonumber(sf.Count) or 1)
						if sf.Map and queueMap[qid] == nil then
							queueMap[qid] = sf.Map
						end
					end
					if qid then
						local side = type(sf.Sides) == "table" and sf.Sides[tostring(pl.UserId)] or nil
						pl:SetAttribute("Queue", qid)
						pl:SetAttribute("QueueSide", side)
						pl:SetAttribute("QueueTime", os.clock())
						firstT = firstT or os.clock()
					end
				end
			end
			if qid then
				S.QueueId = qid
				S.EndsAt = now() + math.max(1, 20 - (os.clock() - (firstT or os.clock())))
				if (queueCounts()[qid] or 0) >= expected or os.clock() - (firstT or os.clock()) > 20 then
					break
				end
			end
		end
		for sec = 3, 1, -1 do
			S.EndsAt = now() + sec
			for _, pl in ipairs(Players:GetPlayers()) do
				remotes.FX:FireClient(pl, "Cue", { Name = "countdown_tick" })
			end
			task.wait(1)
		end
		local q = queueDef(qid)
		if q and startMatch(q) then
			runPlaying()
		end
		Router.Unpublish()
		S.Phase = "Lobby"
		Router.ToLobby(Players:GetPlayers())
		-- 늦게 온 사람·이동 실패한 사람도 로비로
		while true do
			task.wait(5)
			if #Players:GetPlayers() > 0 then
				Router.ToLobby(Players:GetPlayers())
			end
		end
	end

	if Router.IsMatchServer then
		-- 상태 알림: 로비의 [배틀 시작]이 이 경기를 찾을 수 있게
		task.spawn(function()
			while true do
				task.wait(5)
				if S.Phase == "Playing" then
					Router.Publish({ Queue = S.QueueId, Mode = S.Mode, EndsAt = S.EndsAt, Open = openSlots() })
				end
			end
		end)
		-- 진행 중에 들어온 사람(빈자리 입장 · 늦게 도착)은 바로 합류, 안 되면 로비로
		Players.PlayerAdded:Connect(function(pl)
			Router.NoteArrival(pl)
			task.spawn(function()
				local t0 = os.clock()
				while pl.Parent and not (DataService.Get(pl) and pl.Character) and os.clock() - t0 < 20 do
					task.wait(0.3)
				end
				if not pl.Parent or S.Phase == "Countdown" then
					return -- 시작 전이면 대기 루프가 받아 줌
				end
				task.wait(0.5)
				if S.Phase ~= "Playing" or not MatchService.JoinInProgress(pl) then
					remotes.Notify:FireClient(pl, "들어갈 자리가 없어 로비로 돌아가요", Color3.fromRGB(255, 200, 90))
					Router.ToLobby({ pl })
				end
			end)
		end)
		task.spawn(runMatchServer)
		return
	end

	task.spawn(function()
		while true do
			-- 1) 로비 대기
			S.Phase = "Lobby"
			local q = nil
			while not q do
				task.wait(1)
				q = pickQueue()
			end
			-- 2) 카운트다운
			S.Phase = "Countdown"
			S.QueueId = q.Id
			S.EndsAt = now() + Config.LobbyCountdown
			local aborted = false
			local lastSec = nil
			while now() < S.EndsAt do
				task.wait(0.25)
				local sec = math.ceil(S.EndsAt - now())
				if sec ~= lastSec and sec <= 3 and sec >= 1 then
					lastSec = sec
					for _, pl in ipairs(Players:GetPlayers()) do
						if pl:GetAttribute("Queue") == q.Id then
							remotes.FX:FireClient(pl, "Cue", { Name = "countdown_tick" })
						end
					end
				end
				if queueCounts()[q.Id] == 0 then
					aborted = true
					break
				end
			end
			if aborted then
				S.QueueId = nil
			elseif launchRemote(q) then
				S.QueueId = nil -- 다른 서버에서 진행 → 이 로비는 바로 다음 대기열을 받음
			elseif startMatch(q) then
				runPlaying()
			else
				S.QueueId = nil
			end
		end
	end)
end

function MatchService.GetPhase()
	return S.Phase
end

-- 관리자 패널용
function MatchService.SetTimeLeft(seconds)
	if S.Phase == "Playing" or S.Phase == "Countdown" then
		S.EndsAt = now() + math.max(0, seconds)
		return true
	end
	return false
end

function MatchService.GetState()
	return S
end

Combatants.Painted:Connect(function(e)
	if e.Player then
		Telemetry.Funnel(e.Player, "FirstPaint")
	end
end)
Combatants.Killed:Connect(function(killer)
	if killer and killer.Player then
		Telemetry.Funnel(killer.Player, "FirstKill")
	end
end)

return MatchService
