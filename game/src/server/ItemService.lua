-- 미션 보상 아이템: 보관(최대 3개) · 사용(F) · 순서 바꾸기(G) · 효과 시간 관리
-- 보관함은 플레이어 속성 "Items"(쉼표 목록)로 클라이언트에 보임
local Players = game:GetService("Players")
local Debris = game:GetService("Debris")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage.Shared.Config)
local ModelKit = require(ReplicatedStorage.Shared.ModelKit)
local Combatants = require(script.Parent.Combatants)
local CombatService = require(script.Parent.CombatService)

local ItemService = {}

local remotes = nil
local inv = {}   -- player -> { itemId, ... }
local ById = {}
for _, it in ipairs(Config.Items) do
	ById[it.Id] = it
end
ItemService.ById = ById

local function now()
	return workspace:GetServerTimeNow()
end

local function publish(player)
	player:SetAttribute("Items", table.concat(inv[player] or {}, ","))
end

local function notify(player, text, color)
	if remotes then
		remotes.Notify:FireClient(player, text, color or Color3.fromRGB(255, 230, 120))
	end
end

function ItemService.Grant(player, id)
	if not ById[id] then
		return
	end
	local list = inv[player] or {}
	inv[player] = list
	table.insert(list, id)
	while #list > Config.ItemSlots do
		table.remove(list, 1) -- 가득 차면 가장 오래된 것부터 버림
	end
	publish(player)
	player:SetAttribute("LastItem", id .. ":" .. tostring(os.clock()))
end

function ItemService.GrantRandom(player)
	local total = 0
	for _, it in ipairs(Config.Items) do
		total = total + (it.Weight or 1)
	end
	local r = math.random() * total
	for _, it in ipairs(Config.Items) do
		r = r - (it.Weight or 1)
		if r <= 0 then
			ItemService.Grant(player, it.Id)
			return it
		end
	end
end

function ItemService.Clear(player)
	inv[player] = {}
	publish(player)
	for _, a in ipairs({ "JetpackUntil", "ShieldUntil", "ZoomBuff", "ZoomUntil", "Golden" }) do
		player:SetAttribute(a, nil)
	end
end

------------------------------------------------------------------------
-- 효과
------------------------------------------------------------------------
local function torsoOf(model)
	return model and (model:FindFirstChild("UpperTorso") or model:FindFirstChild("Torso"))
end

local function attachJetpack(e, color)
	local model = e.Model
	local torso = torsoOf(model)
	if not torso then
		return
	end
	local old = model:FindFirstChild("SF_Jetpack")
	if old then
		old:Destroy()
	end
	local pack = model:FindFirstChild("SF_Backpack")
	if pack then
		pack:Destroy() -- 잉크 탱크 대신 제트팩을 멤
	end
	local jp = ModelKit.Item("Jetpack", color)
	jp.Name = "SF_Jetpack"
	for _, p in ipairs(jp:GetDescendants()) do
		if p:IsA("BasePart") then
			p.Massless = true
		end
	end
	jp:PivotTo(torso.CFrame * CFrame.new(0, 0.1, torso.Size.Z / 2 + 0.2))
	for _, p in ipairs(jp:GetDescendants()) do
		if p:IsA("BasePart") then
			p.Anchored = false
			local w = Instance.new("WeldConstraint")
			w.Part0 = torso
			w.Part1 = p
			w.Parent = p
		end
	end
	-- 노즐 불꽃 (모두에게 보임)
	for _, a in ipairs(jp:GetDescendants()) do
		if a:IsA("Attachment") and a.Name == "Flame" then
			local pe = Instance.new("ParticleEmitter")
			pe.Color = ColorSequence.new(Color3.fromRGB(255, 240, 160), Color3.fromRGB(255, 90, 30))
			pe.LightEmission = 1
			pe.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.55), NumberSequenceKeypoint.new(1, 0) })
			pe.Lifetime = NumberRange.new(0.18, 0.3)
			pe.Speed = NumberRange.new(10, 14)
			pe.Rate = 60
			pe.EmissionDirection = Enum.NormalId.Left -- 원기둥을 세웠으므로 로컬 -X = 아래
			pe.SpreadAngle = Vector2.new(8, 8)
			pe.Parent = a
			local l = Instance.new("PointLight")
			l.Color = Color3.fromRGB(255, 170, 60)
			l.Range = 8
			l.Brightness = 2
			l.Parent = a
		end
	end
	jp.Parent = model
end

