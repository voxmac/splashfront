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
local RankService = require(script.Parent.RankService)
local Telemetry = require(script.Parent.TelemetryService)

local MatchService = {}

local remotes, arena, lobby
local maps = {}
local nextMapIndex = 1
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
	local list = {}
	for _, o in ipairs(S.Owners) do
		local cov = coverage[o.OwnerId] or 0
		local bonus = S.Bonus[o.OwnerId] or 0
		local score
		if S.Mode == "Flag" then
			score = S.FlagScore[o.OwnerId] or 0
		else
			score = cov + bonus
		end
		table.insert(list, {
			OwnerId = o.OwnerId, Name = o.Name, Color = o.Color,
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

local function broadcast()
	local flags = {}
	for _, f in ipairs(S.Flags) do
		local best = 0
		for _, v in pairs(f.Progress) do
			best = math.max(best, v)
		end
		table.insert(flags, { Name = f.Name, Owner = f.Owner, Progress = best })
	end
	local modeDef = S.Mode and Config.Modes[S.Mode]
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
	remotes.State:FireAllClients({
		Phase = S.Phase,
		QueueId = S.QueueId,
		Mode = S.Mode,
		ModeName = modeDef and modeDef.Name or "",
		MapName = arena.Name,
		MapId = arena.Id,
		NextMapName = maps[nextMapIndex] and maps[nextMapIndex].Name or "",
		EndsAt = S.EndsAt,
		Teams = scores(),
		Mission = S.Mission,
		Flags = flags,
		QueueCounts = queueCounts(),
		FinalSplash = S.FinalSplash,
	})
end

------------------------------------------------------------------------
-- 스폰
------------------------------------------------------------------------
local function teamVest(character, color)
	local torso = character:FindFirstChild("UpperTorso") or character:FindFirstChild("Torso")
	if not torso then
		return
	end
	local old = character:FindFirstChild("TeamVest")
	if old then
		old:Destroy()
	end
	local vest = Instance.new("Part")
	vest.Name = "TeamVest"
	vest.Size = torso.Size + Vector3.new(0.25, -0.2, 0.25)
	vest.Color = color
	vest.Material = Enum.Material.Neon
	vest.CanCollide = false
	vest.CanQuery = false
	vest.Massless = true
	vest.Transparency = 0.15
	vest.CFrame = torso.CFrame
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = torso
	weld.Part1 = vest
	weld.Parent = vest
	vest.Parent = character
end

-- 총(오른손) + 크루 헬멧 + 잉크 탱크 백팩 (Blender 모델, 업로드 전에는 내장 대체 모델)
local function attachGear(e, model)
	for _, n in ipairs({ "SF_Gun", "SF_Helmet", "SF_Backpack" }) do
		local old = model:FindFirstChild(n)
		if old then
			old:Destroy()
		end
	end
	local color = MatchService.ColorOf(e.OwnerId)
	local hand = model:FindFirstChild("RightHand") or model:FindFirstChild("Right Arm")
	if hand then
		local skin = e.Player and Cosmetics.ById[e.Player:GetAttribute("Skin") or ""] or nil
		local gun = ModelKit.Gun(e.WeaponId, color, skin, skin and Cosmetics.MaterialOf(skin.Material) or nil)
		gun.Name = "SF_Gun"
		ModelKit.WeldTo(gun, hand, CFrame.new(0, -0.25, -0.15))
	end
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

local function spawnCFrame(e)
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
	local okGear, gearErr = pcall(attachGear, e, model)
	if not okGear then
		warn("[SplashFront] 장비 부착 실패:", gearErr)
	end
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
	local killer = e.LastAttacker
	local root = model:FindFirstChild("HumanoidRootPart")
	if killer and killer ~= e then
		killer.Kills = killer.Kills + 1
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
		Effect = killer and killer.KillEffect or nil,
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
local function buildFlags()
	local fx = workspace:FindFirstChild("FX")
	for _, def in ipairs(arena.FlagPoints) do
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
	MatchService.ApplyMap(maps[nextMapIndex])
	nextMapIndex = nextMapIndex % #maps + 1
	PaintService.SetRadiusMultiplier(1)
	S.QueueId = q.Id
	S.Mode = mode
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
		for _, t in ipairs(Config.Teams) do
			table.insert(S.Owners, { OwnerId = t.Id, Name = t.Name, Color = t.Color })
		end
		for i = 1, capacity do
			local team = ((i - 1) % 2) + 1
			slots[i] = { OwnerId = team, TeamId = team }
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
		if profile and profile.EquippedPattern and Cosmetics.ById[profile.EquippedPattern] then
			e.PatternMaterial = Cosmetics.MaterialOf(Cosmetics.ById[profile.EquippedPattern].Material)
		end
		e.KillEffect = profile and profile.EquippedEffect or nil
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
	MissionService.Start()
	for _, pl in ipairs(humans) do
		remotes.FX:FireClient(pl, "Cue", { Name = "countdown_go" })
	end
	announce(Config.Modes[mode].Name .. " 시작! " .. Config.Modes[mode].Desc, Color3.fromRGB(255, 255, 255))
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
			Color = MatchService.ColorOf(e.OwnerId), Kills = e.Kills, Deaths = e.Deaths,
			Cells = e.Cells, Coins = e.IsBot and 0 or coins, RatingDelta = ratingDelta, Won = won,
		})
	end
	table.sort(rows, function(a, b)
		return (a.Cells + a.Kills * 30) > (b.Cells + b.Kills * 30)
	end)
	Telemetry.RecordMatch(statRows)

	local winnerInfo = winner and ownerInfo(winner)
	remotes.Results:FireAllClients({
		Mode = S.Mode,
		Teams = final,
		WinnerName = winnerInfo and winnerInfo.Name or nil,
		WinnerColor = winnerInfo and winnerInfo.Color or nil,
		Rows = rows,
		Ranked = ranked,
	})
	broadcast()
	task.wait(Config.ResultsTime)

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
			e.Player:SetAttribute("OwnerId", nil)
			e.Player:SetAttribute("TeamColor", nil)
			e.Player:LoadCharacter()
			DataService.Save(e.Player)
		end
	end
	Combatants.Clear()
	S.Phase = "Lobby"
	S.Mode = nil
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

