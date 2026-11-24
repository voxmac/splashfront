-- 로비와 아레나(크로마 스퀘어)를 코드로 생성
-- 새 맵은 BuildXXX 함수를 추가하고 같은 형태의 info 테이블을 돌려주면 됨
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Lighting = game:GetService("Lighting")
local CollectionService = game:GetService("CollectionService")
local Config = require(ReplicatedStorage.Shared.Config)

local MapBuilder = {}

local CELL = Config.CellSize
local MS = Config.MapScale or 1 -- 맵 가로·세로 배율 (높이는 그대로)

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

-- 맵별 조명 (레퍼런스: 낮게 뜬 해 + 눈부심, 햇살 줄기, 따뜻한 대기 안개, 입체 구름, 먼 곳 살짝 흐림)
-- Day(크로마 스퀘어·로비) / Sunset(스카이 루프탑 노을 네온) / City(시가전 골든 아워)
local PRESETS = {
	Day = { Clock = 14.6, Lat = 35, Bright = 3, Amb = Color3.fromRGB(140, 146, 165), Out = Color3.fromRGB(165, 172, 192), Spec = 0.6,
		AtmDensity = 0.3, AtmOffset = 0.2, AtmColor = Color3.fromRGB(205, 225, 255), AtmDecay = Color3.fromRGB(110, 150, 215), Haze = 1.4, Glare = 0.5,
		Sat = 0.2, Con = 0.08, Tint = Color3.fromRGB(255, 252, 246), Bloom = 0.4, Thresh = 1.6,
		Rays = 0.08, RaySpread = 0.7, Dof = 0.12, Clouds = { Cover = 0.55, Density = 0.65, Color = Color3.fromRGB(255, 255, 255) }, Sun = 16 },
	Sunset = { Clock = 17.6, Lat = 35, Bright = 2.2, Amb = Color3.fromRGB(90, 90, 110), Out = Color3.fromRGB(140, 140, 160), Spec = 1,
		AtmDensity = 0.27, AtmOffset = 0.15, AtmColor = Color3.fromRGB(225, 200, 255), AtmDecay = Color3.fromRGB(120, 80, 160), Haze = 0.8, Glare = 0.6,
		Sat = 0.18, Con = 0.1, Tint = Color3.fromRGB(255, 242, 248), Bloom = 0.6, Thresh = 1.4,
		Rays = 0.1, RaySpread = 0.8, Dof = 0.12, Clouds = { Cover = 0.5, Density = 0.55, Color = Color3.fromRGB(255, 214, 236) }, Sun = 18 },
	-- 로비 격납고: 차가운 남색 실내, 네온이 번지도록 블룸 강하게, 바닥 반사
	Lobby = { Clock = 14, Lat = 35, Bright = 1.1, Amb = Color3.fromRGB(34, 42, 72), Out = Color3.fromRGB(48, 58, 96), Spec = 0.6, Exposure = -0.35,
		AtmDensity = 0.18, AtmOffset = 0.1, AtmColor = Color3.fromRGB(150, 170, 230), AtmDecay = Color3.fromRGB(70, 80, 140), Haze = 0.6, Glare = 0,
		Sat = 0.18, Con = 0.18, Tint = Color3.fromRGB(230, 236, 255), Bloom = 0.5, Thresh = 1.35,
		Rays = 0.05, RaySpread = 0.5, Dof = 0.06, Clouds = { Cover = 0.5, Density = 0.6, Color = Color3.fromRGB(230, 236, 255) }, Sun = 14 },
	-- 시가전: 레퍼런스 1번처럼 지평선 가까운 해, 주황빛 먼지 안개, 햇살 번짐, 먼 건물은 실루엣
	City = { Clock = 17.75, Lat = 25, Bright = 2.6, Amb = Color3.fromRGB(110, 86, 78), Out = Color3.fromRGB(150, 118, 100), Spec = 1,
		AtmDensity = 0.42, AtmOffset = 0.25, AtmColor = Color3.fromRGB(255, 196, 150), AtmDecay = Color3.fromRGB(176, 104, 74), Haze = 2.6, Glare = 1.6,
		Sat = 0.06, Con = 0.14, Tint = Color3.fromRGB(255, 232, 208), Bloom = 0.7, Thresh = 1.15,
		Rays = 0.16, RaySpread = 0.85, Dof = 0.28, Clouds = { Cover = 0.62, Density = 0.7, Color = Color3.fromRGB(255, 196, 160) }, Sun = 22 },
}
local function ensure(class, parent)
	local o = parent:FindFirstChildOfClass(class)
	if not o then
		o = Instance.new(class)
		o.Parent = parent
	end
	return o
end

function MapBuilder.ApplyLighting(name)
	local p = PRESETS[name] or PRESETS.Day
	Lighting.ClockTime = p.Clock
	Lighting.GeographicLatitude = p.Lat or 35
	Lighting.Brightness = p.Bright
	Lighting.Ambient = p.Amb
	Lighting.OutdoorAmbient = p.Out
	Lighting.EnvironmentSpecularScale = p.Spec
	Lighting.ExposureCompensation = p.Exposure or 0
	local a = ensure("Atmosphere", Lighting)
	a.Density, a.Offset, a.Color, a.Decay, a.Haze, a.Glare = p.AtmDensity, p.AtmOffset or 0.15, p.AtmColor, p.AtmDecay, p.Haze, p.Glare
	local cc = ensure("ColorCorrectionEffect", Lighting)
	cc.Saturation, cc.Contrast, cc.TintColor = p.Sat, p.Con, p.Tint
	local b = ensure("BloomEffect", Lighting)
	b.Intensity, b.Threshold, b.Size = p.Bloom, p.Thresh, 28
	local rays = ensure("SunRaysEffect", Lighting)
	rays.Intensity, rays.Spread = p.Rays or 0.06, p.RaySpread or 0.6
	local dof = ensure("DepthOfFieldEffect", Lighting)
	dof.FarIntensity = p.Dof or 0.1
	dof.NearIntensity = 0
	dof.FocusDistance = 40
	dof.InFocusRadius = 90
	local sky = ensure("Sky", Lighting)
	sky.SunAngularSize = p.Sun or 14
	local clouds = ensure("Clouds", workspace.Terrain)
	if p.Clouds then
		clouds.Enabled = true
		clouds.Cover, clouds.Density, clouds.Color = p.Clouds.Cover, p.Clouds.Density, p.Clouds.Color
	else
		clouds.Enabled = false
	end
end

function MapBuilder.SetupLighting()
	-- 0.6: 밝은 한낮 카툰 톤 (흰 구조물 위에 진한 팀 페인트가 또렷하게)
	Lighting.ClockTime = 14.2
	Lighting.GeographicLatitude = 35
	Lighting.Brightness = 3
	Lighting.Ambient = Color3.fromRGB(140, 146, 165)
	Lighting.OutdoorAmbient = Color3.fromRGB(165, 172, 192)
	Lighting.EnvironmentDiffuseScale = 1
	Lighting.EnvironmentSpecularScale = 0.6
	Lighting.ShadowSoftness = 0.25
	Lighting.GlobalShadows = true
	if not Lighting:FindFirstChildOfClass("Atmosphere") then
		local a = Instance.new("Atmosphere")
		a.Density = 0.27
		a.Offset = 0.15
		a.Color = Color3.fromRGB(199, 222, 255)
		a.Decay = Color3.fromRGB(110, 150, 215)
		a.Glare = 0.2
		a.Haze = 1.1
		a.Parent = Lighting
	end
	if not Lighting:FindFirstChildOfClass("Sky") then
		local sky = Instance.new("Sky")
		sky.SunAngularSize = 14
		sky.Parent = Lighting
	end
	if not Lighting:FindFirstChildOfClass("ColorCorrectionEffect") then
		local cc = Instance.new("ColorCorrectionEffect")
		cc.Saturation = 0.22
		cc.Contrast = 0.06
		cc.Brightness = 0.02
		cc.TintColor = Color3.fromRGB(255, 252, 248)
		cc.Parent = Lighting
	end
	if not Lighting:FindFirstChildOfClass("SunRaysEffect") then
		local rays = Instance.new("SunRaysEffect")
		rays.Intensity = 0.06
		rays.Parent = Lighting
	end
	if not Lighting:FindFirstChildOfClass("BloomEffect") then
		local b = Instance.new("BloomEffect")
		b.Intensity = 0.35
		b.Threshold = 1.7
		b.Parent = Lighting
	end	Lighting.ShadowSoftness = 0.18
	MapBuilder.ApplyLighting("Lobby")
end

-- 기획서 3장: 엄폐물은 어두운 외곽선으로 바닥과 구분
local OUTLINED = { Crate = true, Wall = true, WarehouseWall = true, Container = true, Parapet = true, WallSill = true, Platform = true,
	Ramp = true, Boundary = true, SpawnWall = true, Lintel = true, WarehouseRoof = true }

------------------------------------------------------------------------
-- 0.6 아트 패스: 밝은 카툰 팔레트 + 엄폐물 디테일(모서리 프레임·받침·캡)
-- 판정용 모양은 그대로 두고 장식 파트만 덧붙임 (CanCollide·CanQuery 끔)
------------------------------------------------------------------------
local PALETTE = {
	Floor = { Color3.fromRGB(238, 240, 247), Enum.Material.SmoothPlastic },
	Boundary = { Color3.fromRGB(214, 220, 234), Enum.Material.SmoothPlastic },
	Wall = { Color3.fromRGB(226, 230, 240), Enum.Material.SmoothPlastic },
	WarehouseWall = { Color3.fromRGB(226, 230, 240), Enum.Material.SmoothPlastic },
	Lintel = { Color3.fromRGB(214, 218, 230), Enum.Material.SmoothPlastic },
	WallSill = { Color3.fromRGB(214, 218, 230), Enum.Material.SmoothPlastic },
	Parapet = { Color3.fromRGB(230, 234, 244), Enum.Material.SmoothPlastic },
	SpawnWall = { Color3.fromRGB(210, 216, 230), Enum.Material.SmoothPlastic },
	Platform = { Color3.fromRGB(206, 212, 228), Enum.Material.SmoothPlastic },
	MidTower = { Color3.fromRGB(196, 204, 222), Enum.Material.SmoothPlastic },
	SpawnTower = { Color3.fromRGB(188, 196, 216), Enum.Material.SmoothPlastic },
	Ramp = { Color3.fromRGB(186, 192, 210), Enum.Material.DiamondPlate },
	Crate = { Color3.fromRGB(236, 176, 100), Enum.Material.WoodPlanks },
	WarehouseRoof = { Color3.fromRGB(222, 218, 206), Enum.Material.SmoothPlastic },
	CityGround = { Color3.fromRGB(150, 160, 178), Enum.Material.SmoothPlastic },
	Street = { Color3.fromRGB(150, 160, 178), Enum.Material.SmoothPlastic },
}
local PASTEL = Color3.fromRGB(190, 210, 238)

