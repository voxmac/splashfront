-- 맵 3: 시가전 (Big City)
-- Studio 인벤토리에서 넣은 "BigCity" 모델(ServerStorage 또는 ServerStorage.Maps 안)을 복제해 전장으로 씀.
-- 모델 안의 스크립트는 안전을 위해 모두 지우고, 도로·광장처럼 평평한 바닥을 위에서 쏘아 찾아 페인트 셀을 깐다.
-- 카툰 외곽선·흰색 팔레트·표면 텍스처는 적용하지 않음 (원본 질감 + 사실적인 흐린 오후 조명)
local ServerStorage = game:GetService("ServerStorage")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage.Shared.Config)

local CityMap = {}

local CELL = Config.CellSize
local ORIGIN = Vector3.new(2800, 0, 0) -- 다른 맵과 겹치지 않는 곳
local MAX_X, MAX_Z = 380, 260          -- 전투 구역 최대 크기 (도시가 더 크면 가운데만 사용)
local WALL_H = 160

local function findSource()
	local names = { "BigCity", "Big City", "Big_City" }
	for _, holder in ipairs({ ServerStorage:FindFirstChild("Maps"), ServerStorage, workspace }) do
		if holder then
			for _, n in ipairs(names) do
				local m = holder:FindFirstChild(n)
				if m and (m:IsA("Model") or m:IsA("Folder")) then
					return m
				end
			end
		end
	end
	return nil
end

local function wall(parent, size, pos)
	local p = Instance.new("Part")
	p.Name = "CityBoundary"
	p.Anchored = true
	p.Size = size
	p.Position = pos
	p.Transparency = 1
	p.CanQuery = false
	p.CastShadow = false
	p.Parent = parent
	return p
end

local function cell(parent, pos)
	local c = Instance.new("Part")
	c.Name = "Cell"
	c.Anchored = true
	c.Size = Vector3.new(CELL - 0.08, 0.2, CELL - 0.08)
	c.Position = pos + Vector3.new(0, 0.1, 0)
	c.Color = Config.NeutralColor
	c.Material = Enum.Material.SmoothPlastic
	c.CanCollide = false
	c.CanTouch = false
	c.CastShadow = false
	c.Transparency = 1 -- 판정용 격자, 화면의 페인트는 클라이언트 PaintVisual이 그림
	c:SetAttribute("Owner", 0)
	c.Parent = parent
	return c
end

