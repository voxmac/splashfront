-- 로비와 아레나(크로마 스퀘어)를 코드로 생성
-- 새 맵은 BuildXXX 함수를 추가하고 같은 형태의 info 테이블을 돌려주면 됨
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Lighting = game:GetService("Lighting")
local CollectionService = game:GetService("CollectionService")
local Config = require(ReplicatedStorage.Shared.Config)

local MapBuilder = {}

local CELL = Config.CellSize

local function part(props)
	local p = Instance.new(props.Wedge and "WedgePart" or "Part")
	p.Anchored = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Material = props.Material or Enum.Material.SmoothPlastic
	p.Color = props.Color or Color3.fromRGB(80, 84, 96)
	p.Size = props.Size
	if props.CFrame then
		p.CFrame = props.CFrame
	else
		p.Position = props.Position
	end
	p.Name = props.Name or "Part"
	if props.Transparency then
		p.Transparency = props.Transparency
	end
	if props.CanCollide == false then
		p.CanCollide = false
	end
	if props.CanQuery == false then
		p.CanQuery = false
	end
	if props.Shape then
		p.Shape = props.Shape
	end
	p.Parent = props.Parent
	return p
end

local function label(parentPart, text, face, textSize)
	local gui = Instance.new("SurfaceGui")
	gui.Face = face or Enum.NormalId.Front
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 40
	gui.Parent = parentPart
	local t = Instance.new("TextLabel")
	t.Size = UDim2.fromScale(1, 1)
	t.BackgroundTransparency = 1
	t.TextColor3 = Color3.new(1, 1, 1)
	t.Font = Enum.Font.GothamBlack
	t.TextScaled = true
	t.Text = text
	t.Name = "Label"
	t.Parent = gui
	return t
end

local function billboard(adornee, text, height)
	local b = Instance.new("BillboardGui")
	b.Size = UDim2.fromOffset(260, 70)
	b.StudsOffset = Vector3.new(0, height or 4, 0)
	b.AlwaysOnTop = false
	b.MaxDistance = 120
	b.Adornee = adornee
	b.Parent = adornee
	local t = Instance.new("TextLabel")
	t.Size = UDim2.fromScale(1, 1)
	t.BackgroundTransparency = 1
	t.TextColor3 = Color3.new(1, 1, 1)
	t.TextStrokeTransparency = 0.3
	t.Font = Enum.Font.GothamBlack
	t.TextScaled = true
	t.Text = text
	t.Name = "Label"
	t.Parent = b
	return t
end

-- 경사로: x1(낮은 쪽)에서 x2(높은 쪽)으로 height만큼 오르는 판
local function ramp(parent, x1, x2, z, width, baseY, height)
	local len = math.abs(x2 - x1)
	local slope = math.sqrt(len * len + height * height)
	local angle = math.atan(height / len)
	if x2 < x1 then
		angle = -angle
	end
	local mid = Vector3.new((x1 + x2) / 2, baseY + height / 2 - 0.5, z)
	return part({
		Name = "Ramp", Parent = parent, Size = Vector3.new(slope, 1, width),
		CFrame = CFrame.new(mid) * CFrame.Angles(0, 0, angle),
		Color = Color3.fromRGB(120, 126, 140), Material = Enum.Material.DiamondPlate,
	})
end

function MapBuilder.SetupLighting()
	Lighting.ClockTime = 17.6 -- 노을빛 네온 분위기
	Lighting.Brightness = 2.2
	Lighting.Ambient = Color3.fromRGB(90, 90, 110)
	Lighting.OutdoorAmbient = Color3.fromRGB(140, 140, 160)
	Lighting.GlobalShadows = true
	if not Lighting:FindFirstChildOfClass("Atmosphere") then
		local a = Instance.new("Atmosphere")
		a.Density = 0.25
		a.Color = Color3.fromRGB(220, 200, 255)
		a.Decay = Color3.fromRGB(120, 80, 160)
		a.Parent = Lighting
	end
	if not Lighting:FindFirstChildOfClass("Sky") then
		local sky = Instance.new("Sky")
		sky.SunAngularSize = 14
		sky.Parent = Lighting
	end
	if not Lighting:FindFirstChildOfClass("ColorCorrectionEffect") then
		local cc = Instance.new("ColorCorrectionEffect")
		cc.Saturation = 0.18
		cc.Contrast = 0.08
		cc.TintColor = Color3.fromRGB(255, 244, 250)
		cc.Parent = Lighting
	end
	if not Lighting:FindFirstChildOfClass("SunRaysEffect") then
		local rays = Instance.new("SunRaysEffect")
		rays.Intensity = 0.06
		rays.Parent = Lighting
	end
	if not Lighting:FindFirstChildOfClass("BloomEffect") then
		local b = Instance.new("BloomEffect")
		b.Intensity = 0.6
		b.Threshold = 1.4
		b.Parent = Lighting
	end
end

-- 기획서 3장: 엄폐물은 어두운 외곽선으로 바닥과 구분
local OUTLINED = { Crate = true, Wall = true, WarehouseWall = true, Container = true, Parapet = true, WallSill = true }
local function addOutlines(folder)
	for _, p in ipairs(folder:GetDescendants()) do
		if p:IsA("BasePart") and OUTLINED[p.Name] then
			local sb = Instance.new("SelectionBox")
			sb.Adornee = p
			sb.Color3 = Color3.fromRGB(12, 12, 20)
			sb.LineThickness = 0.06
			sb.SurfaceTransparency = 1
			sb.Parent = p
		end
	end
end

