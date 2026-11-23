-- 사격·피해·스페셜·잉크/체력 회복 (서버 권한 판정)
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage.Shared.Config)
local Weapons = require(ReplicatedStorage.Shared.Weapons)
local Combatants = require(script.Parent.Combatants)
local PaintService = require(script.Parent.PaintService)

local CombatService = {}

local remotes = nil
local colorOf = function()
	return Config.NeutralColor
end
local active = false

function CombatService.Init(remoteFolder)
	remotes = remoteFolder
	remotes.Fire.OnServerEvent:Connect(CombatService.OnPlayerFire)
	remotes.Special.OnServerEvent:Connect(CombatService.OnPlayerSpecial)
end

function CombatService.SetActive(on)
	active = on
end

function CombatService.SetColorResolver(fn)
	colorOf = fn
end

local function rootOf(e)
	local m = e.Model
	return m and m:FindFirstChild("HumanoidRootPart")
end

local function humanoidOf(e)
	local m = e.Model
	return m and m:FindFirstChildOfClass("Humanoid")
end

local function headOf(e)
	local m = e.Model
	return m and m:FindFirstChild("Head")
end

local function fxFolder()
	local f = workspace:FindFirstChild("FX")
	if not f then
		f = Instance.new("Folder")
		f.Name = "FX"
		f.Parent = workspace
	end
	return f
end

------------------------------------------------------------------------
-- 피해
------------------------------------------------------------------------
function CombatService.Damage(attacker, victim, amount, headshot, hitPos)
	if not victim.Alive then
		return false
	end
	if os.clock() < victim.ProtectedUntil then
		return false
	end
	local hum = humanoidOf(victim)
	if not hum or hum.Health <= 0 then
		return false
	end
	victim.LastDamaged = os.clock()
	victim.LastAttacker = attacker
	victim.LastHeadshot = headshot
	local newHealth = math.max(0, hum.Health - amount)
	hum.Health = newHealth
	local killed = newHealth <= 0

	if attacker and attacker.Player then
		remotes.HitConfirm:FireClient(attacker.Player, {
			Damage = math.floor(amount + 0.5), Head = headshot, Pos = hitPos, Kill = killed,
		})
	end
	if victim.Player then
		local from = rootOf(attacker or victim)
		local color = attacker and colorOf(attacker.OwnerId) or nil
		remotes.Damaged:FireClient(victim.Player, from and from.Position or hitPos, amount, color)
	end
	return killed
end

local function splashDamage(attacker, center, radius, maxDamage)
	for _, e in ipairs(Combatants.All()) do
		if e.Alive and Combatants.IsEnemy(attacker, e) then
			local r = rootOf(e)
			if r then
				local d = (r.Position - center).Magnitude
				if d <= radius then
					local dmg = maxDamage * (1 - 0.5 * (d / radius))
					CombatService.Damage(attacker, e, dmg, false, r.Position)
				end
			end
		end
	end
end

------------------------------------------------------------------------
-- 명중 보정 (지연 보상): 서버에서 보는 적 위치는 쏜 사람 화면보다 조금 늦으므로
-- 레이가 적 머리·몸통 가까이(허용 거리 안) 지나가면 명중으로 인정. 벽 뒤는 인정 안 함
------------------------------------------------------------------------
local BODY_PARTS = { "UpperTorso", "LowerTorso", "Torso", "HumanoidRootPart" }
local function assistHit(e, origin, dir, maxDist, params)
	local A = Config.HitAssist
	if not A then
		return nil
	end
	local best, bestT, bestHead = nil, math.huge, false
	for _, v in ipairs(Combatants.All()) do
		if v.Alive and v.Model and Combatants.IsEnemy(e, v) then
			local function perpOf(part)
				local rel = part.Position - origin
				local t = rel:Dot(dir)
				if t <= 0 or t > maxDist then
					return math.huge, t
				end
				return (rel - dir * t).Magnitude, t
			end
			local head = v.Model:FindFirstChild("Head")
			local hp, ht = math.huge, 0
			if head then
				hp, ht = perpOf(head)
			end
			local bp, bt = math.huge, 0
			for _, n in ipairs(BODY_PARTS) do
				local part = v.Model:FindFirstChild(n)
				if part then
					local p2, t2 = perpOf(part)
					if p2 < bp then
						bp, bt = p2, t2
					end
				end
			end
			local isHead, t = nil, nil
			if hp <= A.Head + ht * A.PerStud then
				isHead, t = true, ht
			elseif bp <= A.Body + bt * A.PerStud then
				isHead, t = false, bt
			end
			if t and t < bestT then
				-- 시야 확인: 맞힌 지점까지 벽이 없어야 함
				local p = origin + dir * t
				local block = workspace:Raycast(origin, p - origin, params)
				if not block or Combatants.FromPart(block.Instance) == v or (block.Position - origin).Magnitude >= t - 1.5 then
					best, bestT, bestHead = v, t, isHead
				end
			end
		end
	end
	if best then
		return best, bestHead, origin + dir * bestT
	end
	return nil