local function spawnSmoke(pos, duration)
	local fx = workspace:FindFirstChild("FX") or workspace
	local cloud = Instance.new("Model")
	cloud.Name = "SmokeCloud"
	local R = Config.SmokeRadius
	local rng = Random.new()
	for i = 1, 13 do
		local a = rng:NextNumber() * math.pi * 2
		local d = rng:NextNumber(0, R * 0.55)
		local size = rng:NextNumber(R * 0.75, R * 1.1)
		local p = Instance.new("Part")
		p.Name = "Puff"
		p.Shape = Enum.PartType.Ball
		p.Size = Vector3.one * 2
		p.Position = pos + Vector3.new(math.cos(a) * d, rng:NextNumber(2, 8), math.sin(a) * d)
		p.Color = Color3.fromRGB(rng:NextInteger(205, 230), rng:NextInteger(208, 232), rng:NextInteger(215, 238))
		p.Material = Enum.Material.SmoothPlastic
		p.Transparency = 0.6
		p.Anchored = true
		p.CanCollide = false
		p.CanQuery = false -- 총알은 통과(시야만 가림)
		p.CanTouch = false
		p.CastShadow = false
		p.Parent = cloud
		TweenService:Create(p, TweenInfo.new(0.6 + i * 0.05, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
			{ Size = Vector3.one * size, Transparency = 0.04 }):Play()
		task.delay(duration - 1.5, function()
			if p.Parent then
				TweenService:Create(p, TweenInfo.new(1.4), { Transparency = 1 }):Play()
			end
		end)
	end
	local core = cloud:FindFirstChild("Puff")
	if core then
		local pe = Instance.new("ParticleEmitter")
		pe.Color = ColorSequence.new(Color3.fromRGB(230, 232, 240))
		pe.Size = NumberSequence.new(4, 9)
		pe.Transparency = NumberSequence.new(0.3, 1)
		pe.Lifetime = NumberRange.new(2, 3)
		pe.Speed = NumberRange.new(1, 3)
		pe.Rate = 12
		pe.SpreadAngle = Vector2.new(180, 180)
		pe.Parent = core
		task.delay(duration - 2, function()
			pe.Enabled = false
		end)
	end
	cloud.Parent = fx
	Debris:AddItem(cloud, duration + 0.5)
end

local function use(player, target)
	local list = inv[player]
	local e = Combatants.FromPlayer(player)
	if not list or #list == 0 then
		return
	end
	if not e or not e.Alive or not player:GetAttribute("InMatch") then
		notify(player, "아이템은 경기 중에 쓸 수 있어요", Color3.fromRGB(255, 180, 120))
		return
	end
	local id = list[1]
	local def = ById[id]
	local color = player:GetAttribute("TeamColor") or Color3.new(1, 1, 1)
	if id == "Jetpack" then
		player:SetAttribute("JetpackUntil", now() + def.Duration)
		attachJetpack(e, color)
	elseif id == "Shield" then
		e.ProtectedUntil = os.clock() + def.Duration
		player:SetAttribute("ShieldUntil", now() + def.Duration)
		if e.Model then
			local ff = Instance.new("ForceField")
			ff.Name = "SF_Shield"
			ff.Visible = true
			ff.Parent = e.Model
			Debris:AddItem(ff, def.Duration)
		end
	elseif id == "Smoke" then
		if typeof(target) ~= "Vector3" then
			return
		end
		CombatService.Throw(e, target, "Smoke", Color3.fromRGB(220, 224, 232), function(pos)
			spawnSmoke(pos, def.Duration)
		end)
	elseif id == "Golden" then
		e.Golden = true
		player:SetAttribute("Golden", true)
		local gun = e.Model and e.Model:FindFirstChild("SF_Gun")
		if gun then
			ModelKit.SetGolden(gun, true)
		end
	elseif id == "Zoom3" or id == "Zoom6" then
		player:SetAttribute("ZoomBuff", def.Zoom)
		player:SetAttribute("ZoomUntil", now() + def.Duration)
	end
	table.remove(list, 1)
	publish(player)
	notify(player, def.Name .. " 사용!", Color3.fromRGB(140, 255, 200))
	if ItemService.OnUsed then
		ItemService.OnUsed(player, id)
	end
end

local function cycle(player)
	local list = inv[player]
	if list and #list > 1 then
		table.insert(list, table.remove(list, 1))
		publish(player)
	end
end

function ItemService.Init(remoteFolder)
	remotes = remoteFolder
	remotes.UseItem.OnServerEvent:Connect(function(player, action, target)
		if action == "use" then
			use(player, target)
		elseif action == "cycle" then
			cycle(player)
		end
	end)
	Players.PlayerRemoving:Connect(function(pl)
		inv[pl] = nil
	end)
	-- 효과 시간 만료 처리
	task.spawn(function()
		while true do
			task.wait(0.25)
			local t = now()
			for _, pl in ipairs(Players:GetPlayers()) do
				local ju = pl:GetAttribute("JetpackUntil")
				if ju and t > ju then
					pl:SetAttribute("JetpackUntil", nil)
					local jp = pl.Character and pl.Character:FindFirstChild("SF_Jetpack")
					if jp then
						jp:Destroy()
					end
				end
				local su = pl:GetAttribute("ShieldUntil")
				if su and t > su then
					pl:SetAttribute("ShieldUntil", nil)
				end
				local zu = pl:GetAttribute("ZoomUntil")
				if zu and t > zu then
					pl:SetAttribute("ZoomUntil", nil)
					pl:SetAttribute("ZoomBuff", nil)
				end
			end
		end
	end)
	-- 황금총을 쏘면(서버가 Golden=false) 총 색을 되돌림
	local function watch(pl)
		pl:GetAttributeChangedSignal("Golden"):Connect(function()
			if not pl:GetAttribute("Golden") then
				local gun = pl.Character and pl.Character:FindFirstChild("SF_Gun")
				if gun then
					ModelKit.SetGolden(gun, false, pl:GetAttribute("TeamColor"))
				end
			end
		end)
	end
	Players.PlayerAdded:Connect(watch)
	for _, pl in ipairs(Players:GetPlayers()) do
		watch(pl)
	end
end

-- 부활할 때 황금총이 남아 있으면 새 총도 금색으로
function ItemService.OnSpawn(e)
	if e.Player and e.Golden and e.Model then
		local gun = e.Model:FindFirstChild("SF_Gun")
		if gun then
			ModelKit.SetGolden(gun, true)
		end
	end
end

return ItemService