------------------------------------------------------------------------
-- 로비
------------------------------------------------------------------------
function MapBuilder.BuildLobby()
	local old = workspace:FindFirstChild("Lobby")
	if old then
		old:Destroy()
	end
	local lobby = Instance.new("Folder")
	lobby.Name = "Lobby"
	lobby.Parent = workspace

	local Y = 400
	part({ Name = "Floor", Parent = lobby, Size = Vector3.new(120, 2, 90), Position = Vector3.new(0, Y - 1, 0),
		Color = Color3.fromRGB(34, 36, 48), Material = Enum.Material.Slate })
	-- 네온 테두리
	for _, s in ipairs({ -1, 1 }) do
		part({ Name = "Trim", Parent = lobby, Size = Vector3.new(120, 0.4, 1), Position = Vector3.new(0, Y + 0.2, s * 44.5),
			Color = Config.Teams[1].Color, Material = Enum.Material.Neon })
		part({ Name = "Trim", Parent = lobby, Size = Vector3.new(1, 0.4, 90), Position = Vector3.new(s * 59.5, Y + 0.2, 0),
			Color = Config.Teams[2].Color, Material = Enum.Material.Neon })
		part({ Name = "Wall", Parent = lobby, Size = Vector3.new(120, 20, 1), Position = Vector3.new(0, Y + 10, s * 45.5),
			Transparency = 1 })
		part({ Name = "Wall", Parent = lobby, Size = Vector3.new(1, 20, 90), Position = Vector3.new(s * 60.5, Y + 10, 0),
			Transparency = 1 })
	end

	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "LobbySpawn"
	spawn.Anchored = true
	spawn.Neutral = true
	spawn.Duration = 0
	spawn.Size = Vector3.new(12, 1, 12)
	spawn.Position = Vector3.new(0, Y + 0.5, 25)
	spawn.Color = Color3.fromRGB(255, 255, 255)
	spawn.Material = Enum.Material.Neon
	spawn.TopSurface = Enum.SurfaceType.Smooth
	spawn.Parent = lobby

	-- 타이틀
	local title = part({ Name = "TitleBoard", Parent = lobby, Size = Vector3.new(40, 8, 1),
		Position = Vector3.new(0, Y + 14, -44), Color = Color3.fromRGB(20, 20, 30) })
	label(title, Config.GameName, Enum.NormalId.Back)

	-- 매치 대기 발판
	local pads = {}
	local n = #Config.Queues
	for i, q in ipairs(Config.Queues) do
		local x = (i - (n + 1) / 2) * 18
		local mode = Config.Modes[q.Mode]
		local pad = part({ Name = "QueuePad_" .. q.Id, Parent = lobby, Size = Vector3.new(12, 0.6, 12),
			Position = Vector3.new(x, Y + 0.3, -18), Color = (i % 2 == 0) and Config.Teams[2].Color or Config.Teams[1].Color,
			Material = Enum.Material.Neon })
		pad.Transparency = 0.25
		pad:SetAttribute("QueueId", q.Id)
		local title2 = q.Mode == "Solo" and "솔로 8인" or (mode.Name .. "\n" .. q.TeamSize .. " vs " .. q.TeamSize)
		if q.Ranked then
			title2 = title2 .. "\n[랭크]"
		end
		local lbl = billboard(pad, title2, 5)
		lbl.Name = "QueueLabel"
		pads[q.Id] = pad
	end

	-- 랭킹 전광판
	local board = part({ Name = "Leaderboard", Parent = lobby, Size = Vector3.new(26, 18, 1),
		Position = Vector3.new(-45, Y + 10, 0), Color = Color3.fromRGB(16, 16, 24) })
	board.CFrame = CFrame.new(board.Position) * CFrame.Angles(0, math.rad(90), 0)
	local gui = Instance.new("SurfaceGui")
	gui.Name = "BoardGui"
	gui.Face = Enum.NormalId.Front
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 30
	gui.Parent = board
	local list = Instance.new("TextLabel")
	list.Name = "List"
	list.Size = UDim2.fromScale(1, 1)
	list.BackgroundTransparency = 1
	list.TextColor3 = Color3.new(1, 1, 1)
	list.Font = Enum.Font.GothamBold
	list.TextSize = 34
	list.TextXAlignment = Enum.TextXAlignment.Left
	list.TextYAlignment = Enum.TextYAlignment.Top
	list.Text = "랭킹 불러오는 중..."
	list.Parent = gui

	return {
		Folder = lobby,
		Spawn = spawn,
		SpawnCFrame = CFrame.new(0, Y + 4, 25),
		QueuePads = pads,
		Leaderboard = list,
	}
end

------------------------------------------------------------------------
-- 아레나 : 크로마 스퀘어 (기획서 8장 배치도와 동일)
------------------------------------------------------------------------
local HALF_X, HALF_Z = 80, 56

-- {중심x, 중심z, 크기x, 크기z, 높이, 종류}  종류: wall / crate / block
-- 왼쪽(A팀) 절반만 정의하고 x를 뒤집어 오른쪽을 만듦. 가운데(x=0) 요소는 mirror=false
local OBSTACLES = {
	{ 0, 22, 36, 2, 8, "wall", false },
	{ 0, -22, 36, 2, 8, "wall", false },
	{ -34, 12, 2, 12, 8, "wall" },
	{ -34, -12, 2, 12, 8, "wall" },
	{ -79, 0, 2, 32, 10, "wall" },
	{ -46, 0, 4, 4, 3, "crate" },
	{ -50, 22, 4, 4, 3, "crate" },
	{ -50, -22, 4, 4, 3, "crate" },
	{ -28, 32, 4, 4, 3, "crate" },
	{ -28, -32, 4, 4, 3, "crate" },
	{ -22, 0, 4, 4, 3, "crate" },
	{ -8, 38, 4, 4, 3, "crate" },
	{ -8, -38, 4, 4, 3, "crate" },
	{ -64, 30, 6, 2, 3, "crate" },
	{ -64, -30, 6, 2, 3, "crate" },
}

-- 높은 지형 (위에 셀이 깔림): {중심x, 중심z, 크기x, 크기z, 높이}
local PLATFORMS = {
	{ 0, 0, 20, 20, 3, false },         -- 중앙 고지대
	{ -56, 40, 8, 8, 7 },               -- 저격 타워
	{ -56, -40, 8, 8, 7 },
	{ -73, 0, 10, 28, 1 },              -- 베이스
}

local function mirrored(list)
	local out = {}
	for _, o in ipairs(list) do
		table.insert(out, o)
		local mirror = o[7]
		if #o == 6 then
			mirror = o[6]
		end
		if o[1] ~= 0 and mirror ~= false then
			local copy = {}
			for i, v in ipairs(o) do
				copy[i] = v
			end
			copy[1] = -o[1]
			copy.Mirror = true
			table.insert(out, copy)
		end
	end
	return out
end