end

------------------------------------------------------------------------
-- 사격 (플레이어·봇 공용)
------------------------------------------------------------------------
-- 쏜 사람 화면에서 맞힌 지점(claim)을 검증: 그 캐릭터가 서버에서도 근처에 있고, 탄도 위에 있고, 벽에 막히지 않았으면 인정
local function verifyClaim(e, origin, dir, range, claim)
	local K = Config.HitClaim
	if not K or type(claim) ~= "table" or typeof(claim.Part) ~= "Instance" or typeof(claim.Pos) ~= "Vector3" then
		return nil
	end
	if not claim.Part:IsA("BasePart") then
		return nil
	end
	local v = Combatants.FromPart(claim.Part)
	if not v or not v.Alive or not Combatants.IsEnemy(e, v) then
		return nil
	end
	local rel = claim.Pos - origin
	local t = rel:Dot(dir)
	if t <= 0 or t > range or (rel - dir * t).Magnitude > K.MaxPerp then
		return nil
	end
	if (claim.Part.Position - claim.Pos).Magnitude > K.MaxMove + claim.Part.Size.Magnitude / 2 then
		return nil
	end
	-- 시야: 캐릭터들을 빼고 지형만으로 막히는지
	local ignore = { e.Model, fxFolder(), workspace:FindFirstChild("Lobby"), workspace:FindFirstChild("Bots") }
	for _, o in ipairs(Combatants.All()) do
		if o.Model then
			table.insert(ignore, o.Model)
		end
	end
	local mp = RaycastParams.new()
	mp.FilterType = Enum.RaycastFilterType.Exclude
	mp.FilterDescendantsInstances = ignore
	if workspace:Raycast(origin, rel * 0.98, mp) then
		return nil
	end
	local part = claim.Part
	local isHead = part.Name == "Head"
	if not isHead and part.Parent and part.Parent:IsA("Accessory") then
		for _, a in ipairs(part:GetChildren()) do
			if a:IsA("Attachment") and (string.find(a.Name, "Hat") or string.find(a.Name, "Hair") or string.find(a.Name, "Face")) then
				isHead = true
			end
		end
	end
	local target = isHead and (v.Model:FindFirstChild("Head") or part) or part
	return { Instance = target, Position = claim.Pos, Normal = -dir }
end