function CityMap.Build()
	local src = findSource()
	if not src then
		warn("[SplashFront] 시가전 맵: ServerStorage에 'BigCity' 모델이 없어 건너뜀")
		return nil
	end
	local old = workspace:FindFirstChild("Arena_City")
	if old then
		old:Destroy()
	end
	local root = Instance.new("Folder")
	root.Name = "Arena_City"
	root.Parent = workspace
	local cells = Instance.new("Folder")
	cells.Name = "Cells"
	cells.Parent = root

	local geo = src:Clone()
	geo.Name = "Geometry"
	-- 무료 모델 안의 스크립트(바이러스·지연 로딩 등)는 실행되지 않게 제거
	for _, d in ipairs(geo:GetDescendants()) do
		if d:IsA("BaseScript") or d:IsA("ModuleScript") then
			d:Destroy()
		end
	end
	local model = geo
	if not geo:IsA("Model") then
		model = Instance.new("Model")
		model.Name = "Geometry"
		for _, c in ipairs(geo:GetChildren()) do
			c.Parent = model
		end
		geo:Destroy()
	end
	model.Parent = root
	for _, d in ipairs(model:GetDescendants()) do
		if d:IsA("BasePart") then
			d.Anchored = true
		elseif d:IsA("Sound") then
			d:Stop()
		end
	end
	-- 모델 중심을 ORIGIN으로
	local bcf, bsize = model:GetBoundingBox()
	model:PivotTo(model:GetPivot() + (ORIGIN - bcf.Position) + Vector3.new(0, bsize.Y / 2, 0))
	bcf, bsize = model:GetBoundingBox()
	local top = bcf.Position.Y + bsize.Y / 2 + 5
	local bottom = bcf.Position.Y - bsize.Y / 2

	-- 바닥 높이 = 위에서 쏜 광선이 가장 많이 닿은 높이 (도로)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = { model }
	local hx = math.min(bsize.X / 2 - 6, MAX_X / 2)
	local hz = math.min(bsize.Z / 2 - 6, MAX_Z / 2)
	-- 긴 쪽을 X(팀 진영 방향)로
	local swap = hz > hx
	local hist = {}
	local samples = {}
	local x = -hx + CELL / 2
	while x < hx do
		local z = -hz + CELL / 2
		while z < hz do
			local p = ORIGIN + Vector3.new(x, 0, z)
			local hit = workspace:Raycast(Vector3.new(p.X, top, p.Z), Vector3.new(0, bottom - top - 5, 0), params)
			if hit and hit.Normal.Y > 0.9 then
				local key = math.floor(hit.Position.Y + 0.5)
				hist[key] = (hist[key] or 0) + 1
				table.insert(samples, { X = p.X, Z = p.Z, Y = hit.Position.Y })
			end
			z = z + CELL
		end
		x = x + CELL
	end
	local groundY, best = bottom, 0
	for k, n in pairs(hist) do
		if n > best then
			groundY, best = k, n
		end
	end

	-- 바닥 셀: 도로 높이 ±3 이내의 평평한 곳만 (건물 지붕 아래·내부는 제외)
	local list = {}
	for _, s in ipairs(samples) do
		if math.abs(s.Y - groundY) <= 3 then
			local c = cell(cells, Vector3.new(s.X, s.Y, s.Z))
			table.insert(list, c)
		end
	end

	-- 전투 구역 경계 (투명 벽 + 천장)
	local cx, cz = ORIGIN.X, ORIGIN.Z
	local midY = groundY + WALL_H / 2
	wall(root, Vector3.new(hx * 2 + 4, WALL_H, 2), Vector3.new(cx, midY, cz - hz - 1))
	wall(root, Vector3.new(hx * 2 + 4, WALL_H, 2), Vector3.new(cx, midY, cz + hz + 1))
	wall(root, Vector3.new(2, WALL_H, hz * 2 + 4), Vector3.new(cx - hx - 1, midY, cz))
	wall(root, Vector3.new(2, WALL_H, hz * 2 + 4), Vector3.new(cx + hx + 1, midY, cz))
	wall(root, Vector3.new(hx * 2 + 4, 2, hz * 2 + 4), Vector3.new(cx, groundY + WALL_H, cz))
	-- 바닥 아래 안전판 (모델 바닥에 구멍이 있어도 떨어지지 않게)
	local floor = wall(root, Vector3.new(hx * 2 + 4, 2, hz * 2 + 4), Vector3.new(cx, groundY - 1.2, cz))
	floor.Name = "CitySafetyFloor"

	-- 먼 배경: 도시 둘레의 낮은 산 능선 (대기 안개에 실루엣으로 보이도록 어두운 녹갈색, 충돌·판정 없음)
	local backdrop = Instance.new("Folder")
	backdrop.Name = "Backdrop"
	backdrop.Parent = root
	local rng = Random.new(1957)
	local ringR = math.max(bsize.X, bsize.Z) / 2 + 260
	local count = 28
	for i = 1, count do
		local ang = (i / count) * math.pi * 2 + rng:NextNumber(-0.06, 0.06)
		local h = rng:NextNumber(90, 210)
		local w = rng:NextNumber(220, 360)
		local r = ringR + rng:NextNumber(-40, 80)
		local pos = Vector3.new(cx + math.cos(ang) * r, groundY + h / 2 - 6, cz + math.sin(ang) * r)
		local face = CFrame.lookAt(pos, Vector3.new(cx, pos.Y, cz))
		for k = -1, 1, 2 do
			local wdg = Instance.new("WedgePart")
			wdg.Name = "Ridge"
			wdg.Anchored = true
			wdg.CanCollide = false
			wdg.CanQuery = false
			wdg.CanTouch = false
			wdg.CastShadow = false
			wdg.Material = Enum.Material.Ground
			wdg.Color = Color3.fromRGB(62 + rng:NextInteger(-8, 8), 66 + rng:NextInteger(-8, 8), 52)
			wdg.Size = Vector3.new(w * 0.9, h, w / 2)
			-- 쐐기 두 개를 등지게 붙여 삼각 능선
			wdg.CFrame = face * CFrame.new(0, 0, -k * w / 4) * CFrame.Angles(0, k == 1 and 0 or math.pi, 0)
			wdg.Parent = backdrop
		end
	end
	local base = Instance.new("Part")
	base.Name = "OuterGround"
	base.Anchored = true
	base.CanCollide = false
	base.CanQuery = false
	base.CastShadow = false
	base.Material = Enum.Material.Ground
	base.Color = Color3.fromRGB(72, 70, 58)
	base.Size = Vector3.new(ringR * 2.4, 1, ringR * 2.4)
	base.Position = Vector3.new(cx, groundY - 3, cz)
	base.Parent = backdrop

	-- 진영 축: 긴 쪽
	local function axisPos(a, b) -- a = 진영 축 좌표, b = 옆 축 좌표
		if swap then
			return Vector3.new(cx + b, groundY, cz + a)
		end
		return Vector3.new(cx + a, groundY, cz + b)
	end
	local along = swap and hz or hx
	local function axisOf(c)
		local d = c.Position - ORIGIN
		return swap and d.Z or d.X, swap and d.X or d.Z
	end

	-- 스폰: 양 끝 거리 18 이내의 바닥 셀 중 옆으로 흩어진 5곳
	local function pickEnd(sign)
		local cand = {}
		for _, c in ipairs(list) do
			local a = axisOf(c)
			if a * sign > along - 22 then
				table.insert(cand, c)
			end
		end
		table.sort(cand, function(p, q)
			local _, bp = axisOf(p)
			local _, bq = axisOf(q)
			return bp < bq
		end)
		local out = {}
		local n = #cand
		for i = 1, 5 do
			local c = cand[math.max(1, math.floor(n * (i - 0.5) / 5 + 0.5))]
			if c then
				local pos = c.Position + Vector3.new(0, 3.5, 0)
				table.insert(out, CFrame.lookAt(pos, Vector3.new(cx, pos.Y, cz)))
			end
		end
		if #out == 0 then
			local pos = axisPos(sign * (along - 10), 0) + Vector3.new(0, 4, 0)
			table.insert(out, CFrame.lookAt(pos, Vector3.new(cx, pos.Y, cz)))
		end
		return out
	end
	local spawns = { [1] = pickEnd(-1), [2] = pickEnd(1) }

	-- 셀 중 목표 지점에 가장 가까운 바닥
	local function nearestGround(target)
		local bestC, bestD = nil, math.huge
		for _, c in ipairs(list) do
			local d = (Vector3.new(c.Position.X, 0, c.Position.Z) - Vector3.new(target.X, 0, target.Z)).Magnitude
			if d < bestD then
				bestC, bestD = c, d
			end
		end
		return bestC and (bestC.Position + Vector3.new(0, 0.2, 0)) or target
	end
	local side = swap and hx or hz
	local solo = {}
	for _, p in ipairs({ { -0.9, 0 }, { 0.9, 0 }, { 0, 0.8 }, { 0, -0.8 }, { -0.5, 0.7 }, { 0.5, -0.7 }, { 0.5, 0.7 }, { -0.5, -0.7 } }) do
		local g = nearestGround(axisPos(p[1] * along, p[2] * side)) + Vector3.new(0, 3.5, 0)
		table.insert(solo, CFrame.lookAt(g, Vector3.new(cx, g.Y, cz)))
	end
	local missionSpots = {}
	for _, p in ipairs({ { 0, 0 }, { -0.35, 0.5 }, { 0.35, -0.5 }, { -0.35, -0.5 }, { 0.35, 0.5 }, { 0, 0.6 }, { 0, -0.6 }, { -0.5, 0 }, { 0.5, 0 } }) do
		table.insert(missionSpots, nearestGround(axisPos(p[1] * along, p[2] * side)))
	end

	print(string.format("[SplashFront] 시가전 맵 준비: 바닥 셀 %d개, 도로 높이 %.1f, 전투 구역 %dx%d", #list, groundY, hx * 2, hz * 2))
	return {
		Id = "BigCity",
		Name = "시가전",
		Folder = root,
		Geometry = model,
		Cells = cells,
		Spawns = spawns,
		SoloSpawns = solo,
		FlagPoints = {
			{ Name = "A", Position = nearestGround(axisPos(0, -0.55 * side)) },
			{ Name = "C", Position = nearestGround(axisPos(0, 0)) },
			{ Name = "B", Position = nearestGround(axisPos(0, 0.55 * side)) },
		},
		MissionSpots = missionSpots,
		BaseCenters = { [1] = axisPos(-(along - 10), 0), [2] = axisPos(along - 10, 0) },
		KillY = groundY - 40,
		Lighting = "City",
		NoTextures = true,
		Realistic = true,
		TeamBanners = {},
	}
end

return CityMap