------------------------------------------------------------------------
-- 아트 패스: 도시 배경, 가로등, 베이스 배너, 전광판 (게임플레이 영향 없음)
------------------------------------------------------------------------
local function decorate(geo)
	local deco = Instance.new("Folder")
	deco.Name = "Decoration"
	deco.Parent = geo
	local rng = Random.new(2026) -- 항상 같은 도시가 나오도록 고정 시드
	local neon = { Config.Teams[1].Color, Config.Teams[2].Color, Color3.fromRGB(255, 196, 0), Color3.fromRGB(140, 90, 255) }

	-- 1) 경기장 밖 빌딩 숲
	local function building(x, z, w, d)
		local h = rng:NextInteger(26, 70)
		local b = part({ Name = "Building", Parent = deco, Size = Vector3.new(w, h, d), Position = Vector3.new(x, h / 2, z),
			Color = Color3.fromRGB(rng:NextInteger(26, 44), rng:NextInteger(26, 40), rng:NextInteger(40, 60)), Material = Enum.Material.Concrete })
		b.CanQuery = false
		local c = neon[rng:NextInteger(1, #neon)]
		-- 창문 띠
		local y = 6
		while y < h - 4 do
			if rng:NextNumber() < 0.55 then
				part({ Name = "Window", Parent = deco, Size = Vector3.new(w + 0.2, 0.6, d + 0.2), Position = Vector3.new(x, y, z),
					Color = c, Material = Enum.Material.Neon, CanCollide = false, CanQuery = false }).Transparency = 0.35
			end
			y = y + rng:NextInteger(4, 7)
		end
		-- 옥상 네온 간판
		if rng:NextNumber() < 0.35 then
			part({ Name = "RoofSign", Parent = deco, Size = Vector3.new(w * 0.7, 3, 0.6), Position = Vector3.new(x, h + 2, z),
				Color = c, Material = Enum.Material.Neon, CanCollide = false, CanQuery = false })
		end
	end
	for x = -110, 110, 22 do
		building(x + rng:NextInteger(-3, 3), -86 - rng:NextInteger(0, 12), rng:NextInteger(12, 18), rng:NextInteger(12, 18))
		building(x + rng:NextInteger(-3, 3), 86 + rng:NextInteger(0, 12), rng:NextInteger(12, 18), rng:NextInteger(12, 18))
	end
	for z = -66, 66, 22 do
		building(-118 - rng:NextInteger(0, 10), z, rng:NextInteger(12, 18), rng:NextInteger(12, 18))
		building(118 + rng:NextInteger(0, 10), z, rng:NextInteger(12, 18), rng:NextInteger(12, 18))
	end
	part({ Name = "CityGround", Parent = deco, Size = Vector3.new(320, 1, 260), Position = Vector3.new(0, -2.5, 0),
		Color = Color3.fromRGB(30, 30, 38), Material = Enum.Material.Asphalt, CanQuery = false })

	-- 2) 외벽 위 가로등 (조명)
	for _, x in ipairs({ -60, -20, 20, 60 }) do
		for _, s in ipairs({ -1, 1 }) do
			local pole = part({ Name = "LampPole", Parent = deco, Size = Vector3.new(0.6, 8, 0.6), Position = Vector3.new(x, 20, s * 57),
				Color = Color3.fromRGB(40, 40, 50), Material = Enum.Material.Metal, CanQuery = false })
			pole.CanCollide = false
			local head = part({ Name = "Lamp", Parent = deco, Size = Vector3.new(3, 0.6, 1.4), Position = Vector3.new(x, 24.2, s * 56),
				Color = Color3.fromRGB(255, 240, 220), Material = Enum.Material.Neon, CanCollide = false, CanQuery = false })
			local light = Instance.new("SpotLight")
			light.Face = Enum.NormalId.Bottom
			light.Range = 40
			light.Angle = 80
			light.Brightness = 2.2
			light.Color = Color3.fromRGB(255, 235, 215)
			light.Parent = head
		end
	end

	-- 3) 베이스 위 팀 배너
	for i, t in ipairs(Config.Teams) do
		local x = (i == 1) and -79 or 79
		local banner = part({ Name = "TeamBanner", Parent = deco, Size = Vector3.new(1, 8, 26), Position = Vector3.new(x, 16, 0),
			Color = t.Color, Material = Enum.Material.Neon, CanQuery = false })
		banner.CanCollide = false
		banner.Transparency = 0.1
		label(banner, t.Name, i == 1 and Enum.NormalId.Right or Enum.NormalId.Left).TextColor3 = Color3.fromRGB(20, 20, 30)
	end

	-- 4) 중앙 상공 전광판 (점수·시간 실시간 표시, 양면)
	local screen = part({ Name = "Jumbotron", Parent = deco, Size = Vector3.new(1, 9, 24), Position = Vector3.new(0, 30, 0),
		Color = Color3.fromRGB(10, 10, 16), Material = Enum.Material.SmoothPlastic, CanQuery = false })
	screen.CanCollide = false
	local labels = {}
	for _, face in ipairs({ Enum.NormalId.Left, Enum.NormalId.Right }) do
		local t = label(screen, "SPLASH FRONT", face)
		t.Font = Enum.Font.GothamBlack
		table.insert(labels, t)
	end
	part({ Name = "JumboFrame", Parent = deco, Size = Vector3.new(0.8, 9.6, 24.6), Position = Vector3.new(0, 30, 0),
		Color = Config.Teams[1].Color, Material = Enum.Material.Neon, CanCollide = false, CanQuery = false }).Transparency = 0.6
	return labels
end