function CombatService.Fire(e, origin, directions, claims)
	if not active or not e.Alive then
		return false
	end
	local w = Weapons.Get(e.WeaponId)
	local now = os.clock()
	if now - e.LastFire < w.FireInterval * 0.75 then
		return false
	end
	if e.Ink < w.InkCost then
		return false
	end
	local head = headOf(e)
	if not head or (head.Position - origin).Magnitude > 10 then
		return false
	end
	e.LastFire = now
	e.Ink = e.Ink - w.InkCost

	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { e.Model, fxFolder(), workspace:FindFirstChild("Lobby") }

	local endpoints = {}
	local count = math.min(#directions, w.Pellets)
	for i = 1, count do
		local dir = directions[i]
		if typeof(dir) == "Vector3" and dir.Magnitude > 0.5 then
			dir = dir.Unit
			e.Shots = (e.Shots or 0) + 1
			local result = workspace:Raycast(origin, dir * w.Range, params)
			local endPos
			-- 서버 레이가 빗나갔으면(지연 때문에 적이 서버에서 조금 옆에 있음) 플레이어 사격에 한해
			-- 1) 쏜 사람 화면의 명중 판정을 검증해 인정  2) 그래도 없으면 탄도 근처 적 보정
			local directVictim = result and Combatants.FromPart(result.Instance)
			if e.Player and not (directVictim and Combatants.IsEnemy(e, directVictim)) then
				local claimed = verifyClaim(e, origin, dir, w.Range, type(claims) == "table" and claims[i] or nil)
				if claimed then
					result = claimed
				else
					local maxDist = result and ((result.Position - origin).Magnitude + 1) or w.Range
					local v, isHead, pos = assistHit(e, origin, dir, maxDist, params)
					if v then
						local part = v.Model:FindFirstChild(isHead and "Head" or "UpperTorso") or v.Model:FindFirstChild("HumanoidRootPart")
						result = { Instance = part, Position = pos, Normal = -dir }
					end
				end
			end
			if result then
				endPos = result.Position
				local victim = Combatants.FromPart(result.Instance)
				if victim then
					if Combatants.IsEnemy(e, victim) then
						local isHead = result.Instance.Name == "Head"
						e.Hits = (e.Hits or 0) + 1
						if isHead then
							e.Headshots = (e.Headshots or 0) + 1
						end
						local dmg = w.Damage * (isHead and w.HeadMul or 1)
						CombatService.Damage(e, victim, dmg, isHead, endPos)
						PaintService.PaintBelow(endPos, 2.5, e.OwnerId, e)
					end
				elseif result.Normal.Y > 0.5 then
					PaintService.PaintAt(endPos, w.PaintRadius, e.OwnerId, e)
				else
					-- 벽에 맞으면 아래로 흘러내림
					PaintService.PaintBelow(endPos + result.Normal * 1.5, w.PaintRadius * 0.7, e.OwnerId, e)
				end
				if w.Splash > 0 then
					splashDamage(e, endPos, w.Splash, w.Damage)
					PaintService.PaintBelow(endPos + Vector3.new(0, 2, 0), w.PaintRadius, e.OwnerId, e)
				end
			else
				endPos = origin + dir * w.Range
				PaintService.PaintBelow(endPos, w.PaintRadius * 0.7, e.OwnerId, e)
			end
			if w.PathPaint then
				local dist = math.min((endPos - origin).Magnitude, w.PathMax or 240)
				local step = w.PathStep or 7
				local d = step
				while d < dist do
					PaintService.PaintBelow(origin + dir * d, w.PathRadius or 2.5, e.OwnerId, e)
					d = d + step
				end
			end
			table.insert(endpoints, endPos)
		end
	end

	remotes.FX:FireAllClients("Tracer", {
		Shooter = e.Player, From = origin, To = endpoints, Color = colorOf(e.OwnerId), Weapon = w.Id,
		Model = e.Model,
	})
	Combatants.Sync(e)
	return true
end

function CombatService.OnPlayerFire(player, weaponId, origin, directions, claims)
	local e = Combatants.FromPlayer(player)
	if not e or typeof(origin) ~= "Vector3" or type(directions) ~= "table" then
		return
	end
	if weaponId ~= e.WeaponId then
		return
	end
	CombatService.Fire(e, origin, directions, claims)
end

------------------------------------------------------------------------
-- 스페셜: 크로마 봄
------------------------------------------------------------------------
function CombatService.UseSpecial(e, target)
	if not active or not e.Alive or e.Special < Config.SpecialCells then
		return false
	end
	local head = headOf(e)
	if not head or typeof(target) ~= "Vector3" then
		return false
	end
	local offset = target - head.Position
	if offset.Magnitude > 70 then
		target = head.Position + offset.Unit * 70
	end
	e.Special = 0
	Combatants.Sync(e)
	local color = colorOf(e.OwnerId)
	remotes.FX:FireAllClients("Bomb", { From = head.Position, To = target, Color = color, Radius = Config.SpecialRadius })
	task.delay(0.7, function()
		if not active then
			return
		end
		PaintService.PaintBelow(target + Vector3.new(0, 3, 0), Config.SpecialRadius, e.OwnerId, e)
		splashDamage(e, target, Config.SpecialRadius, Config.SpecialDamage)
	end)
	return true
end

function CombatService.OnPlayerSpecial(player, target)
	local e = Combatants.FromPlayer(player)
	if e then
		CombatService.UseSpecial(e, target)
	end
end

------------------------------------------------------------------------
-- 잉크 충전·체력 회복 (Main 루프에서 0.1초마다 호출)
------------------------------------------------------------------------
function CombatService.Tick(dt)
	if not active then
		return
	end
	local now = os.clock()
	for _, e in ipairs(Combatants.All()) do
		if e.Alive then
			local root = rootOf(e)
			if root then
				if now - e.LastFire > Config.InkRefillDelay and e.Ink < Config.InkMax then
					local own = PaintService.OwnerBelow(root.Position) == e.OwnerId
					local rate = own and Config.InkRefillOwnColor or Config.InkRefill
					e.Ink = math.min(Config.InkMax, e.Ink + rate * dt)
				end
				local hum = humanoidOf(e)
				if hum and hum.Health > 0 and hum.Health < hum.MaxHealth and now - e.LastDamaged > Config.RegenDelay then
					hum.Health = math.min(hum.MaxHealth, hum.Health + Config.RegenPerSecond * dt)
				end
			end
			Combatants.Sync(e)
		end
	end
end

return CombatService
