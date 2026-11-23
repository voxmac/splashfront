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
-- 사격 (플레이어·봇 공용)
------------------------------------------------------------------------
function CombatService.Fire(e, origin, directions)
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

function CombatService.OnPlayerFire(player, weaponId, origin, directions)
	local e = Combatants.FromPlayer(player)
	if not e or typeof(origin) ~= "Vector3" or type(directions) ~= "table" then
		return
	end
	if weaponId ~= e.WeaponId then
		return
	end
	CombatService.Fire(e, origin, directions)
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