function MapBuilder.BuildArena()
	local old = workspace:FindFirstChild("Arena")
	if old then
		old:Destroy()
	end
	local arena = Instance.new("Folder")
	arena.Name = "Arena"
	arena.Parent = workspace
	local geo = Instance.new("Folder")
	geo.Name = "Geometry"
	geo.Parent = arena
	local cells = Instance.new("Folder")
	cells.Name = "Cells"
	cells.Parent = arena

	-- 바닥
	part({ Name = "Floor", Parent = geo, Size = Vector3.new(HALF_X * 2 + 8, 2, HALF_Z * 2 + 8), Position = Vector3.new(0, -1, 0),
		Color = Color3.fromRGB(70, 72, 82), Material = Enum.Material.Concrete })
	-- 외벽 + 네온 라인
	for _, s in ipairs({ -1, 1 }) do
		part({ Name = "Boundary", Parent = geo, Size = Vector3.new(HALF_X * 2 + 8, 16, 2), Position = Vector3.new(0, 8, s * (HALF_Z + 1)),
			Color = Color3.fromRGB(44, 46, 58), Material = Enum.Material.Metal })
		part({ Name = "Boundary", Parent = geo, Size = Vector3.new(2, 16, HALF_Z * 2 + 8), Position = Vector3.new(s * (HALF_X + 1), 8, 0),
			Color = Color3.fromRGB(44, 46, 58), Material = Enum.Material.Metal })
		part({ Name = "NeonLine", Parent = geo, Size = Vector3.new(HALF_X * 2 + 8, 0.5, 0.3), Position = Vector3.new(0, 15.5, s * HALF_Z),
			Color = Config.Teams[s == -1 and 1 or 2].Color, Material = Enum.Material.Neon, CanCollide = false, CanQuery = false })
	end
	-- 투명 천장(지붕 위로 나가지 않게)
	part({ Name = "Ceiling", Parent = geo, Size = Vector3.new(HALF_X * 2 + 8, 2, HALF_Z * 2 + 8), Position = Vector3.new(0, 40, 0),
		Transparency = 1, CanQuery = false })

	local blocked = {} -- 셀을 깔지 않을 바닥 영역
	local function block(cx, cz, sx, sz)
		table.insert(blocked, { cx - sx / 2, cx + sx / 2, cz - sz / 2, cz + sz / 2 })
	end

	-- 장애물
	for _, o in ipairs(mirrored(OBSTACLES)) do
		local cx, cz, sx, sz, h, kind = o[1], o[2], o[3], o[4], o[5], o[6]
		local color, mat
		if kind == "wall" then
			color, mat = Color3.fromRGB(52, 54, 70), Enum.Material.Metal
		else
			color, mat = Color3.fromRGB(160, 120, 70), Enum.Material.WoodPlanks
		end
		local p = part({ Name = kind == "wall" and "Wall" or "Crate", Parent = geo, Size = Vector3.new(sx, h, sz),
			Position = Vector3.new(cx, h / 2, cz), Color = color, Material = mat })
		p:SetAttribute("Cover", kind)
		if kind == "wall" then
			-- 벽 윗선 네온
			part({ Name = "WallTrim", Parent = geo, Size = Vector3.new(sx + 0.1, 0.3, sz + 0.1), Position = Vector3.new(cx, h + 0.15, cz),
				Color = Color3.fromRGB(255, 255, 255), Material = Enum.Material.Neon, CanQuery = false })
		end
		block(cx, cz, sx, sz)
	end

	-- 플랫폼 + 그 위 셀
	local function addCells(x1, x2, z1, z2, y)
		local x = x1 + CELL / 2
		while x < x2 do
			local z = z1 + CELL / 2
			while z < z2 do
				local free = true
				if y < 0.5 then
					for _, b in ipairs(blocked) do
						if x > b[1] - 0.5 and x < b[2] + 0.5 and z > b[3] - 0.5 and z < b[4] + 0.5 then
							free = false
							break
						end
					end
				end
				if free then
					local c = part({ Name = "Cell", Parent = cells, Size = Vector3.new(CELL - 0.08, 0.2, CELL - 0.08),
						Position = Vector3.new(x, y + 0.1, z), Color = Config.NeutralColor, Material = Enum.Material.SmoothPlastic,
						CanCollide = false })
					c.CanTouch = false
					c.CastShadow = false
					c:SetAttribute("Owner", 0)
				end
				z = z + CELL
			end
			x = x + CELL
		end
	end

	for _, pl in ipairs(mirrored(PLATFORMS)) do
		local cx, cz, sx, sz, h = pl[1], pl[2], pl[3], pl[4], pl[5]
		part({ Name = "Platform", Parent = geo, Size = Vector3.new(sx, h, sz), Position = Vector3.new(cx, h / 2, cz),
			Color = Color3.fromRGB(96, 100, 116), Material = Enum.Material.Concrete })
		block(cx, cz, sx, sz)
		addCells(cx - sx / 2, cx + sx / 2, cz - sz / 2, cz + sz / 2, h)
	end

	-- 경사로
	ramp(geo, -16, -10, 0, 8, 0, 3)
	ramp(geo, 16, 10, 0, 8, 0, 3)
	for _, s in ipairs({ 1, -1 }) do
		ramp(geo, -74 * 1, -60, 40 * s, 4, 0, 7)
		ramp(geo, 74, 60, 40 * s, 4, 0, 7)
		-- 타워 앞쪽 흉벽(앉으면 숨는 높이)
		part({ Name = "Parapet", Parent = geo, Size = Vector3.new(1, 2.6, 8), Position = Vector3.new(-52.5, 8.3, 40 * s),
			Color = Config.Teams[1].Color, Material = Enum.Material.Glass, })
		part({ Name = "Parapet", Parent = geo, Size = Vector3.new(1, 2.6, 8), Position = Vector3.new(52.5, 8.3, 40 * s),
			Color = Config.Teams[2].Color, Material = Enum.Material.Glass })
	end

	block(-13, 0, 6, 8)
	block(13, 0, 6, 8)
	for _, s in ipairs({ 1, -1 }) do
		block(-67, 40 * s, 14, 4)
		block(67, 40 * s, 14, 4)
	end

	local jumbotron = decorate(geo)

	-- 바닥 셀
	addCells(-HALF_X, HALF_X, -HALF_Z, HALF_Z, 0)

	-- 스폰 위치 (베이스 위)
	local spawns = { [1] = {}, [2] = {} }
	for i = 0, 4 do
		local z = -10 + i * 5
		table.insert(spawns[1], CFrame.lookAt(Vector3.new(-73, 4, z), Vector3.new(0, 4, z)))
		table.insert(spawns[2], CFrame.lookAt(Vector3.new(73, 4, z), Vector3.new(0, 4, z)))
	end
	-- 솔로 모드: 맵 가장자리 8곳
	local solo = {}
	local soloPts = { { -73, 0 }, { 73, 0 }, { 0, 48 }, { 0, -48 }, { -40, 48 }, { 40, -48 }, { 40, 48 }, { -40, -48 } }
	for _, p in ipairs(soloPts) do
		local y = (math.abs(p[1]) > 68) and 4 or 3
		table.insert(solo, CFrame.lookAt(Vector3.new(p[1], y, p[2]), Vector3.new(0, y, 0)))
	end

	local flags = {
		{ Name = "A", Position = Vector3.new(0, 0, -40) },
		{ Name = "C", Position = Vector3.new(0, 3, 0) },
		{ Name = "B", Position = Vector3.new(0, 0, 40) },
	}

	local missionSpots = {
		Vector3.new(0, 3, 0), Vector3.new(-30, 0, 44), Vector3.new(30, 0, -44), Vector3.new(-30, 0, -44),
		Vector3.new(30, 0, 44), Vector3.new(0, 0, 40), Vector3.new(0, 0, -40), Vector3.new(-40, 0, 0), Vector3.new(40, 0, 0),
	}

	addOutlines(geo)
	return {
		Id = "ChromaSquare",
		Name = "크로마 스퀘어",
		KillY = -40,
		Folder = arena,
		Geometry = geo,
		Cells = cells,
		Spawns = spawns,
		SoloSpawns = solo,
		FlagPoints = flags,
		MissionSpots = missionSpots,
		BaseCenters = { [1] = Vector3.new(-73, 1, 0), [2] = Vector3.new(73, 1, 0) },
		Jumbotron = jumbotron,
	}