local function deco(parent, size, cf, color, mat)
	local p = Instance.new("Part")
	p.Name = "Detail"
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = mat or Enum.Material.SmoothPlastic
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = parent
	return p
end

local function stylize(folder)
	local detail = Instance.new("Folder")
	detail.Name = "Detail"
	detail.Parent = folder
	for _, p in ipairs(folder:GetDescendants()) do
		if p:IsA("BasePart") and p.Name ~= "Cell" and p.Parent ~= detail then
			local pal = PALETTE[p.Name]
			if pal then
				p.Color = pal[1]
				p.Material = pal[2]
			elseif p.Name == "Building" or p.Name == "CityBuilding" then
				p.Color = p.Color:Lerp(PASTEL, 0.75)
				p.Material = Enum.Material.SmoothPlastic
			elseif p.Name == "Container" then
				p.Color = p.Color:Lerp(Color3.new(1, 1, 1), 0.25)
				p.Material = Enum.Material.SmoothPlastic
			end
			local sz, cf = p.Size, p.CFrame
			if p.Name == "Crate" then
				-- 모서리 각재 4개 + 윗테 4개 + 가운데 X 대신 가로대
				local dark = Color3.fromRGB(170, 108, 56)
				for _, sx in ipairs({ -1, 1 }) do
					for _, sz2 in ipairs({ -1, 1 }) do
						deco(detail, Vector3.new(0.5, sz.Y + 0.04, 0.5), cf * CFrame.new(sx * (sz.X / 2 - 0.2), 0, sz2 * (sz.Z / 2 - 0.2)), dark, Enum.Material.Wood)
					end
				end
				for _, sx in ipairs({ -1, 1 }) do
					deco(detail, Vector3.new(0.4, 0.4, sz.Z + 0.06), cf * CFrame.new(sx * (sz.X / 2 - 0.15), sz.Y / 2 - 0.15, 0), dark, Enum.Material.Wood)
					deco(detail, Vector3.new(sz.X + 0.06, 0.4, 0.4), cf * CFrame.new(0, sz.Y / 2 - 0.15, sx * (sz.Z / 2 - 0.15)), dark, Enum.Material.Wood)
					deco(detail, Vector3.new(sz.X + 0.06, 0.35, 0.36), cf * CFrame.new(0, -0.1, sx * (sz.Z / 2 - 0.12)), dark, Enum.Material.Wood)
				end
			elseif p.Name == "Wall" or p.Name == "WarehouseWall" or p.Name == "Boundary" or p.Name == "SpawnWall" then
				-- 아래 걸레받이 + 위 캡(살짝 넓게) + 일정 간격 패널 이음새
				local long = (sz.X >= sz.Z) and "X" or "Z"
				deco(detail, Vector3.new(sz.X + 0.12, 0.6, sz.Z + 0.12), cf * CFrame.new(0, -sz.Y / 2 + 0.3, 0), Color3.fromRGB(150, 158, 180))
				deco(detail, Vector3.new(sz.X + 0.3, 0.35, sz.Z + 0.3), cf * CFrame.new(0, sz.Y / 2 + 0.17, 0), Color3.fromRGB(245, 247, 252))
				local len = (long == "X") and sz.X or sz.Z
				local n = math.floor(len / 8)
				for k = 1, n - 1 do
					local o = -len / 2 + k * (len / n)
					local off = (long == "X") and CFrame.new(o, 0, 0) or CFrame.new(0, 0, o)
					local s2 = (long == "X") and Vector3.new(0.18, sz.Y - 0.8, sz.Z + 0.06) or Vector3.new(sz.X + 0.06, sz.Y - 0.8, 0.18)
					deco(detail, s2, cf * off, Color3.fromRGB(190, 196, 214))
				end
			elseif p.Name == "Platform" or p.Name == "Parapet" then
				-- 윗면 가장자리 띠
				deco(detail, Vector3.new(sz.X + 0.16, 0.3, sz.Z + 0.16), cf * CFrame.new(0, sz.Y / 2 - 0.12, 0), Color3.fromRGB(250, 250, 255))
			elseif p.Name == "Container" then
				-- 골판 무늬(세로 리브) + 문 손잡이
				local long = (sz.X >= sz.Z) and "X" or "Z"
				local len = (long == "X") and sz.X or sz.Z
				local shade = p.Color:Lerp(Color3.new(0, 0, 0), 0.18)
				for k = 1, math.floor(len / 1.6) do
					local o = -len / 2 + (k - 0.5) * 1.6
					local off = (long == "X") and CFrame.new(o, 0, 0) or CFrame.new(0, 0, o)
					local s2 = (long == "X") and Vector3.new(0.35, sz.Y - 0.6, sz.Z + 0.1) or Vector3.new(sz.X + 0.1, sz.Y - 0.6, 0.35)
					deco(detail, s2, cf * off, shade)
				end
				deco(detail, Vector3.new(sz.X + 0.14, 0.3, sz.Z + 0.14), cf * CFrame.new(0, sz.Y / 2 - 0.15, 0), shade)
				deco(detail, Vector3.new(sz.X + 0.14, 0.3, sz.Z + 0.14), cf * CFrame.new(0, -sz.Y / 2 + 0.15, 0), shade)
			end
		end
	end
end

local function addOutlines(folder, keepOriginal)
	if not keepOriginal then
		stylize(folder)
	end
	for _, p in ipairs(folder:GetDescendants()) do
		if p:IsA("BasePart") and OUTLINED[p.Name] then
			local sb = Instance.new("SelectionBox")
			sb.Adornee = p
			sb.Color3 = Color3.fromRGB(40, 44, 70)
			sb.LineThickness = 0.05
			sb.SurfaceTransparency = 1
			sb.Parent = p
		end
	end
end

------------------------------------------------------------------------
-- 로비
------------------------------------------------------------------------
-- 로비: 광장(페인트 스플랫 바닥) + 로고 타이틀 + 매치 발판 무대 + 랭킹 보드 + 상점 부스
local LOBBY_COLORS = {
	Color3.fromRGB(255, 46, 170), Color3.fromRGB(0, 200, 255), Color3.fromRGB(255, 214, 0),
	Color3.fromRGB(70, 220, 80), Color3.fromRGB(175, 80, 255), Color3.fromRGB(255, 140, 30),
}

local function cyl(props)
	-- 세로로 선 원기둥/원판 (Roblox 원기둥은 X축이 길이 방향이라 90도 돌림)
	local h, d = props.Height, props.Diameter
	props.Shape = Enum.PartType.Cylinder
	props.Size = Vector3.new(h, d, d)
	props.CFrame = CFrame.new(props.Position) * CFrame.Angles(0, 0, math.rad(90))
	props.Position = nil
	props.Height, props.Diameter = nil, nil
	return part(props)
end

local function titleText(gui, text, pos, size, c1, c2)
	local t = Instance.new("TextLabel")
	t.BackgroundTransparency = 1
	t.Position = pos
	t.Size = size
	t.Font = Enum.Font.FredokaOne
	t.TextScaled = true
	t.Text = text
	t.TextColor3 = Color3.new(1, 1, 1)
	t.Parent = gui
	local g = Instance.new("UIGradient")
	g.Color = ColorSequence.new(c1, c2)
	g.Rotation = 90
	g.Parent = t
	local st = Instance.new("UIStroke")
	st.Thickness = 10
	st.Color = Color3.fromRGB(16, 12, 30)
	st.Parent = t
	return t
end

-- 로고 이미지가 준비되면 벽 모니터 오른쪽 위에 작은 로고를 붙임 (제목 폭은 그만큼 줄임)
function MapBuilder.ApplyMonitorLogo(folder, url)
	for _, mon in ipairs(folder:GetDescendants()) do
		if mon.Name == "WallMonitor" and mon:FindFirstChild("Screen") then
			local bg = mon.Screen:FindFirstChild("BG")
			if bg and not bg:FindFirstChild("Logo") then
				local li = Instance.new("ImageLabel")
				li.Name = "Logo"
				li.BackgroundTransparency = 1
				li.Image = url
				li.ScaleType = Enum.ScaleType.Fit
				li.Size = UDim2.fromScale(0.26, 0.24)
				li.Position = UDim2.fromScale(0.72, 0.06)
				li.Parent = bg
				local h = bg:FindFirstChild("Head")
				if h then
					h.Size = UDim2.fromScale(0.64, 0.34)
				end
			end
		end
	end
end