local function setQueue(player, queueId)
	if player:GetAttribute("InMatch") then
		return
	end
	if queueId ~= nil and not queueDef(queueId) then
		return
	end
	player:SetAttribute("Queue", queueId)
	if queueId then
		Telemetry.Funnel(player, "Queued")
	end
end

-- 이번 경기에 쓸 맵으로 모든 서비스를 전환
function MatchService.ApplyMap(info)
	arena = info
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
			return m.Name
		end
	end
	nextMapIndex = nextMapIndex % #maps + 1
	return maps[nextMapIndex].Name
end

function MatchService.Init(remoteFolder, mapList, lobbyInfo)
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

	remotes.Queue.OnServerEvent:Connect(setQueue)
	for id, pad in pairs(lobby.QueuePads) do
		pad.Touched:Connect(function(hit)
			local pl = Players:GetPlayerFromCharacter(hit.Parent)
			if pl and pl:GetAttribute("Queue") ~= id then
				setQueue(pl, id)
				remotes.Notify:FireClient(pl, "대기열 참가: " .. id .. " (다시 누르면 UI에서 취소)", Color3.fromRGB(255, 255, 255))
			end
		end)
	end

	Players.PlayerRemoving:Connect(function(pl)
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
			if not aborted and startMatch(q) then
				-- 3) 경기
				local last = os.clock()
				while S.Phase == "Playing" do
					task.wait(0.25)
					local dt = os.clock() - last
					last = os.clock()
					local left = S.EndsAt - now()
					if not S.FinalSplash and left <= Config.FinalSplashTime then
						S.FinalSplash = true
						PaintService.SetRadiusMultiplier(Config.FinalSplashMul)
						announce("파이널 스플래시! 페인트 범위 1.5배", Color3.fromRGB(255, 220, 60))
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