end

------------------------------------------------------------------------
-- 맵 2: 스카이 루프탑
-- 고층 빌딩 옥상 3동(가운데 + 양 팀 스폰 빌딩) 사이를 경사로·점프패드·집라인으로 잇는 수직 맵.
-- 중앙에는 컨테이너·박스로 가득한 창고(1층 실내전 + 지붕 고지대)와 벽 아래 '저격 구멍'.
-- 빌딩 사이로 떨어지면 탈락(KillY). 좌표는 옥상 기준 상대좌표 → skyPos로 변환
------------------------------------------------------------------------
local SKY_Y = 150                         -- 가운데 옥상 바닥 높이
local SKY_O = Vector3.new(0, 0, 700)      -- 크로마 스퀘어와 겹치지 않게 떨어진 위치

local function skyPos(x, y, z)
	return Vector3.new(SKY_O.X + x, SKY_Y + y, SKY_O.Z + z)
end

function MapBuilder.BuildSkyRooftop()
	local old = workspace:FindFirstChild("SkyRooftop")
	if old then
		old:Destroy()
	end
	local root = Instance.new("Folder")
	root.Name = "SkyRooftop"
	root.Parent = workspace
	local geo = Instance.new("Folder")
	geo.Name = "Geometry"
	geo.Parent = root
	local cells = Instance.new("Folder")
	cells.Name = "Cells"
	cells.Parent = root
	local deco = Instance.new("Folder")
	deco.Name = "Decoration"
	deco.Parent = root

	local CONCRETE = Color3.fromRGB(78, 80, 92)
	local METAL = Color3.fromRGB(118, 108, 92)
	local blocked = {}

	local function block(level, cx, cz, sx, sz)
		table.insert(blocked, { level, cx - sx / 2, cx + sx / 2, cz - sz / 2, cz + sz / 2 })
	end

	-- 상대좌표 상자: 바닥 y1에서 높이 h
	local function box(name, cx, y1, cz, sx, h, sz, color, mat, parent)
		return part({ Name = name, Parent = parent or geo, Size = Vector3.new(sx, h, sz), Position = skyPos(cx, y1 + h / 2, cz),
			Color = color or CONCRETE, Material = mat or Enum.Material.Concrete })
	end

	-- 바닥 셀 깔기 (같은 높이의 장애물 자리는 제외)
	local function cellsOn(x1, x2, z1, z2, y)
		local x = x1 + CELL / 2
		while x < x2 do
			local z = z1 + CELL / 2
			while z < z2 do
				local free = true
				for _, b in ipairs(blocked) do
					if math.abs(b[1] - y) < 0.5 and x > b[2] - 0.5 and x < b[3] + 0.5 and z > b[4] - 0.5 and z < b[5] + 0.5 then
						free = false
						break
					end
				end
				if free then
					local c = part({ Name = "Cell", Parent = cells, Size = Vector3.new(CELL - 0.08, 0.2, CELL - 0.08),
						Position = skyPos(x, y + 0.1, z), Color = Config.NeutralColor, CanCollide = false })
					c.CanTouch = false
					c.CastShadow = false
					c:SetAttribute("Owner", 0)
				end
				z = z + CELL
			end
			x = x + CELL
		end
	end

	-- 경사로 + 난간 (xLow 높이 y0 → xHigh 높이 y0+h)
	local function skyRamp(xLow, xHigh, z, width, y0, h)
		local len = math.abs(xHigh - xLow)
		local slope = math.sqrt(len * len + h * h)
		local angle = math.atan(h / len)
		if xHigh < xLow then
			angle = -angle
		end
		local cf = CFrame.new(skyPos((xLow + xHigh) / 2, y0 + h / 2 - 0.5, z)) * CFrame.Angles(0, 0, angle)
		part({ Name = "Ramp", Parent = geo, Size = Vector3.new(slope, 1, width), CFrame = cf,
			Color = Color3.fromRGB(150, 150, 160), Material = Enum.Material.DiamondPlate })
		for _, side in ipairs({ -1, 1 }) do
			part({ Name = "Rail", Parent = geo, Size = Vector3.new(slope, 2.4, 0.4), CFrame = cf * CFrame.new(0, 1.7, side * (width / 2 + 0.2)),
				Color = Color3.fromRGB(255, 196, 0), Material = Enum.Material.Metal })
		end
	end

	-- 점프패드: 밟으면 launch 속도로 발사 (플레이어는 클라이언트, 봇은 서버가 처리)
	local function jumpPad(x, y, z, launch)
		local pad = part({ Name = "JumpPad", Parent = geo, Size = Vector3.new(6, 0.6, 6), Position = skyPos(x, y + 0.3, z),
			Color = Color3.fromRGB(0, 255, 220), Material = Enum.Material.Neon })
		pad:SetAttribute("Launch", launch)
		CollectionService:AddTag(pad, "SF_JumpPad")
		local ring = part({ Name = "PadRing", Parent = deco, Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.2, 7.5, 7.5),
			CFrame = CFrame.new(skyPos(x, y + 0.65, z)) * CFrame.Angles(0, 0, math.rad(90)), Color = Color3.fromRGB(255, 255, 255),
			Material = Enum.Material.Neon, CanCollide = false, CanQuery = false })
		ring.Transparency = 0.5
		local light = Instance.new("PointLight")
		light.Color = pad.Color
		light.Range = 12
		light.Brightness = 2
		light.Parent = pad
		local cooldown = {}
		pad.Touched:Connect(function(hit)
			local model = hit:FindFirstAncestorOfClass("Model")
			local bots = workspace:FindFirstChild("Bots")
			if not model or not bots or not model:IsDescendantOf(bots) then
				return
			end
			if cooldown[model] and os.clock() - cooldown[model] < 0.8 then
				return
			end
			cooldown[model] = os.clock()
			local r = model:FindFirstChild("HumanoidRootPart")
			if r then
				r.AssemblyLinearVelocity = launch
			end
		end)
		block(y, x, z, 6, 6)
		return pad
	end

	-- 집라인: 시작 기둥의 E 프롬프트로 탑승, from → to 로 미끄러져 내려감
	local function zipline(from, to, fromBase, toBase)
		local h1, h2 = from.Y - (SKY_Y + fromBase), to.Y - (SKY_Y + toBase)
		local startPole = part({ Name = "ZipStart", Parent = geo, Size = Vector3.new(0.8, h1, 0.8), Position = from - Vector3.new(0, h1 / 2, 0),
			Color = Color3.fromRGB(255, 196, 0), Material = Enum.Material.Metal })
		part({ Name = "ZipEnd", Parent = geo, Size = Vector3.new(0.8, h2, 0.8), Position = to - Vector3.new(0, h2 / 2, 0),
			Color = Color3.fromRGB(255, 196, 0), Material = Enum.Material.Metal })
		local len = (to - from).Magnitude
		part({ Name = "ZipCable", Parent = deco, Size = Vector3.new(0.25, 0.25, len), CFrame = CFrame.lookAt((from + to) / 2, to),
			Color = Color3.fromRGB(30, 30, 30), Material = Enum.Material.Metal, CanCollide = false, CanQuery = false })
		startPole:SetAttribute("ZipFrom", from)
		startPole:SetAttribute("ZipTo", to)
		CollectionService:AddTag(startPole, "SF_Zipline")
		local prompt = Instance.new("ProximityPrompt")
		prompt.ActionText = "집라인 타기"
		prompt.ObjectText = "집라인"
		prompt.KeyboardKeyCode = Enum.KeyCode.E
		prompt.HoldDuration = 0
		prompt.MaxActivationDistance = 10
		prompt.RequiresLineOfSight = false
		prompt.Parent = startPole
	end

	--------------------------------------------------------------------
	-- 빌딩 3동
	--------------------------------------------------------------------
	box("MidTower", 0, -SKY_Y, 0, 100, SKY_Y, 104, Color3.fromRGB(46, 48, 62))
	for _, s in ipairs({ -1, 1 }) do
		box("SpawnTower", 76 * s, -SKY_Y, 0, 20, SKY_Y + 8, 60, Color3.fromRGB(40, 42, 56))
	end
	-- 빌딩 외벽 네온 창문 띠
	local y = -12
	local band = 0
	while y > -SKY_Y + 10 do
		band = band + 1
		local c = (band % 2 == 0) and Config.Teams[1].Color or Config.Teams[2].Color
		part({ Name = "WindowBand", Parent = deco, Size = Vector3.new(100.4, 0.8, 104.4), Position = skyPos(0, y, 0), Color = c,
			Material = Enum.Material.Neon, CanCollide = false, CanQuery = false }).Transparency = 0.45
		for _, s in ipairs({ -1, 1 }) do
			part({ Name = "WindowBand", Parent = deco, Size = Vector3.new(20.4, 0.8, 60.4), Position = skyPos(76 * s, y + 6, 0),
				Color = Config.Teams[s == -1 and 1 or 2].Color, Material = Enum.Material.Neon, CanCollide = false, CanQuery = false }).Transparency = 0.45
		end
		y = y - 12
	end

	--------------------------------------------------------------------
	-- 옥상 가장자리 난간(앉으면 숨는 높이)
	--------------------------------------------------------------------
	for _, t in ipairs({ -1, 1 }) do
		box("Parapet", 0, 0, 51.5 * t, 100, 2.5, 1, CONCRETE)
		block(0, 0, 51.5 * t, 100, 1)
	end
	for _, s in ipairs({ -1, 1 }) do
		for _, seg in ipairs({ { -52, -25 }, { -19, 19 }, { 25, 52 } }) do
			local cz, len = (seg[1] + seg[2]) / 2, seg[2] - seg[1]
			box("Parapet", 49.5 * s, 0, cz, 1, 2.5, len, CONCRETE)
			block(0, 49.5 * s, cz, 1, len)
		end
		-- 스폰 빌딩 옥상: 뒤 벽(높음), 옆 난간, 앞 난간(경사로 자리 비움)
		local back = box("SpawnWall", 85.5 * s, 8, 0, 1, 6, 60, Color3.fromRGB(36, 36, 48))
		block(8, 85.5 * s, 0, 1, 60)
		label(back, "SKY ROOFTOP", s == -1 and Enum.NormalId.Right or Enum.NormalId.Left).TextColor3 = Config.Teams[s == -1 and 1 or 2].Color
		for _, t in ipairs({ -1, 1 }) do
			box("Parapet", 76 * s, 8, 29.5 * t, 20, 2.5, 1, CONCRETE)
			block(8, 76 * s, 29.5 * t, 20, 1)
		end
		for _, seg in ipairs({ { -30, -25 }, { -19, 19 }, { 25, 30 } }) do
			local cz, len = (seg[1] + seg[2]) / 2, seg[2] - seg[1]
			box("Parapet", 66.5 * s, 8, cz, 1, 2.5, len, CONCRETE)
			block(8, 66.5 * s, cz, 1, len)
		end
		-- 빌딩 사이 경사로 2개 (허공 위 다리)
		for _, t in ipairs({ -1, 1 }) do
			skyRamp(50 * s, 66 * s, 22 * t, 6, 0, 8)
		end
		-- 스폰 옥상 엄폐 박스
		for _, t in ipairs({ -1, 1 }) do
			box("Crate", 70 * s, 8, 12 * t, 4, 3, 4, Color3.fromRGB(160, 120, 70), Enum.Material.WoodPlanks)
			block(8, 70 * s, 12 * t, 4, 4)
		end
	end

	--------------------------------------------------------------------
	-- 중앙 창고 (1층 실내전 + 지붕 고지대, 벽 아래 저격 구멍)
	--------------------------------------------------------------------
	local W_H = 10
	local function wallX(z, x1, x2)    -- z 고정, x 방향 벽
		local cx, len = (x1 + x2) / 2, x2 - x1
		box("WarehouseWall", cx, 0, z, len, W_H, 1, METAL, Enum.Material.CorrodedMetal)
		block(0, cx, z, len, 1)
	end
	local function wallZ(x, z1, z2)    -- x 고정, z 방향 벽
		local cz, len = (z1 + z2) / 2, z2 - z1
		box("WarehouseWall", x, 0, cz, 1, W_H, len, METAL, Enum.Material.CorrodedMetal)
		block(0, x, cz, 1, len)
	end
	local function lintelX(z, x1, x2)
		box("Lintel", (x1 + x2) / 2, 7, z, x2 - x1, W_H - 7, 1, METAL, Enum.Material.CorrodedMetal)
	end
	local function lintelZ(x, z1, z2)
		box("Lintel", x, 7, (z1 + z2) / 2, 1, W_H - 7, z2 - z1, METAL, Enum.Material.CorrodedMetal)
	end
	for _, t in ipairs({ -1, 1 }) do
		local z = 13.5 * t
		-- 양 끝 구간은 바닥 1~2.4 높이가 뚫린 '저격 구멍' (앉아서 쏘는 낮은 틈)
		for _, seg in ipairs({ { -20, -12 }, { 12, 20 } }) do
			local cx, len = (seg[1] + seg[2]) / 2, seg[2] - seg[1]
			box("WallSill", cx, 0, z, len, 1, 1, METAL, Enum.Material.CorrodedMetal)
			box("WarehouseWall", cx, 2.4, z, len, W_H - 2.4, 1, METAL, Enum.Material.CorrodedMetal)
			block(0, cx, z, len, 1)
		end
		wallX(z, -6, 6)
		lintelX(z, -12, -6)
		lintelX(z, 6, 12)
	end
	for _, s in ipairs({ -1, 1 }) do
		local x = 19.5 * s
		wallZ(x, -14, -4)
		wallZ(x, 4, 14)
		lintelZ(x, -4, 4)
	end
	-- 지붕 (가운데 길쭉한 채광창 구멍)
	local roofParts = { { -20, -3, -14, 14 }, { 3, 20, -14, 14 }, { -3, 3, 10, 14 }, { -3, 3, -14, -10 } }
	for _, r in ipairs(roofParts) do
		box("WarehouseRoof", (r[1] + r[2]) / 2, W_H, (r[3] + r[4]) / 2, r[2] - r[1], 1, r[4] - r[3], Color3.fromRGB(96, 90, 80), Enum.Material.Metal)
	end
	-- 지붕 난간
	for _, t in ipairs({ -1, 1 }) do
		box("RoofRail", 0, W_H + 1, 13.75 * t, 40, 1.6, 0.5, Color3.fromRGB(255, 196, 0), Enum.Material.Metal)
		block(W_H + 1, 0, 13.75 * t, 40, 0.5)
		box("RoofRail", 19.75 * t, W_H + 1, 0, 0.5, 1.6, 28, Color3.fromRGB(255, 196, 0), Enum.Material.Metal)
		block(W_H + 1, 19.75 * t, 0, 0.5, 28)
	end
	-- 실내 박스 + 조명
	for _, s in ipairs({ -1, 1 }) do
		for _, t in ipairs({ -1, 1 }) do
			box("Crate", 12 * s, 0, 7 * t, 4, 3, 4, Color3.fromRGB(160, 120, 70), Enum.Material.WoodPlanks)
			block(0, 12 * s, 7 * t, 4, 4)
		end
		local lamp = part({ Name = "CeilingLamp", Parent = deco, Size = Vector3.new(4, 0.3, 1), Position = skyPos(10 * s, W_H - 0.4, 0),
			Color = Color3.fromRGB(255, 240, 210), Material = Enum.Material.Neon, CanCollide = false, CanQuery = false })
		local l = Instance.new("PointLight")
		l.Range = 22
		l.Brightness = 1.6
		l.Parent = lamp
	end

	--------------------------------------------------------------------
	-- 컨테이너 레인 + 컨테이너 2단 탑(깃발 A/B 고지대)
	--------------------------------------------------------------------
	local CONTAINER = { Color3.fromRGB(200, 90, 40), Color3.fromRGB(40, 110, 170), Color3.fromRGB(60, 140, 80), Color3.fromRGB(170, 40, 60) }
	for _, s in ipairs({ -1, 1 }) do
		for i, t in ipairs({ -1, 1 }) do
			box("Container", 34 * s, 0, 33 * t, 14, 7, 6, CONTAINER[i + (s == 1 and 2 or 0)], Enum.Material.CorrodedMetal)
			block(0, 34 * s, 33 * t, 14, 6)
		end
	end
	for i, t in ipairs({ -1, 1 }) do
		box("Container", 0, 0, 42 * t, 16, 6, 6, CONTAINER[i], Enum.Material.CorrodedMetal)
		box("Container", 0, 6, 42 * t, 16, 6, 6, CONTAINER[i + 2], Enum.Material.CorrodedMetal)
		block(0, 0, 42 * t, 16, 6)
	end

	-- 옥상 박스(절반 엄폐)
	for _, s in ipairs({ -1, 1 }) do
		for _, c in ipairs({ { -37, 0 }, { -40, 26 }, { -40, -26 }, { -28, 8 }, { -28, -8 }, { -12, 26 }, { -12, -26 },
			{ -44, 44 }, { -44, -44 }, { -14, 46 }, { -14, -46 } }) do
			box("Crate", c[1] * s, 0, c[2], 4, 3, 4, Color3.fromRGB(160, 120, 70), Enum.Material.WoodPlanks)
			block(0, c[1] * s, c[2], 4, 4)
		end
	end

	--------------------------------------------------------------------
	-- 점프패드
	--------------------------------------------------------------------
	for _, t in ipairs({ -1, 1 }) do
		jumpPad(0, 0, 7 * t, Vector3.new(0, 75, 8 * t))          -- 창고 안 → 채광창 위 지붕
		jumpPad(0, 0, 30 * t, Vector3.new(0, 80, 18 * t))        -- 레인 → 컨테이너 탑(깃발 A/B)
	end
	for _, s in ipairs({ -1, 1 }) do
		jumpPad(26 * s, 0, 0, Vector3.new(-14 * s, 75, 0))       -- 창고 정문 앞 → 창고 지붕
		jumpPad(45 * s, 0, 0, Vector3.new(42 * s, 78, 0))        -- 옥상 끝 → 허공 건너 스폰 빌딩 (스폰 난간 위로 넘김)
	end

	--------------------------------------------------------------------
	-- 집라인 (높은 곳 → 낮은 곳)
	--------------------------------------------------------------------
	for _, s in ipairs({ -1, 1 }) do
		for _, t in ipairs({ -1, 1 }) do
			-- 시뮬레이션으로 난간·경사로 난간·컨테이너와 안 부딪히는 높이/경로 확인
			zipline(skyPos(72 * s, 19, 20 * t), skyPos(26 * s, 7, 46 * t), 8, 0)    -- 스폰 옥상(경사로 입구 위) → 사이드 레인
			zipline(skyPos(6 * s, 20, 42 * t), skyPos(44 * s, 7, 16 * t), 12, 0)   -- 컨테이너 탑 → 옥상 가장자리
		end
	end

	--------------------------------------------------------------------
	-- 페인트 셀 (각 층)
	--------------------------------------------------------------------
	cellsOn(-50, 50, -52, 52, 0)                       -- 가운데 옥상 + 창고 1층
	for _, s in ipairs({ -1, 1 }) do
		local x1 = (s == -1) and -86 or 66
		cellsOn(x1, x1 + 20, -30, 30, 8)               -- 스폰 옥상
	end
	for _, r in ipairs(roofParts) do
		cellsOn(r[1], r[2], r[3], r[4], W_H + 1)       -- 창고 지붕
	end
	for _, t in ipairs({ -1, 1 }) do
		cellsOn(-8, 8, 42 * t - 3, 42 * t + 3, 12)     -- 컨테이너 탑 위
	end

	--------------------------------------------------------------------
	-- 배경: 발아래 도시 + 먼 스카이라인, 전광판, 옥상 조명
	--------------------------------------------------------------------
	local rng = Random.new(1750)
	local neon = { Config.Teams[1].Color, Config.Teams[2].Color, Color3.fromRGB(255, 196, 0), Color3.fromRGB(140, 90, 255) }
	part({ Name = "Street", Parent = deco, Size = Vector3.new(700, 1, 700), Position = Vector3.new(SKY_O.X, -0.5, SKY_O.Z),
		Color = Color3.fromRGB(24, 24, 32), Material = Enum.Material.Asphalt, CanQuery = false })
	for i = 1, 70 do
		local a = rng:NextNumber() * math.pi * 2
		local dist = rng:NextNumber(115, 300)
		local far = dist > 220
		local h = far and rng:NextInteger(160, 240) or rng:NextInteger(50, 135)
		local w = rng:NextInteger(16, 30)
		local pos = Vector3.new(SKY_O.X + math.cos(a) * dist, h / 2, SKY_O.Z + math.sin(a) * dist)
		part({ Name = "CityBuilding", Parent = deco, Size = Vector3.new(w, h, w), Position = pos,
			Color = Color3.fromRGB(rng:NextInteger(24, 40), rng:NextInteger(24, 36), rng:NextInteger(38, 58)), Material = Enum.Material.Concrete,
			CanQuery = false })
		local c = neon[rng:NextInteger(1, #neon)]
		local wy = 8
		while wy < h - 4 do
			if rng:NextNumber() < 0.5 then
				part({ Name = "Window", Parent = deco, Size = Vector3.new(w + 0.2, 0.6, w + 0.2), Position = Vector3.new(pos.X, wy, pos.Z),
					Color = c, Material = Enum.Material.Neon, CanCollide = false, CanQuery = false }).Transparency = 0.4
			end
			wy = wy + rng:NextInteger(5, 9)
		end
	end
	-- 옥상 투광등
	for _, s in ipairs({ -1, 1 }) do
		for _, t in ipairs({ -1, 1 }) do
			local lamp = part({ Name = "Floodlight", Parent = deco, Size = Vector3.new(2, 1, 2), Position = skyPos(48 * s, 9, 50 * t),
				Color = Color3.fromRGB(255, 245, 225), Material = Enum.Material.Neon, CanCollide = false, CanQuery = false })
			local spot = Instance.new("SpotLight")
			spot.Face = Enum.NormalId.Bottom
			spot.Range = 45
			spot.Angle = 90
			spot.Brightness = 2
			spot.Parent = lamp
			box("LightPole", 48 * s, 0, 50.6 * t, 0.5, 8.5, 0.5, Color3.fromRGB(40, 40, 50), Enum.Material.Metal, deco).CanQuery = false
		end
	end
	-- 전광판
	local screen = part({ Name = "Jumbotron", Parent = deco, Size = Vector3.new(1, 9, 24), Position = skyPos(0, 30, 0),
		Color = Color3.fromRGB(10, 10, 16), CanQuery = false })
	screen.CanCollide = false
	local jumbotron = {}
	for _, face in ipairs({ Enum.NormalId.Left, Enum.NormalId.Right }) do
		table.insert(jumbotron, label(screen, "SKY ROOFTOP", face))
	end

	--------------------------------------------------------------------
	-- 스폰·깃발·미션 지점
	--------------------------------------------------------------------
	local spawns = { [1] = {}, [2] = {} }
	for _, z in ipairs({ -16, -8, 0, 8, 16 }) do
		table.insert(spawns[1], CFrame.lookAt(skyPos(-79, 11, z), skyPos(0, 11, z)))
		table.insert(spawns[2], CFrame.lookAt(skyPos(79, 11, z), skyPos(0, 11, z)))
	end
	local solo = {}
	for _, p3 in ipairs({ { -79, 11, 0 }, { 79, 11, 0 }, { 0, 3, 49 }, { 0, 3, -49 }, { -30, 3, 48 }, { 30, 3, -48 }, { 30, 3, 48 }, { 8, 14, 0 } }) do
		table.insert(solo, CFrame.lookAt(skyPos(p3[1], p3[2], p3[3]), skyPos(0, p3[2], 0)))
	end

	addOutlines(geo)
	return {
		Id = "SkyRooftop",
		Name = "스카이 루프탑",
		Folder = root,
		Geometry = geo,
		Cells = cells,
		Spawns = spawns,
		SoloSpawns = solo,
		FlagPoints = {
			{ Name = "A", Position = skyPos(0, 12, -42) },
			{ Name = "C", Position = skyPos(0, 0, 0) },
			{ Name = "B", Position = skyPos(0, 12, 42) },
		},
		MissionSpots = {
			skyPos(0, 0, 0), skyPos(0, 12, 42), skyPos(0, 12, -42), skyPos(30, 0, 42), skyPos(-30, 0, -42),
			skyPos(-30, 0, 42), skyPos(30, 0, -42), skyPos(40, 0, 0), skyPos(-40, 0, 0), skyPos(10, 11, 0),
		},
		KillY = SKY_Y - 30,
		Jumbotron = jumbotron,
	}
end

return MapBuilder
