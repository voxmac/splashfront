-- 인원이 부족할 때 자리를 채우는 간단한 AI 봇
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage.Shared.Config)
local Weapons = require(ReplicatedStorage.Shared.Weapons)
local Combatants = require(script.Parent.Combatants)
local CombatService = require(script.Parent.CombatService)

local BotService = {}

local BOT_NAMES = { "Splatty", "NeonNinja", "DripKing", "PaintPanda", "Chromo", "Spritz", "Gloopy", "Blotto",
	"Inkredible", "Hue_Jack", "Smudge", "PrismPop", "Dribble", "Tagger", "Vandal_V", "Swatch" }
local nameIndex = 0
local goalProvider = nil
local cellsFolder = nil
local running = false
local state = {} -- entity -> { Goal, GoalTime, LastPos, StuckTime, Strafe }

function BotService.NextName()
	nameIndex = nameIndex % #BOT_NAMES + 1
	return "[BOT] " .. BOT_NAMES[nameIndex]
end

function BotService.RandomWeapon()
	local pool = { "Pistol", "Rifle", "SMG", "Shotgun", "Launcher", "Rifle" }
	return pool[math.random(1, #pool)]
end

function BotService.SetGoalProvider(fn)
	goalProvider = fn
end

function BotService.SetCells(folder)
	cellsFolder = folder
end

-- 봇 걷기·달리기 동작: Roblox 기본 R15 애니메이션을 서버에서 재생 (자동으로 모든 클라이언트에 보임)
local ANIM_IDS = { Idle = 507766666, Walk = 507777826, Run = 507767714, Jump = 507765000, Fall = 507767968 }
local animated = {} -- model -> { Hum, Root, Tracks, Cur }
local function setupAnimations(model)
	local hum = model:FindFirstChildOfClass("Humanoid")
	local root = model:FindFirstChild("HumanoidRootPart")
	if not hum or not root then
		return
	end
	-- 클라이언트용 Animate 스크립트는 봇에서 돌지 않으니 지우고 서버가 직접 재생
	local old = model:FindFirstChild("Animate")
	if old then
		old:Destroy()
	end
	local animator = hum:FindFirstChildOfClass("Animator") or Instance.new("Animator", hum)
	local tracks = {}
	for name, id in pairs(ANIM_IDS) do
		local a = Instance.new("Animation")
		a.AnimationId = "rbxassetid://" .. id
		local ok, t = pcall(function()
			return animator:LoadAnimation(a)
		end)
		if ok and t then
			t.Priority = (name == "Idle") and Enum.AnimationPriority.Idle or Enum.AnimationPriority.Movement
			t.Looped = name ~= "Jump"
			tracks[name] = t
		end
	end
	animated[model] = { Hum = hum, Root = root, Tracks = tracks, Cur = nil }
end

local function play(st, name, speed)
	local t = st.Tracks[name]
	if not t then
		return
	end
	if st.Cur ~= name then
		for n, other in pairs(st.Tracks) do
			if n ~= name and other.IsPlaying then
				other:Stop(0.15)
			end
		end
		t:Play(0.15)
		st.Cur = name
	end
	t:AdjustSpeed(speed or 1)
end

RunService.Heartbeat:Connect(function()
	for model, st in pairs(animated) do
		if not model.Parent or st.Hum.Health <= 0 then
			for _, t in pairs(st.Tracks) do
				t:Stop(0.2)
			end
			animated[model] = nil
		else
			local v = st.Root.AssemblyLinearVelocity
			local flat = Vector3.new(v.X, 0, v.Z).Magnitude
			local s = st.Hum:GetState()
			if s == Enum.HumanoidStateType.Freefall then
				play(st, v.Y > 2 and "Jump" or "Fall", 1)
			elseif flat > 13 then
				play(st, "Run", flat / 16)
			elseif flat > 0.8 then
				play(st, "Walk", math.max(0.5, flat / 10))
			else
				play(st, "Idle", 1)
			end
		end
	end
end)

function BotService.CreateModel(e, cframe, color)
	local folder = workspace:FindFirstChild("Bots")
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = "Bots"
		folder.Parent = workspace
	end
	local desc = Instance.new("HumanoidDescription")
	local model = Players:CreateHumanoidModelFromDescription(desc, Enum.HumanoidRigType.R15)
	model.Name = e.Name
	local hum = model:FindFirstChildOfClass("Humanoid")
	hum.MaxHealth = Config.MaxHealth
	hum.Health = Config.MaxHealth
	hum.WalkSpeed = Config.WalkSpeed
	hum.DisplayName = e.Name
	hum.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.Viewer
	for _, d in ipairs(model:GetDescendants()) do
		if d:IsA("BasePart") then
			if d.Name == "UpperTorso" or d.Name == "LowerTorso" then
				d.Color = color
			elseif d.Name ~= "HumanoidRootPart" then
				d.Color = color:Lerp(Color3.new(1, 1, 1), 0.55)
			end
		end
	end
	-- 총·헬멧·백팩은 MatchService가 플레이어와 똑같이 붙임 (ModelKit)
	model:PivotTo(cframe)
	model.Parent = folder
	local root = model:FindFirstChild("HumanoidRootPart")
	if root then
		root:SetNetworkOwner(nil)
	end
	setupAnimations(model)
	state[e] = { Goal = nil, GoalTime = 0, LastPos = cframe.Position, StuckTime = 0, Strafe = 1 }
	return model
end

local function canSee(e, fromPos, target)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { e.Model, workspace:FindFirstChild("FX") }
	local dir = target.Position - fromPos
	local hit = workspace:Raycast(fromPos, dir, params)
	return hit and hit.Instance:IsDescendantOf(target.Parent)
end

local function randomEnemyCell(e)
	if not cellsFolder then
		return nil
	end
	local cells = cellsFolder:GetChildren()
	if #cells == 0 then
		return nil
	end
	local root = e.Model.HumanoidRootPart
	local best, bestScore = nil, math.huge
	for _ = 1, 14 do
		local c = cells[math.random(1, #cells)]
		if c:GetAttribute("Owner") ~= e.OwnerId then
			local score = (c.Position - root.Position).Magnitude + math.random() * 25
			if score < bestScore then
				best, bestScore = c, score
			end
		end
	end
	return best and best.Position or cells[math.random(1, #cells)].Position
end

local function spreadDir(dir, degrees)
	if degrees <= 0 then
		return dir.Unit
	end
	local r = math.rad(degrees)
	local cf = CFrame.lookAt(Vector3.zero, dir)
	local a = math.random() * math.pi * 2
	local m = math.random() * r
	return (cf * CFrame.Angles(math.cos(a) * m, math.sin(a) * m, 0)).LookVector
end

local function fireAt(e, head, targetPos, extraSpread)
	local w = Weapons.Get(e.WeaponId)
	local dirs = {}
	local base = targetPos - head.Position
	for i = 1, w.Pellets do
		dirs[i] = spreadDir(base, w.Spread + (extraSpread or 0))
	end
	CombatService.Fire(e, head.Position, dirs)
	-- 다른 플레이어 화면에서 봇 상체·팔이 표적 쪽으로 기울도록
	if e.Model and base.Magnitude > 0.1 then
		local pitch = math.floor(math.deg(math.asin(math.clamp(base.Unit.Y, -1, 1))) + 0.5)
		if math.abs((e.Model:GetAttribute("AimPitch") or 0) - pitch) >= 3 then
			e.Model:SetAttribute("AimPitch", pitch)
		end
	end
end

local function think(e)
	local model = e.Model
	local hum = model and model:FindFirstChildOfClass("Humanoid")
	local root = model and model:FindFirstChild("HumanoidRootPart")
	local head = model and model:FindFirstChild("Head")
	if not hum or not root or not head or hum.Health <= 0 then
		return
	end
	local s = state[e]
	if not s then
		s = { Goal = nil, GoalTime = 0, LastPos = root.Position, StuckTime = 0, Strafe = 1 }
		state[e] = s
	end
	local w = Weapons.Get(e.WeaponId)
	local now = os.clock()

	-- 1) 보이는 가장 가까운 적
	local target, targetDist = nil, w.Range * 0.85
	for _, other in ipairs(Combatants.All()) do
		if other.Alive and Combatants.IsEnemy(e, other) and other.Model then
			local tr = other.Model:FindFirstChild("UpperTorso") or other.Model:FindFirstChild("HumanoidRootPart")
			if tr then
				local d = (tr.Position - head.Position).Magnitude
				if d < targetDist and canSee(e, head.Position, tr) then
					target, targetDist = tr, d
				end
			end
		end
	end

	if target then
		-- 교전: 좌우로 흔들며 사격
		if math.random() < 0.15 then
			s.Strafe = -s.Strafe
		end
		local side = (target.Position - root.Position):Cross(Vector3.yAxis)
		if side.Magnitude > 0.1 then
			hum:MoveTo(root.Position + side.Unit * 6 * s.Strafe)
		end
		root.CFrame = CFrame.lookAt(root.Position, Vector3.new(target.Position.X, root.Position.Y, target.Position.Z))
		if e.Ink >= w.InkCost then
			local aimErr = 1.5 + targetDist * 0.04
			fireAt(e, head, target.Position + Vector3.new(0, math.random() * 0.8, 0), aimErr)
		end
		if e.Special >= Config.SpecialCells and math.random() < 0.3 then
			CombatService.UseSpecial(e, target.Position)
		end
		return
	end

	-- 2) 목표 지점으로 이동하며 바닥 칠하기
	local goalNeeded = (not s.Goal) or (now - s.GoalTime > 6) or ((s.Goal - root.Position) * Vector3.new(1, 0, 1)).Magnitude < 4
	if goalNeeded then
		local g = nil
		if goalProvider and math.random() < 0.55 then
			g = goalProvider(e)
		end
		s.Goal = g or randomEnemyCell(e)
		s.GoalTime = now
	end
	if s.Goal then
		hum:MoveTo(s.Goal)
		if e.Ink > 25 then
			local flat = (s.Goal - root.Position) * Vector3.new(1, 0, 1)
			if flat.Magnitude > 0.1 then
				local aimPoint = root.Position + flat.Unit * math.min(w.Range * 0.6, 14) - Vector3.new(0, 3, 0)
				fireAt(e, head, aimPoint, 3)
			end
		end
		if e.Special >= Config.SpecialCells and math.random() < 0.05 then
			CombatService.UseSpecial(e, s.Goal)
		end
	end

	-- 3) 끼임 탈출
	if (root.Position - s.LastPos).Magnitude < 0.5 then
		s.StuckTime = s.StuckTime + 0.2
		if s.StuckTime > 1.2 then
			-- 앞이 낭떠러지(스카이 루프탑 빌딩 사이)면 뛰지 않고 목표만 바꿈
			local params = RaycastParams.new()
			params.FilterType = Enum.RaycastFilterType.Exclude
			params.FilterDescendantsInstances = { model }
			local ahead = root.Position + root.CFrame.LookVector * 5 + Vector3.new(0, 2, 0)
			if workspace:Raycast(ahead, Vector3.new(0, -25, 0), params) then
				hum.Jump = true
			end
			s.Goal = nil
			s.StuckTime = 0
		end
	else
		s.StuckTime = 0
	end
	s.LastPos = root.Position
end

function BotService.Start()
	if running then
		return
	end
	running = true
	task.spawn(function()
		while running do
			for _, e in ipairs(Combatants.All()) do
				if e.IsBot and e.Alive then
					local ok, err = pcall(think, e)
					if not ok then
						warn("[SplashFront] bot error:", err)
					end
				end
			end
			task.wait(0.2)
		end
	end)
end

function BotService.Stop()
	running = false
	state = {}
	local folder = workspace:FindFirstChild("Bots")
	if folder then
		folder:ClearAllChildren()
	end
end

return BotService