function MapBuilder.BuildLobby()
	local old = workspace:FindFirstChild("Lobby")
	if old then
		old:Destroy()
	end
	local lobby = Instance.new("Folder")
	lobby.Name = "Lobby"
	lobby.Parent = workspace
	local deco = Instance.new("Folder")
	deco.Name = "Decoration"
	deco.Parent = lobby
	local rng = Random.new(77)

	local Y = 400
	local W, D = 170, 130
	------------------------------------------------------------------
	-- SF 격납고 로비: 짙은 남색 강철 벽 + 노랑/자홍 네온 칸, 유리 천장과 네온 갈비대,
	-- 무지개 네온 통로, 떠 있는 육각 무기 진열대 (레퍼런스: 사이파이 하이퍼 FPS 로비)
	------------------------------------------------------------------
	local STEEL = Color3.fromRGB(30, 38, 62)
	local STEEL2 = Color3.fromRGB(42, 52, 84)
	local STEEL3 = Color3.fromRGB(22, 28, 46)
	local NEON_Y = Color3.fromRGB(240, 255, 40)
	local NEON_M = Color3.fromRGB(255, 40, 200)
	local NEON_P = Color3.fromRGB(150, 70, 255)
	local NEON_C = Color3.fromRGB(0, 230, 255)
	local H = 46 -- 천장 높이

	-- 바닥: 진한 강철판 + 10스터드 이음새
	local floor = part({ Name = "Floor", Parent = lobby, Size = Vector3.new(W, 2, D), Position = Vector3.new(0, Y - 1, 0),
		Color = Color3.fromRGB(18, 22, 38), Material = Enum.Material.SmoothPlastic })
	floor.Reflectance = 0.05 -- 네온이 바닥에 비치는 광택
	floor:SetAttribute("NoTexture", true)
	for x = -W / 2 + 10, W / 2 - 10, 10 do
		part({ Name = "Seam", Parent = deco, Size = Vector3.new(0.18, 0.04, D), Position = Vector3.new(x, Y + 0.02, 0),
			Color = Color3.fromRGB(12, 14, 24), CanCollide = false, CanQuery = false })
	end
	for z = -D / 2 + 10, D / 2 - 10, 10 do
		part({ Name = "Seam", Parent = deco, Size = Vector3.new(W, 0.04, 0.18), Position = Vector3.new(0, Y + 0.02, z),
			Color = Color3.fromRGB(12, 14, 24), CanCollide = false, CanQuery = false })
	end
	-- 중앙 통로 (스폰 → 발판 무대): 밝은 패널 + 양옆 무지개 네온 줄
	local pathZ1, pathZ2 = -12, D / 2 - 4
	local walk = part({ Name = "Walkway", Parent = deco, Size = Vector3.new(26, 0.1, pathZ2 - pathZ1), Position = Vector3.new(0, Y + 0.05, (pathZ1 + pathZ2) / 2),
		Color = Color3.fromRGB(28, 34, 58), Material = Enum.Material.SmoothPlastic, CanCollide = false, CanQuery = false })
	walk.Reflectance = 0.04
	local segs = 24
	for i = 0, segs - 1 do
		local z1 = pathZ1 + (pathZ2 - pathZ1) * i / segs
		local len = (pathZ2 - pathZ1) / segs
		local c = Color3.fromHSV((i / segs) * 0.85, 0.85, 1)
		for _, sx in ipairs({ -1, 1 }) do
			part({ Name = "RainbowLine", Parent = deco, Size = Vector3.new(0.7, 0.12, len + 0.02), Position = Vector3.new(sx * 13.4, Y + 0.08, z1 + len / 2),
				Color = c, Material = Enum.Material.Neon, CanCollide = false, CanQuery = false })
		end
	end
	-- 통로 가운데 화살표 표시
	for z = pathZ2 - 12, pathZ1 + 8, -10 do
		for _, sx in ipairs({ -1, 1 }) do
			local w = part({ Name = "Chevron", Parent = deco, Size = Vector3.new(0.6, 0.06, 4), CFrame = CFrame.new(sx * 1.4, Y + 0.12, z)
				* CFrame.Angles(0, math.rad(sx * 40), 0), Color = Color3.fromRGB(160, 175, 210), Material = Enum.Material.Neon, CanCollide = false, CanQuery = false })
			w.Transparency = 0.45
		end
	end

	-- 벽: 14스터드 칸마다 안쪽 패널 + 칸 경계 기둥(노랑/자홍 네온) + 아래·위 시안 띠
	local function wallSide(axis, sgn)
		local len = axis == "X" and W or D
		local function at(t, y, inset)
			if axis == "X" then
				return Vector3.new(t, y, sgn * (D / 2 - inset))
			end
			return Vector3.new(sgn * (W / 2 - inset), y, t)
		end
		local function size(along, h, thick)
			if axis == "X" then
				return Vector3.new(along, h, thick)
			end
			return Vector3.new(thick, h, along)
		end
		part({ Name = "HangarWall", Parent = lobby, Size = size(len, H, 2), Position = at(0, Y + H / 2, -1), Color = STEEL, Material = Enum.Material.Metal })
		part({ Name = "WallSkirt", Parent = deco, Size = size(len, 0.5, 0.4), Position = at(0, Y + 4, 0.2), Color = NEON_C, Material = Enum.Material.Neon,
			CanQuery = false, CanCollide = false })
		part({ Name = "WallCrown", Parent = deco, Size = size(len, 0.5, 0.4), Position = at(0, Y + H - 8, 0.2), Color = NEON_P, Material = Enum.Material.Neon,
			CanQuery = false, CanCollide = false })
		local k = 0
		for t = -len / 2 + 7, len / 2 - 7, 14 do
			k = k + 1
			-- 들어간 패널 (가운데 조금 밝게)
			part({ Name = "WallPanel", Parent = deco, Size = size(11, H - 16, 0.6), Position = at(t, Y + 4 + (H - 12) / 2, 0.3), Color = STEEL2,
				Material = Enum.Material.Metal, CanQuery = false })
			part({ Name = "PanelSlit", Parent = deco, Size = size(8, 0.25, 0.7), Position = at(t, Y + 14, 0.35), Color = STEEL3, CanQuery = false })
			part({ Name = "PanelSlit", Parent = deco, Size = size(8, 0.25, 0.7), Position = at(t, Y + 26, 0.35), Color = STEEL3, CanQuery = false })
			-- 칸 경계 기둥 + 세로 네온
			local edge = t + 7
			if edge < len / 2 - 1 then
				part({ Name = "WallRib", Parent = deco, Size = size(2.2, H, 1.6), Position = at(edge, Y + H / 2, 0.6), Color = STEEL3,
					Material = Enum.Material.Metal, CanQuery = false })
				local nc = (k % 2 == 0) and NEON_M or NEON_Y
				local bar = part({ Name = "WallNeon", Parent = deco, Size = size(0.7, 14, 0.5), Position = at(edge, Y + 13, 1.5), Color = nc,
					Material = Enum.Material.Neon, CanQuery = false, CanCollide = false })
				if k % 2 == 1 then
					local l = Instance.new("PointLight")
					l.Color = nc
					l.Range = 18
					l.Brightness = 1.4
					l.Parent = bar
				end
			end
		end
	end
	wallSide("X", -1)
	wallSide("X", 1)
	wallSide("Z", -1)
	wallSide("Z", 1)

	-- 벽 모니터: 게임 안내·팁이 흐르는 화면 (좌우 벽, 사람 눈높이 위)
	local tips = {
		{ "PAINT TO WIN", "바닥을 더 많이 칠한 팀이 승리 · 페인트 80% + 처치·미션 20%" },
		{ "ZONE TEAMS", "같은 ZONE 발판에 선 친구끼리 한 팀으로 출전" },
		{ "DAILY MISSIONS", "일일·주간 미션을 깨고 코인으로 스킨을 사세요" },
		{ "NEW MAP", "크로마 시티 · 도시 한복판에서 벌이는 페인트 시가전" },
	}
	for i, tip in ipairs(tips) do
		local sx = (i <= 2) and -1 or 1
		local zz = (i % 2 == 1) and 40 or -30 -- 랭킹 보드·상점 간판(z 2~25)과 겹치지 않게
		local pos = Vector3.new(sx * (W / 2 - 1.9), Y + 15, zz)
		local mon = part({ Name = "WallMonitor", Parent = deco, Size = Vector3.new(16, 8.5, 0.4), CFrame = CFrame.lookAt(pos, pos + Vector3.new(-sx, 0, 0)),
			Color = Color3.fromRGB(8, 10, 20), Material = Enum.Material.Glass, CanQuery = false })
		part({ Name = "MonitorFrame", Parent = deco, Size = Vector3.new(16.8, 9.3, 0.3), CFrame = mon.CFrame * CFrame.new(0, 0, 0.25),
			Color = Color3.fromRGB(26, 32, 54), Material = Enum.Material.Metal, CanQuery = false })
		local g = Instance.new("SurfaceGui")
		g.Face = Enum.NormalId.Front
		g.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
		g.PixelsPerStud = 32
		g.LightInfluence = 0
		g.Parent = mon
		g.Name = "Screen"
		local bg = Instance.new("Frame")
		bg.Name = "BG"
		bg.Size = UDim2.fromScale(1, 1)
		bg.BackgroundColor3 = Color3.new(1, 1, 1)
		bg.Parent = g
		local grad = Instance.new("UIGradient")
		local c1 = (i % 2 == 1) and NEON_M or NEON_C
		grad.Color = ColorSequence.new(c1:Lerp(Color3.new(0, 0, 0), 0.55), Color3.fromRGB(10, 12, 28))
		grad.Rotation = 35
		grad.Parent = bg
		-- 타이틀 로고와 같은 스타일: 몬세라트 굵은 이탤릭 + 네온 그라데이션 + 남색 외곽선
		local TITLE_FONT = Font.new("rbxasset://fonts/families/Montserrat.json", Enum.FontWeight.Heavy, Enum.FontStyle.Italic)
		local pink = (i % 2 == 1)
		-- 위·아래 네온 라인 (타이틀 보드 테두리 색)
		for _, yy in ipairs({ 0, 0.975 }) do
			local ln = Instance.new("Frame")
			ln.BorderSizePixel = 0
			ln.Size = UDim2.fromScale(1, 0.025)
			ln.Position = UDim2.fromScale(0, yy)
			ln.BackgroundColor3 = (yy == 0) and Color3.fromRGB(255, 40, 200) or Color3.fromRGB(240, 255, 40)
			ln.Parent = bg
		end
		local h = Instance.new("TextLabel")
		h.BackgroundTransparency = 1
		h.Name = "Head"
		h.Size = UDim2.fromScale(0.9, 0.34)
		h.Position = UDim2.fromScale(0.05, 0.1)
		h.FontFace = TITLE_FONT
		h.TextScaled = true
		h.TextXAlignment = Enum.TextXAlignment.Left
		h.TextColor3 = Color3.new(1, 1, 1)
		h.Text = tip[1]
		h.Parent = bg
		local hg = Instance.new("UIGradient")
		hg.Color = pink and ColorSequence.new(Color3.fromRGB(255, 150, 225), Color3.fromRGB(255, 30, 140))
			or ColorSequence.new(Color3.fromRGB(150, 245, 255), Color3.fromRGB(0, 150, 255))
		hg.Rotation = 90
		hg.Parent = h
		local hs = Instance.new("UIStroke")
		hs.Thickness = 4
		hs.Color = Color3.fromRGB(16, 12, 30)
		hs.Parent = h
		-- 제목 아래 노란 사선 띠 (타이틀의 FRONT 띠 느낌)
		local bar = Instance.new("Frame")
		bar.BorderSizePixel = 0
		bar.BackgroundColor3 = NEON_Y
		bar.Size = UDim2.fromScale(0.3, 0.035)
		bar.Position = UDim2.fromScale(0.05, 0.48)
		bar.Rotation = -2
		bar.Parent = bg
		local d2 = Instance.new("TextLabel")
		d2.BackgroundTransparency = 1
		d2.Size = UDim2.fromScale(0.9, 0.34)
		d2.Position = UDim2.fromScale(0.05, 0.56)
		d2.FontFace = Font.new("rbxasset://fonts/families/GothamSSm.json", Enum.FontWeight.Bold, Enum.FontStyle.Normal)
		d2.TextScaled = true
		d2.TextWrapped = true
		d2.TextXAlignment = Enum.TextXAlignment.Left
		d2.TextYAlignment = Enum.TextYAlignment.Top
		d2.TextColor3 = Color3.fromRGB(235, 240, 255)
		d2.Text = tip[2]
		d2.Parent = bg
		local ds = Instance.new("UIStroke")
		ds.Thickness = 2
		ds.Color = Color3.fromRGB(10, 8, 24)
		ds.Transparency = 0.3
		ds.Parent = d2
	end

	-- 유리 천장 + 자홍/보라 네온 갈비대 (하늘과 구름이 비침)
	part({ Name = "CeilingGlass", Parent = deco, Size = Vector3.new(W, 0.4, D), Position = Vector3.new(0, Y + H, 0), Color = Color3.fromRGB(150, 200, 255),
		Material = Enum.Material.Glass, Transparency = 0.6, CanQuery = false })
	local ri = 0
	for x = -W / 2, W / 2, 14 do
		ri = ri + 1
		part({ Name = "CeilingRib", Parent = deco, Size = Vector3.new(2, 2.4, D), Position = Vector3.new(x, Y + H - 1, 0), Color = STEEL3,
			Material = Enum.Material.Metal, CanQuery = false })
		part({ Name = "RibNeon", Parent = deco, Size = Vector3.new(0.6, 0.3, D - 2), Position = Vector3.new(x, Y + H - 2.3, 0),
			Color = (ri % 2 == 0) and NEON_M or NEON_P, Material = Enum.Material.Neon, CanQuery = false, CanCollide = false })
	end
	for z = -D / 2, D / 2, 26 do
		part({ Name = "CeilingBeam", Parent = deco, Size = Vector3.new(W, 1.6, 1.6), Position = Vector3.new(0, Y + H - 1.2, z), Color = STEEL3,
			Material = Enum.Material.Metal, CanQuery = false })
	end
	-- 천장에 매단 조명 (흰 사각 등)
	for x = -56, 56, 28 do
		for z = -30, 40, 35 do
			local lamp = part({ Name = "CeilingLamp", Parent = deco, Size = Vector3.new(6, 0.4, 2), Position = Vector3.new(x, Y + H - 2.6, z),
				Color = Color3.fromRGB(235, 245, 255), Material = Enum.Material.Neon, CanQuery = false, CanCollide = false })
			local sl = Instance.new("SurfaceLight")
			sl.Face = Enum.NormalId.Bottom
			sl.Range = 40
			sl.Angle = 90
			sl.Brightness = 0.7
			sl.Color = Color3.fromRGB(210, 225, 255)
			sl.Parent = lamp
		end
	end

	-- 떠 있는 육각 무기 진열대 (총은 클라이언트에서 천천히 회전: Spin 속성)
	local displays = { { -42, 30, "Sniper" }, { 42, 30, "Rifle" }, { -42, 4, "Launcher" }, { 42, 4, "Shotgun" } }
	for i, dsp in ipairs(displays) do
		local base = Vector3.new(dsp[1], Y + 3.2, dsp[2])
		for k = 0, 2 do
			part({ Name = "HexDeck", Parent = lobby, Size = Vector3.new(9.2, 1.2, 16), CFrame = CFrame.new(base) * CFrame.Angles(0, math.rad(60 * k), 0),
				Color = Color3.fromRGB(225, 232, 245), Material = Enum.Material.SmoothPlastic })
			part({ Name = "HexRim", Parent = deco, Size = Vector3.new(9.4, 0.3, 16.2), CFrame = CFrame.new(base + Vector3.new(0, -0.7, 0))
				* CFrame.Angles(0, math.rad(60 * k), 0), Color = (i % 2 == 0) and NEON_C or NEON_M, Material = Enum.Material.Neon, CanQuery = false,
				CanCollide = false })
		end
		-- 아래로 좁아지는 받침 (떠 있는 느낌)
		part({ Name = "HexUnder", Parent = deco, Shape = Enum.PartType.Ball, Size = Vector3.new(8, 3, 8), Position = base + Vector3.new(0, -1.6, 0),
			Color = Color3.fromRGB(70, 80, 110), Material = Enum.Material.Metal, CanQuery = false })
		local glow = part({ Name = "HexGlow", Parent = deco, Size = Vector3.new(1, 1, 1), Position = base + Vector3.new(0, -3, 0), Transparency = 1,
			CanQuery = false, CanCollide = false })
		local gl = Instance.new("PointLight")
		gl.Color = (i % 2 == 0) and NEON_C or NEON_M
		gl.Range = 14
		gl.Brightness = 2.5
		gl.Parent = glow
		local ok, gun = pcall(function()
			local ModelKit = require(ReplicatedStorage.Shared.ModelKit)
			local m = ModelKit.Gun(dsp[3], (i % 2 == 0) and NEON_C or NEON_M)
			m:ScaleTo(m:GetScale() * 2.2)
			return m
		end)
		if ok and gun then
			gun.Name = "DisplayGun"
			gun:PivotTo(CFrame.new(base + Vector3.new(0, 4.2, 0)) * CFrame.Angles(0, math.rad(90), 0))
			gun:SetAttribute("Spin", 30)
			gun.Parent = deco
		end
		-- 진열대 위 홀로 이름판
		local board = part({ Name = "HoloSign", Parent = deco, Size = Vector3.new(7, 2, 0.2), Position = base + Vector3.new(0, 8.5, 0), Transparency = 1,
			CanCollide = false, CanQuery = false })
		local bb = Instance.new("BillboardGui")
		bb.Size = UDim2.new(7, 0, 1.6, 0)
		bb.LightInfluence = 0
		bb.MaxDistance = 90
		bb.Parent = board
		local t = Instance.new("TextLabel")
		t.Size = UDim2.fromScale(1, 1)
		t.BackgroundColor3 = Color3.fromRGB(14, 18, 34)
		t.BackgroundTransparency = 0.2
		t.TextScaled = true
		t.TextColor3 = Color3.new(1, 1, 1)
		t.FontFace = Font.new("rbxasset://fonts/families/GothamSSm.json", Enum.FontWeight.Heavy, Enum.FontStyle.Italic)
		local w = require(ReplicatedStorage.Shared.Weapons).Get(dsp[3])
		t.Text = string.upper(w.Class) .. "  ·  " .. w.Name
		t.Parent = bb
		local st = Instance.new("UIStroke")
		st.Color = (i % 2 == 0) and NEON_C or NEON_M
		st.Thickness = 2
		st.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
		st.Parent = t
	end

	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "LobbySpawn"
	spawn.Anchored = true
	spawn.Neutral = true
	spawn.Duration = 0
	spawn.Size = Vector3.new(14, 0.6, 14)
	spawn.Position = Vector3.new(0, Y + 0.3, 44)
	spawn.Color = Color3.fromRGB(240, 240, 255)
	spawn.Material = Enum.Material.Neon
	spawn.Transparency = 0.2
	spawn.TopSurface = Enum.SurfaceType.Smooth
	spawn.Parent = lobby

	------------------------------------------------------------------
	-- 타이틀 로고 (북쪽 벽, 스폰을 바라봄)
	------------------------------------------------------------------
	local TZ = -D / 2 + 3
	local TY = Y + 22
	local board = part({ Name = "TitleBoard", Parent = lobby, Size = Vector3.new(70, 24, 1.5), Position = Vector3.new(0, TY, TZ),
		Color = Color3.fromRGB(22, 18, 38), Material = Enum.Material.SmoothPlastic })
	-- 네온 테두리
	for _, e in ipairs({ { 0, 12.4, 71.6, 0.8 }, { 0, -12.4, 71.6, 0.8 }, { -35.4, 0, 0.8, 25.6 }, { 35.4, 0, 0.8, 25.6 } }) do
		part({ Name = "TitleFrame", Parent = deco, Size = Vector3.new(e[3], e[4], 1.8), Position = Vector3.new(e[1], TY + e[2], TZ),
			Color = (e[2] ~= 0) and Color3.fromRGB(255, 40, 200) or Color3.fromRGB(240, 255, 40), Material = Enum.Material.Neon, CanQuery = false })
	end
	local gui = Instance.new("SurfaceGui")
	gui.Name = "Logo"
	gui.Face = Enum.NormalId.Back
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 30
	gui.LightInfluence = 0
	gui.Parent = board
	titleText(gui, "SPLASH", UDim2.fromScale(0.04, 0.03), UDim2.fromScale(0.92, 0.47), Color3.fromRGB(255, 130, 215), Color3.fromRGB(255, 30, 140))
	titleText(gui, "FRONT", UDim2.fromScale(0.14, 0.47), UDim2.fromScale(0.72, 0.37), Color3.fromRGB(130, 245, 255), Color3.fromRGB(0, 150, 255))
	local sub = Instance.new("TextLabel")
	sub.BackgroundTransparency = 1
	sub.Position = UDim2.fromScale(0.1, 0.85)
	sub.Size = UDim2.fromScale(0.8, 0.12)
	sub.Font = Enum.Font.GothamBlack
	sub.TextScaled = true
	sub.Text = "PAINT  ·  SHOOT  ·  CONQUER"
	sub.TextColor3 = Color3.fromRGB(255, 220, 90)
	sub.Parent = gui
	-- 로고 아래로 흘러내리는 페인트
	for i = 1, 14 do
		local x = -31 + (i - 1) * (62 / 13) + rng:NextNumber(-1, 1)
		local len = rng:NextNumber(1.5, 6)
		local c = LOBBY_COLORS[(i % #LOBBY_COLORS) + 1]
		local w = rng:NextNumber(0.8, 1.6)
		part({ Name = "Drip", Parent = deco, Size = Vector3.new(w, len, 0.5), Position = Vector3.new(x, TY - 12.8 - len / 2, TZ + 0.9),
			Color = c, Material = Enum.Material.Neon, CanCollide = false, CanQuery = false })
		part({ Name = "DripTip", Parent = deco, Shape = Enum.PartType.Ball, Size = Vector3.new(w * 1.3, w * 1.3, w * 1.3),
			Position = Vector3.new(x, TY - 12.8 - len, TZ + 0.9), Color = c, Material = Enum.Material.Neon, CanCollide = false, CanQuery = false })
	end
	-- 양옆 스피커 타워 + 무대 조명
	for _, s in ipairs({ -1, 1 }) do
		local tx = s * 46
		part({ Name = "Speaker", Parent = deco, Size = Vector3.new(8, 20, 6), Position = Vector3.new(tx, Y + 10, TZ + 2),
			Color = Color3.fromRGB(26, 24, 36), Material = Enum.Material.Metal })
		for k, yy in ipairs({ 5, 11, 16.5 }) do
			local d = (k == 3) and 3 or 5.4
			part({ Name = "Woofer", Parent = deco, Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.4, d, d),
				CFrame = CFrame.new(tx, Y + yy, TZ + 5.1) * CFrame.Angles(0, math.rad(90), 0),
				Color = LOBBY_COLORS[s == -1 and 1 or 2], Material = Enum.Material.Neon, CanQuery = false })
		end
		local lamp = part({ Name = "StageLight", Parent = deco, Size = Vector3.new(2, 2, 2), Position = Vector3.new(tx, Y + 21, TZ + 10),
			Color = Color3.fromRGB(255, 250, 235), Material = Enum.Material.Neon, CanQuery = false })
		lamp.CFrame = CFrame.lookAt(lamp.Position, Vector3.new(0, TY, TZ))
		local sp = Instance.new("SpotLight")
		sp.Face = Enum.NormalId.Front
		sp.Range = 50
		sp.Angle = 60
		sp.Brightness = 3
		sp.Parent = lamp
	end

	------------------------------------------------------------------
	-- 매치 대기 발판 무대 (부채꼴 배치)
	------------------------------------------------------------------
	part({ Name = "Stage", Parent = lobby, Size = Vector3.new(146, 0.6, 30), Position = Vector3.new(0, Y + 0.3, -28),
		Color = Color3.fromRGB(28, 26, 42), Material = Enum.Material.DiamondPlate })
	part({ Name = "StageEdge", Parent = deco, Size = Vector3.new(146, 0.25, 0.6), Position = Vector3.new(0, Y + 0.65, -13),
		Color = LOBBY_COLORS[3], Material = Enum.Material.Neon, CanQuery = false })
	-- 팀전은 A존 / B존 발판 두 개: 같은 존에 선 사람끼리 한 팀으로 시작
	local ZONE_COLORS = { Color3.fromRGB(0, 170, 255), Color3.fromRGB(255, 120, 40) }
	local ZONE_NAMES = { "A", "B" }
	local pads, labels, padList = {}, {}, {}
	local n = #Config.Queues
	local PAD_COLORS = { LOBBY_COLORS[2], LOBBY_COLORS[4], LOBBY_COLORS[1], LOBBY_COLORS[6], LOBBY_COLORS[5] }

	local function makePad(q, side, base, diameter, c)
		cyl({ Name = "PadRim", Parent = deco, Height = 0.5, Diameter = diameter + 1.2, Position = base + Vector3.new(0, 0.25, 0), Color = c,
			Material = Enum.Material.Neon, CanQuery = false }).Transparency = 0.15
		cyl({ Name = "PadBase", Parent = lobby, Height = 0.9, Diameter = diameter + 0.4, Position = base + Vector3.new(0, 0.45, 0),
			Color = Color3.fromRGB(36, 34, 52), Material = Enum.Material.Metal })
		local pad = cyl({ Name = "QueuePad_" .. q.Id .. (side > 0 and ("_" .. ZONE_NAMES[side]) or ""), Parent = lobby, Height = 0.2,
			Diameter = diameter - 1.6, Position = base + Vector3.new(0, 1.0, 0), Color = c, Material = Enum.Material.Neon })
		pad.Transparency = 0.3
		pad:SetAttribute("QueueId", q.Id)
		pad:SetAttribute("Side", side)
		local att = Instance.new("Attachment")
		att.Parent = pad
		local pe = Instance.new("ParticleEmitter")
		pe.Color = ColorSequence.new(c)
		pe.LightEmission = 0.8
		pe.Size = NumberSequence.new(0.3, 0)
		pe.Lifetime = NumberRange.new(1.4, 2.2)
		pe.Speed = NumberRange.new(3, 6)
		pe.Rate = 3
		pe.SpreadAngle = Vector2.new(20, 20)
		pe.EmissionDirection = Enum.NormalId.Right -- 원기둥을 눕혔으므로 Right = 위쪽
		pe.Shape = Enum.ParticleEmitterShape.Disc
		pe.ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume
		pe.Parent = att
		local light = Instance.new("PointLight")
		light.Color = c
		light.Range = 14
		light.Brightness = 2
		light.Parent = pad
		if side > 0 then
			-- 발판 바로 위 작은 존 표시 (A / B + 인원)
			local zb = Instance.new("BillboardGui")
			zb.Name = "ZoneTag"
			zb.Size = UDim2.new(3.4, 0, 1, 0)
			zb.StudsOffset = Vector3.new(0, 2.4, 0)
			zb.MaxDistance = 70
			zb.LightInfluence = 0
			zb.Adornee = pad
			zb.Parent = pad
			local zt = Instance.new("TextLabel")
			zt.Name = "Text"
			zt.Size = UDim2.fromScale(1, 1)
			zt.BackgroundColor3 = c
			zt.BackgroundTransparency = 0.1
			zt.Font = Enum.Font.GothamBlack
			zt.TextScaled = true
			zt.TextColor3 = Color3.new(1, 1, 1)
			zt.Text = "ZONE 0/" .. q.TeamSize
			zt.FontFace = Font.new("rbxasset://fonts/families/GothamSSm.json", Enum.FontWeight.Heavy, Enum.FontStyle.Italic)
			zt.Parent = zb
			local zc = Instance.new("UICorner")
			zc.CornerRadius = UDim.new(0.3, 0)
			zc.Parent = zt
			pad:SetAttribute("ZoneLabel", true)
		end
		table.insert(padList, { Pad = pad, Queue = q.Id, Side = side })
		return pad
	end

	for i, q in ipairs(Config.Queues) do
		local t = (i - (n + 1) / 2)
		local x = t * 28
		local z = -26 - (2 - math.abs(t)) * 2.5
		local c = PAD_COLORS[((i - 1) % #PAD_COLORS) + 1]
		local base = Vector3.new(x, Y + 0.6, z)
		local anchor
		if q.Mode == "Solo" then
			anchor = makePad(q, 0, base, 13, c)
		else
			-- 두 존 사이 칸막이 + 존 발판
			part({ Name = "ZoneDivider", Parent = deco, Size = Vector3.new(0.4, 0.5, 11), Position = base + Vector3.new(0, 0.6, 0),
				Color = c, Material = Enum.Material.Neon, CanQuery = false })
			makePad(q, 1, base + Vector3.new(-6.1, 0, 0), 11.4, ZONE_COLORS[1])
			makePad(q, 2, base + Vector3.new(6.1, 0, 0), 11.4, ZONE_COLORS[2])
			anchor = part({ Name = "QueueBoardAnchor_" .. q.Id, Parent = deco, Size = Vector3.new(1, 1, 1), Position = base + Vector3.new(0, 1, 0),
				Transparency = 1, CanCollide = false, CanQuery = false, CanTouch = false })
		end
		local mode = Config.Modes[q.Mode]
		local title2 = q.Mode == "Solo" and "솔로 8인" or (mode.Name .. "  " .. q.TeamSize .. "vs" .. q.TeamSize)
		-- 안내 화면: 발판 뒤에 세운 얇은 스크린 (떠 있는 글씨판 대신 → 발판·존 표시와 겹치지 않음)
		local screenPos = Vector3.new(x, Y + 5.2, z - 8.6)
		local screen = part({ Name = "QueueScreen", Parent = lobby, Size = Vector3.new(13, 4.4, 0.3), CFrame = CFrame.lookAt(screenPos,
			Vector3.new(x, Y + 5.2, 60)), Color = Color3.fromRGB(10, 14, 28), Material = Enum.Material.Glass })
		for _, e in ipairs({ { 0, 2.3, 13.4, 0.2 }, { 0, -2.3, 13.4, 0.2 } }) do
			part({ Name = "ScreenTrim", Parent = deco, Size = Vector3.new(e[3], e[4], 0.4), CFrame = screen.CFrame * CFrame.new(e[1], e[2], 0), Color = c,
				Material = Enum.Material.Neon, CanQuery = false, CanCollide = false })
		end
		for _, sx in ipairs({ -5.5, 5.5 }) do
			part({ Name = "ScreenLeg", Parent = deco, Size = Vector3.new(0.4, 3.2, 0.4), CFrame = screen.CFrame * CFrame.new(sx, -3.8, 0.1),
				Color = Color3.fromRGB(40, 48, 74), Material = Enum.Material.Metal, CanQuery = false })
		end
		local bb = Instance.new("SurfaceGui")
		bb.Name = "QueueBoard"
		bb.Face = Enum.NormalId.Front
		bb.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
		bb.PixelsPerStud = 40
		bb.LightInfluence = 0
		bb.Parent = screen
		local plate = Instance.new("Frame")
		plate.Size = UDim2.fromScale(1, 1)
		plate.BackgroundColor3 = Color3.fromRGB(10, 14, 30)
		plate.BackgroundTransparency = 0.05
		plate.Parent = bb
		local pg = Instance.new("UIGradient")
		pg.Color = ColorSequence.new(Color3.fromRGB(40, 52, 96), Color3.fromRGB(10, 12, 26))
		pg.Rotation = 90
		pg.Parent = plate
		local tl = Instance.new("TextLabel")
		tl.Name = "Title"
		tl.BackgroundTransparency = 1
		tl.Size = UDim2.new(0.92, 0, 0.56, 0)
		tl.Position = UDim2.new(0.04, 0, 0.06, 0)
		tl.FontFace = Font.new("rbxasset://fonts/families/GothamSSm.json", Enum.FontWeight.Heavy, Enum.FontStyle.Italic)
		tl.TextScaled = true
		tl.TextColor3 = Color3.new(1, 1, 1)
		tl.Text = title2
		tl.Parent = plate
		local sub = Instance.new("TextLabel")
		sub.Name = "Sub"
		sub.BackgroundTransparency = 1
		sub.Size = UDim2.new(0.86, 0, 0.3, 0)
		sub.Position = UDim2.new(0.07, 0, 0.64, 0)
		sub.Font = Enum.Font.GothamBold
		sub.TextScaled = true
		sub.RichText = true
		sub.TextColor3 = Color3.fromRGB(200, 200, 220)
		sub.Text = q.Mode == "Solo" and "발판을 밟아 참가" or "같은 ZONE에 선 사람끼리 한 팀"
		sub.Parent = plate
		pads[q.Id] = anchor
		labels[q.Id] = { Label = sub, Title = title2, Ranked = q.Ranked }
	end

	------------------------------------------------------------------
	-- 랭킹 보드 (서쪽, 클릭하면 TOP 50 창)
	------------------------------------------------------------------
	local bx = -W / 2 + 3
	local lb = part({ Name = "Leaderboard", Parent = lobby, Size = Vector3.new(30, 20, 1), Position = Vector3.new(bx, Y + 12, 10),
		Color = Color3.fromRGB(16, 14, 28) })
	-- 앞면(글씨 면)이 로비 안쪽(+X)을 보게. 90°로 돌리면 글씨가 벽 쪽을 향해 빈 판처럼 보였음
	lb.CFrame = CFrame.new(lb.Position) * CFrame.Angles(0, math.rad(-90), 0)
	for _, e in ipairs({ { 0, 10.3, 31, 0.6 }, { 0, -10.3, 31, 0.6 }, { -15.3, 0, 0.6, 21 }, { 15.3, 0, 0.6, 21 } }) do
		part({ Name = "BoardFrame", Parent = deco, Size = Vector3.new(e[3], e[4], 1.2), CFrame = lb.CFrame * CFrame.new(e[1], e[2], 0),
			Color = LOBBY_COLORS[3], Material = Enum.Material.Neon, CanQuery = false })
	end
	local bgui = Instance.new("SurfaceGui")
	bgui.Name = "BoardGui"
	bgui.Face = Enum.NormalId.Front
	bgui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	bgui.PixelsPerStud = 30
	bgui.LightInfluence = 0
	bgui.Parent = lb
	local list = Instance.new("TextLabel")
	list.Name = "List"
	list.Size = UDim2.new(1, 0, 0.88, 0)
	list.BackgroundTransparency = 1
	list.TextColor3 = Color3.new(1, 1, 1)
	list.Font = Enum.Font.GothamBold
	list.TextSize = 34
	list.TextXAlignment = Enum.TextXAlignment.Left
	list.TextYAlignment = Enum.TextYAlignment.Top
	list.Text = "랭킹 불러오는 중..."
	list.Parent = bgui
	local hint = Instance.new("TextLabel")
	hint.Size = UDim2.new(1, 0, 0.1, 0)
	hint.Position = UDim2.fromScale(0, 0.89)
	hint.BackgroundColor3 = LOBBY_COLORS[3]
	hint.TextColor3 = Color3.fromRGB(30, 20, 0)
	hint.Font = Enum.Font.GothamBlack
	hint.TextScaled = true
	hint.Text = "클릭해서 TOP 50 보기"
	hint.Parent = bgui
	local cd = Instance.new("ClickDetector")
	cd.Name = "OpenBoard"
	cd.MaxActivationDistance = 80
	cd.Parent = lb

	------------------------------------------------------------------
	-- 상점 부스 (동쪽, E로 열기)
	------------------------------------------------------------------
	local sx = W / 2 - 10
	part({ Name = "ShopCounter", Parent = lobby, Size = Vector3.new(6, 3.5, 18), Position = Vector3.new(sx, Y + 1.75, 10),
		Color = Color3.fromRGB(46, 40, 70), Material = Enum.Material.Wood })
	part({ Name = "ShopTop", Parent = deco, Size = Vector3.new(6.4, 0.4, 18.4), Position = Vector3.new(sx, Y + 3.7, 10),
		Color = LOBBY_COLORS[1], Material = Enum.Material.Neon, CanQuery = false })
	for k = 0, 5 do
		part({ Name = "Awning", Parent = deco, Size = Vector3.new(8, 0.4, 3), Position = Vector3.new(sx + 1, Y + 11, 2.5 + k * 3),
			Color = (k % 2 == 0) and LOBBY_COLORS[1] or Color3.fromRGB(250, 250, 255), Material = Enum.Material.SmoothPlastic, CanQuery = false })
	end
	for _, zz in ipairs({ 1, 19 }) do
		part({ Name = "ShopPole", Parent = deco, Size = Vector3.new(0.6, 11, 0.6), Position = Vector3.new(sx + 3.5, Y + 5.5, zz),
			Color = Color3.fromRGB(200, 200, 210), Material = Enum.Material.Metal })
	end
	local sign = part({ Name = "ShopSign", Parent = deco, Size = Vector3.new(1, 3.4, 16), Position = Vector3.new(sx + 3.2, Y + 13.2, 10),
		Color = Color3.fromRGB(20, 18, 32), CanQuery = false })
	label(sign, "SHOP · CRATE", Enum.NormalId.Left).TextColor3 = LOBBY_COLORS[3]
	-- 진열대 위 페인트 통
	for k = 0, 4 do
		cyl({ Name = "Bucket", Parent = deco, Height = 1.6, Diameter = 1.6, Position = Vector3.new(sx - 1, Y + 4.7, 3.5 + k * 3.2),
			Color = LOBBY_COLORS[(k % #LOBBY_COLORS) + 1], Material = Enum.Material.SmoothPlastic, CanQuery = false })
	end
	local promptHost = part({ Name = "ShopPromptHost", Parent = lobby, Size = Vector3.new(1, 1, 1), Position = Vector3.new(sx - 4, Y + 3, 10),
		Transparency = 1, CanCollide = false, CanQuery = false })
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "SF_ShopPrompt"
	prompt.ActionText = "상점 열기"
	prompt.ObjectText = "SPLASH SHOP"
	prompt.KeyboardKeyCode = Enum.KeyCode.E
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = 12
	prompt.RequiresLineOfSight = false
	prompt.Parent = promptHost

	return {
		Folder = lobby,
		Spawn = spawn,
		SpawnCFrame = CFrame.new(0, Y + 4, 44),
		QueuePads = pads, -- 큐별 대표 위치(안내판 기준)
		QueuePadList = padList, -- { Pad, Queue, Side(0=솔로, 1=A존, 2=B존) }
		QueueLabels = labels,
		PadRadius = 5.6,
		Leaderboard = list,
	}
end

------------------------------------------------------------------------
-- 아레나 : 크로마 스퀘어 (기획서 8장 배치도와 동일)
------------------------------------------------------------------------
local HALF_X, HALF_Z = 80 * MS, 56 * MS

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
	-- 0.5: 맵 2배 확장에 맞춘 추가 엄폐물
	{ -40, 10, 4, 4, 3, "crate" },
	{ -40, -10, 4, 4, 3, "crate" },
	{ -16, 28, 4, 4, 3, "crate" },
	{ -16, -28, 4, 4, 3, "crate" },
	{ -60, 14, 4, 4, 3, "crate" },
	{ -60, -14, 4, 4, 3, "crate" },
	{ -30, 46, 4, 4, 3, "crate" },
	{ -30, -46, 4, 4, 3, "crate" },
	{ -46, 32, 4, 4, 3, "crate" },
	{ -46, -32, 4, 4, 3, "crate" },
	{ -20, 14, 6, 2, 5, "wall" },
	{ -20, -14, 6, 2, 5, "wall" },
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

	-- 1) 발아래 도시 (스카이 루프탑처럼 고층 옥상 위에서 내려다보는 네온 도시 + 먼 스카이라인)
	local STREET_Y = -160
	local function building(x, z, w, d, top)
		local h = top - STREET_Y
		local b = part({ Name = "Building", Parent = deco, Size = Vector3.new(w, h, d), Position = Vector3.new(x, STREET_Y + h / 2, z),
			Color = Color3.fromRGB(rng:NextInteger(24, 40), rng:NextInteger(24, 36), rng:NextInteger(38, 58)), Material = Enum.Material.Concrete })
		b.CanQuery = false
		b.CastShadow = false
		local c = neon[rng:NextInteger(1, #neon)]
		-- 창문 띠
		local y = STREET_Y + 8
		while y < top - 4 do
			if rng:NextNumber() < 0.5 then
				part({ Name = "Window", Parent = deco, Size = Vector3.new(w + 0.2, 0.6, d + 0.2), Position = Vector3.new(x, y, z),
					Color = c, Material = Enum.Material.Neon, CanCollide = false, CanQuery = false }).Transparency = 0.4
			end
			y = y + rng:NextInteger(5, 9)
		end
		-- 옥상 네온 간판
		if rng:NextNumber() < 0.35 then
			part({ Name = "RoofSign", Parent = deco, Size = Vector3.new(w * 0.7, 3, 0.6), Position = Vector3.new(x, top + 2, z),
				Color = c, Material = Enum.Material.Neon, CanCollide = false, CanQuery = false })
		end
	end
	-- 우리가 서 있는 빌딩 몸통 (옥상 아래로 길게, 창문 띠)
	local bw, bd = HALF_X * 2 + 60, HALF_Z * 2 + 60
	local shell = part({ Name = "TowerShell", Parent = deco, Size = Vector3.new(bw, -2 - STREET_Y, bd), Position = Vector3.new(0, (STREET_Y - 2) / 2, 0),
		Color = Color3.fromRGB(34, 34, 48), Material = Enum.Material.Concrete, CanQuery = false })
	shell.CastShadow = false
	for y = STREET_Y + 10, -8, 7 do
		part({ Name = "Window", Parent = deco, Size = Vector3.new(bw + 0.3, 0.8, bd + 0.3), Position = Vector3.new(0, y, 0),
			Color = Color3.fromRGB(255, 210, 140), Material = Enum.Material.Neon, CanCollide = false, CanQuery = false }).Transparency = 0.55
	end
	-- 주변 빌딩: 가까운 건 옥상보다 낮게(내려다보임), 먼 건 높게(스카이라인)
	for i = 1, 90 do
		local ang = rng:NextNumber() * math.pi * 2
		local dist = rng:NextNumber(130, 420) * MS
		local far = dist > 260 * MS
		local top = far and rng:NextInteger(20, 120) or rng:NextInteger(-110, -15)
		local w = rng:NextInteger(18, 34) * MS
		building(math.cos(ang) * dist, math.sin(ang) * dist, w, w, top)
	end
	part({ Name = "CityGround", Parent = deco, Size = Vector3.new(1000 * MS, 1, 1000 * MS), Position = Vector3.new(0, STREET_Y - 0.5, 0),
		Color = Color3.fromRGB(24, 24, 32), Material = Enum.Material.Asphalt, CanQuery = false })

	-- 2) 난간 위 투광등 + 옥상 가장자리 설비(실외기·물탱크·안테나 경고등)
	for _, x0 in ipairs({ -70, -40, -10, 20, 50 }) do
		local x = (x0 + 10) * MS
		for _, s in ipairs({ -1, 1 }) do
			local pole = part({ Name = "LampPole", Parent = deco, Size = Vector3.new(0.6, 9, 0.6), Position = Vector3.new(x, 3.2 + 4.5, s * (HALF_Z + 2.4)),
				Color = Color3.fromRGB(40, 40, 50), Material = Enum.Material.Metal, CanQuery = false })
			pole.CanCollide = false
			local head = part({ Name = "Lamp", Parent = deco, Size = Vector3.new(3, 0.6, 1.4), Position = Vector3.new(x, 12.4, s * (HALF_Z + 1.4)),
				Color = Color3.fromRGB(255, 240, 220), Material = Enum.Material.Neon, CanCollide = false, CanQuery = false })
			local light = Instance.new("SpotLight")
			light.Face = Enum.NormalId.Bottom
			light.Range = 40
			light.Angle = 90
			light.Brightness = 2
			light.Color = Color3.fromRGB(255, 235, 215)
			light.Parent = head
		end
	end
	local ledgeX, ledgeZ = HALF_X + 14, HALF_Z + 14
	for _, s in ipairs({ -1, 1 }) do
		for _, t in ipairs({ -1, 1 }) do
			-- 물탱크 (모서리)
			local tank = part({ Name = "WaterTank", Parent = deco, Shape = Enum.PartType.Cylinder, Size = Vector3.new(10, 8, 8),
				CFrame = CFrame.new(s * ledgeX, 9, t * ledgeZ) * CFrame.Angles(0, 0, math.rad(90)), Color = Color3.fromRGB(120, 96, 70),
				Material = Enum.Material.WoodPlanks, CanQuery = false })
			tank.CanCollide = false
			for _, lx in ipairs({ -2.5, 2.5 }) do
				for _, lz in ipairs({ -2.5, 2.5 }) do
					part({ Name = "TankLeg", Parent = deco, Size = Vector3.new(0.5, 4, 0.5), Position = Vector3.new(s * ledgeX + lx, 2, t * ledgeZ + lz),
						Color = Color3.fromRGB(50, 50, 60), Material = Enum.Material.Metal, CanCollide = false, CanQuery = false })
				end
			end
			-- 안테나 + 깜빡이는 빨간 경고등
			local ax, az = s * (ledgeX - 10), t * (ledgeZ + 4)
			part({ Name = "Antenna", Parent = deco, Size = Vector3.new(0.6, 26, 0.6), Position = Vector3.new(ax, 13, az), Color = Color3.fromRGB(180, 180, 190),
				Material = Enum.Material.Metal, CanCollide = false, CanQuery = false })
			local beacon = part({ Name = "Beacon", Parent = deco, Shape = Enum.PartType.Ball, Size = Vector3.new(1.2, 1.2, 1.2), Position = Vector3.new(ax, 26.4, az),
				Color = Color3.fromRGB(255, 40, 40), Material = Enum.Material.Neon, CanCollide = false, CanQuery = false })
			local bl = Instance.new("PointLight")
			bl.Color = Color3.fromRGB(255, 40, 40)
			bl.Range = 10
			bl.Parent = beacon
			task.spawn(function()
				while beacon.Parent do
					beacon.Transparency = (beacon.Transparency == 0) and 0.8 or 0
					bl.Enabled = beacon.Transparency == 0
					task.wait(0.9)
				end
			end)
		end
		-- 실외기 줄 (긴 변 바깥 가장자리)
		for k = -3, 3 do
			local u = part({ Name = "ACUnit", Parent = deco, Size = Vector3.new(5, 3.4, 4), Position = Vector3.new(k * 22 * MS, 1.7, s * (HALF_Z + 8)),
				Color = Color3.fromRGB(196, 198, 206), Material = Enum.Material.Metal, CanCollide = false, CanQuery = false })
			part({ Name = "ACFan", Parent = deco, Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.3, 2.6, 2.6),
				CFrame = u.CFrame * CFrame.new(0, 1.75, 0) * CFrame.Angles(0, 0, math.rad(90)), Color = Color3.fromRGB(60, 62, 72),
				Material = Enum.Material.DiamondPlate, CanCollide = false, CanQuery = false })
		end
	end

	-- 3) 베이스 위 팀 배너 (경기마다 팀 색·이름으로 다시 칠함)
	local banners = {}
	for i, t in ipairs(Config.Teams) do
		local x = (i == 1) and -79 * MS or 79 * MS
		local banner = part({ Name = "TeamBanner", Parent = deco, Size = Vector3.new(1, 8, 26 * MS), Position = Vector3.new(x, 16, 0),
			Color = t.Color, Material = Enum.Material.Neon, CanQuery = false })
		banner.CanCollide = false
		banner.Transparency = 0.1
		local l = label(banner, t.Name, i == 1 and Enum.NormalId.Right or Enum.NormalId.Left)
		l.TextColor3 = Color3.fromRGB(20, 20, 30)
		banners[i] = { Part = banner, Label = l }
	end

	-- 4) 중앙 상공 전광판 (점수·시간 실시간 표시, 양면)
	local screen = part({ Name = "Jumbotron", Parent = deco, Size = Vector3.new(1, 13, 34), Position = Vector3.new(0, 30, 0),
		Color = Color3.fromRGB(10, 10, 16), Material = Enum.Material.SmoothPlastic, CanQuery = false })
	screen.CanCollide = false
	local labels = {}
	for _, face in ipairs({ Enum.NormalId.Left, Enum.NormalId.Right }) do
		local t = label(screen, "SPLASH FRONT", face)
		t.Font = Enum.Font.GothamBlack
		table.insert(labels, t)
	end
	part({ Name = "JumboFrame", Parent = deco, Size = Vector3.new(0.8, 13.6, 34.6), Position = Vector3.new(0, 30, 0),
		Color = Config.Teams[1].Color, Material = Enum.Material.Neon, CanCollide = false, CanQuery = false }).Transparency = 0.6
	return labels, banners
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

	-- 바닥: 고층 빌딩 옥상 (경기장 밖으로 넓은 옥상 가장자리까지)
	part({ Name = "Floor", Parent = geo, Size = Vector3.new(HALF_X * 2 + 60, 2, HALF_Z * 2 + 60), Position = Vector3.new(0, -1, 0),
		Color = Color3.fromRGB(78, 80, 92), Material = Enum.Material.Concrete })
	-- 외곽: 높은 철벽 대신 옥상 난간(낮은 콘크리트 + 노란 손잡이 + 네온 띠) + 보이지 않는 벽(밖으로 못 나감)
	local PARAPET = 3.2
	for _, s in ipairs({ -1, 1 }) do
		part({ Name = "Boundary", Parent = geo, Size = Vector3.new(HALF_X * 2 + 4, PARAPET, 2), Position = Vector3.new(0, PARAPET / 2, s * (HALF_Z + 1)),
			Color = Color3.fromRGB(70, 72, 84), Material = Enum.Material.Concrete })
		part({ Name = "Boundary", Parent = geo, Size = Vector3.new(2, PARAPET, HALF_Z * 2 + 4), Position = Vector3.new(s * (HALF_X + 1), PARAPET / 2, 0),
			Color = Color3.fromRGB(70, 72, 84), Material = Enum.Material.Concrete })
		part({ Name = "RailTop", Parent = geo, Size = Vector3.new(HALF_X * 2 + 4, 0.35, 0.5), Position = Vector3.new(0, PARAPET + 1.1, s * (HALF_Z + 1)),
			Color = Color3.fromRGB(255, 196, 0), Material = Enum.Material.Metal, CanQuery = false })
		part({ Name = "RailTop", Parent = geo, Size = Vector3.new(0.5, 0.35, HALF_Z * 2 + 4), Position = Vector3.new(s * (HALF_X + 1), PARAPET + 1.1, 0),
			Color = Color3.fromRGB(255, 196, 0), Material = Enum.Material.Metal, CanQuery = false })
		for k = -HALF_X, HALF_X, 8 do
			part({ Name = "RailPost", Parent = geo, Size = Vector3.new(0.3, 1.1, 0.3), Position = Vector3.new(k, PARAPET + 0.55, s * (HALF_Z + 1)),
				Color = Color3.fromRGB(255, 196, 0), Material = Enum.Material.Metal, CanQuery = false })
		end
		for k = -HALF_Z, HALF_Z, 8 do
			part({ Name = "RailPost", Parent = geo, Size = Vector3.new(0.3, 1.1, 0.3), Position = Vector3.new(s * (HALF_X + 1), PARAPET + 0.55, k),
				Color = Color3.fromRGB(255, 196, 0), Material = Enum.Material.Metal, CanQuery = false })
		end
		part({ Name = "NeonLine", Parent = geo, Size = Vector3.new(HALF_X * 2 + 4, 0.3, 0.3), Position = Vector3.new(0, PARAPET - 0.4, s * HALF_Z),
			Color = Config.Teams[s == -1 and 1 or 2].Color, Material = Enum.Material.Neon, CanCollide = false, CanQuery = false })
		local inv1 = part({ Name = "InvisibleWall", Parent = geo, Size = Vector3.new(HALF_X * 2 + 4, 40, 2), Position = Vector3.new(0, 20, s * (HALF_Z + 1)),
			Transparency = 1, CanQuery = false })
		inv1.CastShadow = false
		local inv2 = part({ Name = "InvisibleWall", Parent = geo, Size = Vector3.new(2, 40, HALF_Z * 2 + 4), Position = Vector3.new(s * (HALF_X + 1), 20, 0),
			Transparency = 1, CanQuery = false })
		inv2.CastShadow = false
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
		local cx, cz, sx, sz, h, kind = o[1] * MS, o[2] * MS, o[3] * MS, o[4] * MS, o[5], o[6]
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
					c.Transparency = 1 -- 판정용 격자는 숨기고, 화면의 페인트는 클라이언트 PaintVisual이 그림
					c:SetAttribute("Owner", 0)
				end
				z = z + CELL
			end
			x = x + CELL
		end
	end

	for _, pl in ipairs(mirrored(PLATFORMS)) do
		local cx, cz, sx, sz, h = pl[1] * MS, pl[2] * MS, pl[3] * MS, pl[4] * MS, pl[5]
		part({ Name = "Platform", Parent = geo, Size = Vector3.new(sx, h, sz), Position = Vector3.new(cx, h / 2, cz),
			Color = Color3.fromRGB(96, 100, 116), Material = Enum.Material.Concrete })
		block(cx, cz, sx, sz)
		addCells(cx - sx / 2, cx + sx / 2, cz - sz / 2, cz + sz / 2, h)
	end

	-- 경사로
	ramp(geo, -16 * MS, -10 * MS, 0, 8 * MS, 0, 3)
	ramp(geo, 16 * MS, 10 * MS, 0, 8 * MS, 0, 3)
	for _, s in ipairs({ 1, -1 }) do
		ramp(geo, -74 * MS, -60 * MS, 40 * MS * s, 4 * MS, 0, 7)
		ramp(geo, 74 * MS, 60 * MS, 40 * MS * s, 4 * MS, 0, 7)
		-- 타워 앞쪽 흉벽(앉으면 숨는 높이)
		part({ Name = "Parapet", Parent = geo, Size = Vector3.new(1, 2.6, 8 * MS), Position = Vector3.new(-52.5 * MS, 8.3, 40 * MS * s),
			Color = Config.Teams[1].Color, Material = Enum.Material.Glass, })
		part({ Name = "Parapet", Parent = geo, Size = Vector3.new(1, 2.6, 8 * MS), Position = Vector3.new(52.5 * MS, 8.3, 40 * MS * s),
			Color = Config.Teams[2].Color, Material = Enum.Material.Glass })
	end

	block(-13 * MS, 0, 6 * MS, 8 * MS)
	block(13 * MS, 0, 6 * MS, 8 * MS)
	for _, s in ipairs({ 1, -1 }) do
		block(-67 * MS, 40 * MS * s, 14 * MS, 4 * MS)
		block(67 * MS, 40 * MS * s, 14 * MS, 4 * MS)
	end

	local jumbotron, banners = decorate(geo)

	-- 바닥 셀
	addCells(-HALF_X, HALF_X, -HALF_Z, HALF_Z, 0)

	-- 스폰 위치 (베이스 위)
	local spawns = { [1] = {}, [2] = {} }
	for i = 0, 4 do
		local z = (-10 + i * 5) * MS
		table.insert(spawns[1], CFrame.lookAt(Vector3.new(-73 * MS, 4, z), Vector3.new(0, 4, z)))
		table.insert(spawns[2], CFrame.lookAt(Vector3.new(73 * MS, 4, z), Vector3.new(0, 4, z)))
	end
	-- 솔로 모드: 맵 가장자리 8곳
	local solo = {}
	local soloPts = { { -73, 0 }, { 73, 0 }, { 0, 48 }, { 0, -48 }, { -40, 48 }, { 40, -48 }, { 40, 48 }, { -40, -48 } }
	for _, p in ipairs(soloPts) do
		local y = (math.abs(p[1]) > 68) and 4 or 3
		table.insert(solo, CFrame.lookAt(Vector3.new(p[1] * MS, y, p[2] * MS), Vector3.new(0, y, 0)))
	end

	local flags = {
		{ Name = "A", Position = Vector3.new(0, 0, -40 * MS) },
		{ Name = "C", Position = Vector3.new(0, 3, 0) },
		{ Name = "B", Position = Vector3.new(0, 0, 40 * MS) },
	}

	local missionSpots = {}
	for _, m in ipairs({ { 0, 3, 0 }, { -30, 0, 44 }, { 30, 0, -44 }, { -30, 0, -44 }, { 30, 0, 44 }, { 0, 0, 40 }, { 0, 0, -40 },
		{ -40, 0, 0 }, { 40, 0, 0 }, { -50, 0, 22 }, { 50, 0, -22 } }) do
		table.insert(missionSpots, Vector3.new(m[1] * MS, m[2], m[3] * MS))
	end

	addOutlines(geo, true) -- 루프탑처럼 원래의 어두운 콘크리트·금속 색 유지
	return {
		Id = "ChromaSquare",
		Name = "크로마 스퀘어",
		KillY = -40,
		Lighting = "Sunset", -- 스카이 루프탑처럼 노을 + 네온 도시
		NoTextures = true,
		Folder = arena,
		Geometry = geo,
		Cells = cells,
		Spawns = spawns,
		SoloSpawns = solo,
		FlagPoints = flags,
		MissionSpots = missionSpots,
		BaseCenters = { [1] = Vector3.new(-73 * MS, 1, 0), [2] = Vector3.new(73 * MS, 1, 0) },
		Jumbotron = jumbotron,
		TeamBanners = banners,
	}
end

------------------------------------------------------------------------
-- 맵 2: 스카이 루프탑
-- 고층 빌딩 옥상 3동(가운데 + 양 팀 스폰 빌딩) 사이를 경사로·점프패드·집라인으로 잇는 수직 맵.
-- 중앙에는 컨테이너·박스로 가득한 창고(1층 실내전 + 지붕 고지대)와 벽 아래 '저격 구멍'.
-- 빌딩 사이로 떨어지면 탈락(KillY). 좌표는 옥상 기준 상대좌표 → skyPos로 변환
------------------------------------------------------------------------
local SKY_Y = 150                         -- 가운데 옥상 바닥 높이
local SKY_O = Vector3.new(0, 0, 1400)     -- 크로마 스퀘어와 겹치지 않게 떨어진 위치 (맵 2배에 맞춰 더 멀리)

-- 설계 좌표(1배) → 월드 좌표. 가로·세로만 MS배, 높이는 그대로라
-- 점프패드(수평 속도도 MS배)·집라인의 궤적과 난간 사이 여유가 그대로 유지됨
local function skyPos(x, y, z)
	return Vector3.new(SKY_O.X + x * MS, SKY_Y + y, SKY_O.Z + z * MS)
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
	local skyBanners = {}
	local METAL = Color3.fromRGB(118, 108, 92)
	local blocked = {}

	local function block(level, cx, cz, sx, sz)
		table.insert(blocked, { level, (cx - sx / 2) * MS, (cx + sx / 2) * MS, (cz - sz / 2) * MS, (cz + sz / 2) * MS })
	end

	-- 상대좌표 상자: 바닥 y1에서 높이 h (가로·세로 MS배)
	local function box(name, cx, y1, cz, sx, h, sz, color, mat, parent)
		return part({ Name = name, Parent = parent or geo, Size = Vector3.new(sx * MS, h, sz * MS), Position = skyPos(cx, y1 + h / 2, cz),
			Color = color or CONCRETE, Material = mat or Enum.Material.Concrete })
	end

	-- 바닥 셀 깔기 (같은 높이의 장애물 자리는 제외)
	local function cellsOn(x1, x2, z1, z2, y)
		x1, x2, z1, z2 = x1 * MS, x2 * MS, z1 * MS, z2 * MS
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
						Position = Vector3.new(SKY_O.X + x, SKY_Y + y + 0.1, SKY_O.Z + z), Color = Config.NeutralColor, CanCollide = false })
					c.CanTouch = false
					c.CastShadow = false
					c.Transparency = 1 -- 판정용 격자는 숨기고, 화면의 페인트는 클라이언트 PaintVisual이 그림
					c:SetAttribute("Owner", 0)
				end
				z = z + CELL
			end
			x = x + CELL
		end
	end

	-- 경사로 + 난간 (xLow 높이 y0 → xHigh 높이 y0+h)
	local function skyRamp(xLow, xHigh, z, width, y0, h)
		width = width * MS
		local len = math.abs(xHigh - xLow) * MS
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
		launch = Vector3.new(launch.X * MS, launch.Y, launch.Z * MS) -- 비행 시간은 같고 수평 거리만 MS배
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
		block(y, x, z, 6 / MS, 6 / MS)
		return pad
	end

	-- 집라인: 시작 기둥의 E 프롬프트로 탑승, from → to 로 미끄러져 내려감
	-- twoWay: 아래쪽 기둥에서도 타고 위로 올라갈 수 있음 (깃발 탑 오르기용)
	local function zipline(from, to, fromBase, toBase, twoWay)
		local h1, h2 = from.Y - (SKY_Y + fromBase), to.Y - (SKY_Y + toBase)
		local startPole = part({ Name = "ZipStart", Parent = geo, Size = Vector3.new(0.8, h1, 0.8), Position = from - Vector3.new(0, h1 / 2, 0),
			Color = Color3.fromRGB(255, 196, 0), Material = Enum.Material.Metal })
		local endPole = part({ Name = "ZipEnd", Parent = geo, Size = Vector3.new(0.8, h2, 0.8), Position = to - Vector3.new(0, h2 / 2, 0),
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
		if twoWay then
			endPole:SetAttribute("ZipFrom", to)
			endPole:SetAttribute("ZipTo", from)
			CollectionService:AddTag(endPole, "SF_Zipline")
			local up = prompt:Clone()
			up.ActionText = "집라인 타고 오르기"
			up.ObjectText = "깃발 탑 집라인"
			up.Parent = endPole
			-- 아래 기둥 표시등 (멀리서도 탈 곳이 보이게)
			local mark = part({ Name = "ZipMark", Parent = deco, Shape = Enum.PartType.Ball, Size = Vector3.new(1.4, 1.4, 1.4), Position = to + Vector3.new(0, 0.6, 0),
				Color = Color3.fromRGB(0, 255, 220), Material = Enum.Material.Neon, CanCollide = false, CanQuery = false })
			local ml = Instance.new("PointLight")
			ml.Color = mark.Color
			ml.Range = 10
			ml.Parent = mark
		end
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
		part({ Name = "WindowBand", Parent = deco, Size = Vector3.new(100 * MS + 0.4, 0.8, 104 * MS + 0.4), Position = skyPos(0, y, 0), Color = c,
			Material = Enum.Material.Neon, CanCollide = false, CanQuery = false }).Transparency = 0.45
		for _, s in ipairs({ -1, 1 }) do
			part({ Name = "WindowBand", Parent = deco, Size = Vector3.new(20 * MS + 0.4, 0.8, 60 * MS + 0.4), Position = skyPos(76 * s, y + 6, 0),
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
		local bl = label(back, "SKY ROOFTOP", s == -1 and Enum.NormalId.Right or Enum.NormalId.Left)
		bl.TextColor3 = Config.Teams[s == -1 and 1 or 2].Color
		skyBanners[s == -1 and 1 or 2] = { Label = bl }
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
			zipline(skyPos(6 * s, 20, 42 * t), skyPos(44 * s, 7, 16 * t), 12, 0, true) -- 컨테이너 탑(깃발) ↔ 옥상 가장자리 (아래에서 타면 탑으로 올라감)
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
	part({ Name = "Street", Parent = deco, Size = Vector3.new(700 * MS, 1, 700 * MS), Position = Vector3.new(SKY_O.X, -0.5, SKY_O.Z),
		Color = Color3.fromRGB(24, 24, 32), Material = Enum.Material.Asphalt, CanQuery = false })
	for i = 1, 70 do
		local a = rng:NextNumber() * math.pi * 2
		local dist = rng:NextNumber(115, 300) * MS
		local far = dist > 220 * MS
		local h = far and rng:NextInteger(160, 240) or rng:NextInteger(50, 135)
		local w = rng:NextInteger(16, 30) * (MS > 1 and 1.5 or 1)
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

	-- 스카이 루프탑은 처음의 어두운 네온 도시 + 노을 분위기 그대로 (흰색 팔레트·표면 텍스처 적용 안 함)
	addOutlines(geo, true)
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
		Lighting = "Sunset",
		NoTextures = true,
		Jumbotron = jumbotron,
		TeamBanners = skyBanners,
	}
end

return MapBuilder
