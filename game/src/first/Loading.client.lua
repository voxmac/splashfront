-- 접속 연출 (ReplicatedFirst): 기본 로딩 화면 대신 SF 로딩 화면을 띄우고, 캐릭터가 로비에 생기면
-- 격납고 유리 천장 위에서 카메라가 떨어지듯 내려와 캐릭터 뒤에 붙으며 화면이 열림 (하늘·빈 공간이 보이지 않게)
local Players = game:GetService("Players")
local ReplicatedFirst = game:GetService("ReplicatedFirst")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")

local player = Players.LocalPlayer
pcall(function()
	ReplicatedFirst:RemoveDefaultLoadingScreen()
end)
-- Roblox 기본 체력 바(오른쪽 위)는 숨김 (게임 HUD에 자체 체력 바가 있음)
pcall(function()
	game:GetService("StarterGui"):SetCoreGuiEnabled(Enum.CoreGuiType.Health, false)
end)

local HEAVY = Font.new("rbxasset://fonts/families/GothamSSm.json", Enum.FontWeight.Heavy, Enum.FontStyle.Italic)

------------------------------------------------------------------------
-- 서버 이동(로비 ↔ 배틀) 전환 화면: 프로필 로딩 화면 대신 짧은 전환 화면만 보여 주고 뒤에서 처리
------------------------------------------------------------------------
local TeleportService = game:GetService("TeleportService")
local SoundService = game:GetService("SoundService")
local MUSIC_BATTLE = "rbxassetid://125224859846133" -- 크로마 테마 (배틀로 갈 때)
local MUSIC_LOBBY = "rbxassetid://137125830506009" -- 로비 테마 (로비로 갈 때)

-- 전환 화면: 로고 + 단계 문구 + 진행 막대(채움 + 흐르는 빛) · p = 0~1
local function makeTransition(msg, p)
	local g = Instance.new("ScreenGui")
	g.Name = "SF_Transition"
	g.IgnoreGuiInset = true
	g.DisplayOrder = 1001
	g.ResetOnSpawn = false
	local f = Instance.new("Frame")
	f.Name = "Bg"
	f.Size = UDim2.fromScale(1, 1)
	f.BackgroundColor3 = Color3.new(1, 1, 1)
	f.BorderSizePixel = 0
	f.Parent = g
	local gr = Instance.new("UIGradient")
	gr.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(26, 34, 70)),
		ColorSequenceKeypoint.new(0.6, Color3.fromRGB(10, 13, 28)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(4, 5, 12)),
	})
	gr.Rotation = 90
	gr.Parent = f
	for k = 0, 5 do
		local st = Instance.new("Frame")
		st.Name = "Stripe"
		st.AnchorPoint = Vector2.new(0.5, 0.5)
		st.Size = UDim2.new(0, 10, 1.6, 0)
		st.Position = UDim2.new(0.08 + k * 0.17, 0, 0.5, 0)
		st.Rotation = 24
		st.BorderSizePixel = 0
		st.BackgroundColor3 = (k % 2 == 0) and Color3.fromRGB(255, 40, 200) or Color3.fromRGB(240, 255, 40)
		st.BackgroundTransparency = 0.88
		st.Parent = f
	end
	local logo = Instance.new("ImageLabel")
	logo.Name = "Logo"
	logo.AnchorPoint = Vector2.new(0.5, 0.5)
	logo.Position = UDim2.fromScale(0.5, 0.42)
	logo.Size = UDim2.fromScale(0.34, 0.2)
	logo.BackgroundTransparency = 1
	logo.ScaleType = Enum.ScaleType.Fit
	logo.Image = "rbxassetid://132379224854027"
	logo.Parent = f
	local t = Instance.new("TextLabel")
	t.Name = "Msg"
	t.AnchorPoint = Vector2.new(0.5, 0.5)
	t.Position = UDim2.fromScale(0.5, 0.6)
	t.Size = UDim2.fromScale(0.5, 0.038)
	t.BackgroundTransparency = 1
	t.TextScaled = true
	t.FontFace = HEAVY
	t.TextColor3 = Color3.fromRGB(240, 255, 40)
	t.Text = msg
	t.Parent = f
	local track = Instance.new("Frame")
	track.Name = "Track"
	track.AnchorPoint = Vector2.new(0.5, 0.5)
	track.Position = UDim2.fromScale(0.5, 0.66)
	track.Size = UDim2.new(0.34, 0, 0, 8)
	track.BackgroundColor3 = Color3.fromRGB(30, 38, 70)
	track.BorderSizePixel = 0
	track.ClipsDescendants = true
	track.Parent = f
	local c1 = Instance.new("UICorner")
	c1.CornerRadius = UDim.new(1, 0)
	c1.Parent = track
	local fill = Instance.new("Frame")
	fill.Name = "Fill"
	fill.Size = UDim2.fromScale(p or 0, 1)
	fill.BackgroundColor3 = Color3.new(1, 1, 1)
	fill.BorderSizePixel = 0
	fill.Parent = track
	local fg = Instance.new("UIGradient")
	fg.Color = ColorSequence.new(Color3.fromRGB(255, 60, 200), Color3.fromRGB(60, 220, 255))
	fg.Parent = fill
	local c2 = Instance.new("UICorner")
	c2.CornerRadius = UDim.new(1, 0)
	c2.Parent = fill
	local shine = Instance.new("Frame")
	shine.Name = "Shine"
	shine.Size = UDim2.new(0, 60, 1, 0)
	shine.Position = UDim2.new(-0.3, 0, 0, 0)
	shine.BackgroundColor3 = Color3.new(1, 1, 1)
	shine.BackgroundTransparency = 0.55
	shine.BorderSizePixel = 0
	shine.Parent = fill
	local pct = Instance.new("TextLabel")
	pct.Name = "Pct"
	pct.AnchorPoint = Vector2.new(0.5, 0.5)
	pct.Position = UDim2.fromScale(0.5, 0.7)
	pct.Size = UDim2.fromScale(0.2, 0.026)
	pct.BackgroundTransparency = 1
	pct.TextScaled = true
	pct.FontFace = Font.new("rbxasset://fonts/families/GothamSSm.json", Enum.FontWeight.Bold)
	pct.TextColor3 = Color3.fromRGB(170, 180, 220)
	pct.Text = math.floor((p or 0) * 100) .. "%"
	pct.Parent = f
	return g
end

-- 전환 화면 움직임: 진행 막대가 목표를 향해 부드럽게 차오르고(기다리는 동안 천천히), 빛이 흐르고, 줄무늬가 흐름
local function animate(g, state)
	local f = g:FindFirstChild("Bg")
	local fill = f and f.Track.Fill
	local t0 = os.clock()
	local conn
	conn = RunService.RenderStepped:Connect(function(dt)
		if not g.Parent then
			conn:Disconnect()
			return
		end
		-- 목표에 가까워질수록 느려짐 → 멈춘 느낌 없이 계속 진행 중
		state.p = state.p + (state.target - state.p) * math.min(1, dt * (state.target >= 1 and 6 or 1.2))
		state.target = math.min(state.cap or 0.95, state.target + dt * 0.02)
		fill.Size = UDim2.fromScale(state.p, 1)
		f.Pct.Text = math.floor(state.p * 100 + 0.5) .. "%"
		local k = ((os.clock() - t0) % 1.1) / 1.1
		fill.Shine.Position = UDim2.new(k * 1.4 - 0.3, 0, 0, 0)
		f.Msg.Text = state.msg .. string.rep(".", math.floor((os.clock() - t0) * 2.5) % 4)
		for _, st in ipairs(f:GetChildren()) do
			if st.Name == "Stripe" then
				local x = st.Position.X.Scale + dt * 0.04
				st.Position = UDim2.new(x > 1.05 and -0.05 or x, 0, 0.5, 0)
			end
		end
		f.Logo.Size = UDim2.fromScale(0.34 + math.sin((os.clock() - t0) * 2.2) * 0.008, 0.2)
	end)
end

-- 음악: 부드럽게 켜고 끄기
local function startMusic(id)
	local snd = Instance.new("Sound")
	snd.Name = "SF_TransitionMusic"
	snd.SoundId = id
	snd.Looped = true
	snd.Volume = 0
	snd.Parent = SoundService
	snd:Play()
	TweenService:Create(snd, TweenInfo.new(1.2), { Volume = 0.45 }):Play()
	return snd
end
local function stopMusic(snd)
	if snd then
		TweenService:Create(snd, TweenInfo.new(1.0), { Volume = 0 }):Play()
		task.delay(1.1, function()
			snd:Destroy()
		end)
	end
end

local function fadeOut(g)
	local f = g and g:FindFirstChild("Bg")
	if f then
		TweenService:Create(f, TweenInfo.new(0.45), { BackgroundTransparency = 1 }):Play()
		for _, d in ipairs(f:GetDescendants()) do
			if d:IsA("TextLabel") then
				TweenService:Create(d, TweenInfo.new(0.35), { TextTransparency = 1 }):Play()
			elseif d:IsA("ImageLabel") then
				TweenService:Create(d, TweenInfo.new(0.35), { ImageTransparency = 1 }):Play()
			elseif d:IsA("Frame") then
				TweenService:Create(d, TweenInfo.new(0.35), { BackgroundTransparency = 1 }):Play()
			end
		end
	end
	task.delay(0.55, function()
		if g then
			g:Destroy()
		end
	end)
end

-- 떠날 때: 서버가 Teleporting을 켜면 전환 화면 + 음악, 막대는 0 → 55%까지 (나머지는 도착한 서버에서 이어서)
local leaving, leavingState, leavingMusic = nil, nil, nil
player:GetAttributeChangedSignal("Teleporting"):Connect(function()
	if player:GetAttribute("Teleporting") then
		if leaving then
			return
		end
		local toLobby = player:GetAttribute("InMatch") or game.PrivateServerId ~= ""
		local msg = toLobby and "로비로 돌아가는 중" or "배틀 서버로 이동 중"
		leaving = makeTransition(msg, 0)
		leavingState = { p = 0, target = 0.35, cap = 0.55, msg = msg }
		leaving.Parent = player:WaitForChild("PlayerGui")
		SoundService:SetAttribute("SF_Transition", true) -- 배경음악·효과음 끄고 전환 음악만
		animate(leaving, leavingState)
		leavingMusic = startMusic(toLobby and MUSIC_LOBBY or MUSIC_BATTLE)
		-- 이동 화면(정지 화면)은 출발 직전의 진행 상태로 등록
		task.spawn(function()
			for _ = 1, 8 do
				if not leaving then
					return
				end
				pcall(function()
					TeleportService:SetTeleportGui(makeTransition(msg, leavingState.p))
				end)
				task.wait(0.5)
			end
		end)
	elseif leaving then
		-- 이동이 취소·실패하면 다시 화면을 엶
		fadeOut(leaving)
		stopMusic(leavingMusic)
		SoundService:SetAttribute("SF_Transition", nil)
		leaving, leavingState, leavingMusic = nil, nil, nil
	end
end)

-- 도착했을 때: 다른 서버에서 넘어왔으면 큰 로딩·낙하 연출 없이 준비되는 대로 바로 화면을 엶
local arrivedSF = nil
pcall(function()
	local td = TeleportService:GetLocalPlayerTeleportData()
	if type(td) == "table" and type(td.SF) == "table" then
		arrivedSF = td.SF
	end
end)
if arrivedSF then
	local toBattle = arrivedSF.Kind == "Match" or arrivedSF.Kind == "Join"
	local old = nil
	pcall(function()
		old = TeleportService:GetArrivingTeleportGui()
	end)
	local p0 = 0.55
	pcall(function()
		local of = old and old:FindFirstChild("Bg")
		p0 = math.max(p0, of.Track.Fill.Size.X.Scale)
	end)
	local stages = toBattle and { "배틀 서버에 연결하는 중", "전장을 준비하는 중", "출격 준비 완료" }
		or { "로비에 연결하는 중", "프로필 동기화 중", "격납고 도착" }
	local g = makeTransition(stages[1], p0)
	g.Parent = player:WaitForChild("PlayerGui")
	if old then
		old:Destroy()
	end
	SoundService:SetAttribute("SF_Transition", true)
	local state = { p = p0, target = p0 + 0.1, cap = 0.8, msg = stages[1] }
	animate(g, state)
	local music = startMusic(toBattle and MUSIC_BATTLE or MUSIC_LOBBY)
	if not game:IsLoaded() then
		game.Loaded:Wait()
	end
	local t0 = os.clock()
	while os.clock() - t0 < 40 do
		local c = player.Character
		local root = c and c:FindFirstChild("HumanoidRootPart")
		local loaded = root ~= nil and player:GetAttribute("Coins") ~= nil
		if loaded and state.msg == stages[1] then
			state.msg = stages[2]
			state.cap = 0.92
			state.target = math.max(state.target, 0.8)
		end
		local ready
		if toBattle then
			-- 배틀: 경기에 들어가 캐릭터가 전장에 설 때까지 (로비 대기 화면은 보이지 않게)
			ready = loaded and player:GetAttribute("InMatch") and root.Position.Y < 300
		else
			ready = loaded and player:GetAttribute("LobbyReady")
		end
		if ready then
			break
		end
		task.wait(0.1)
	end
	state.msg = stages[3]
	state.cap = 1
	state.target = 1
	task.wait(0.5)
	stopMusic(music)
	fadeOut(g)
	-- 전환 음악이 다 줄어든 뒤 게임 음악을 서서히 켬 (겹치지 않게)
	task.delay(1.0, function()
		SoundService:SetAttribute("SF_Transition", nil)
	end)
	return
end


local gui = Instance.new("ScreenGui")
gui.Name = "SF_Loading"
gui.IgnoreGuiInset = true
gui.DisplayOrder = 1000
gui.ResetOnSpawn = false
gui.Parent = player:WaitForChild("PlayerGui")

local bg = Instance.new("Frame")
bg.Size = UDim2.fromScale(1, 1)
bg.BackgroundColor3 = Color3.new(1, 1, 1)
bg.BorderSizePixel = 0
bg.Parent = gui
local grad = Instance.new("UIGradient")
grad.Color = ColorSequence.new({
	ColorSequenceKeypoint.new(0, Color3.fromRGB(26, 34, 70)),
	ColorSequenceKeypoint.new(0.6, Color3.fromRGB(10, 13, 28)),
	ColorSequenceKeypoint.new(1, Color3.fromRGB(4, 5, 12)),
})
grad.Rotation = 90
grad.Parent = bg

-- 네온 사선 줄
local stripes = {}
for i = 0, 5 do
	local s = Instance.new("Frame")
	s.AnchorPoint = Vector2.new(0.5, 0.5)
	s.Size = UDim2.new(0, 10, 1.6, 0)
	s.Position = UDim2.new(0.08 + i * 0.17, 0, 0.5, 0)
	s.Rotation = 24
	s.BorderSizePixel = 0
	s.BackgroundColor3 = (i % 2 == 0) and Color3.fromRGB(255, 40, 200) or Color3.fromRGB(240, 255, 40)
	s.BackgroundTransparency = 0.86
	s.Parent = bg
	table.insert(stripes, s)
end

local function text(props)
	local t = Instance.new("TextLabel")
	t.BackgroundTransparency = 1
	t.TextColor3 = Color3.new(1, 1, 1)
	t.FontFace = HEAVY
	t.TextScaled = true
	for k, v in pairs(props) do
		t[k] = v
	end
	t.Parent = bg
	return t
end
local t1 = text({ Text = "SPLASH", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.38), Size = UDim2.fromScale(0.6, 0.16),
	TextColor3 = Color3.fromRGB(255, 70, 200) })
local t2 = text({ Text = "FRONT", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.52), Size = UDim2.fromScale(0.42, 0.12),
	TextColor3 = Color3.fromRGB(60, 220, 255) })
for _, t in ipairs({ t1, t2 }) do
	local st = Instance.new("UIStroke")
	st.Thickness = 4
	st.Color = Color3.fromRGB(10, 10, 24)
	st.Parent = t
end
-- 업로드한 로고 이미지가 준비되면 글자 로고 대신 표시 (서버 ImageService가 ReplicatedStorage.Images에 주소를 올림)
local logoImg = Instance.new("ImageLabel")
logoImg.AnchorPoint = Vector2.new(0.5, 0.5)
logoImg.Position = UDim2.fromScale(0.5, 0.44)
logoImg.Size = UDim2.fromScale(0.62, 0.36)
logoImg.BackgroundTransparency = 1
logoImg.ScaleType = Enum.ScaleType.Fit
-- 로고 이미지 ID를 바로 써서 접속 직후부터 이미지 로고 표시 (Images 속성이 오면 그 주소로 갱신)
logoImg.Image = "rbxassetid://132379224854027"
logoImg.Visible = true
logoImg.Parent = bg
t1.Visible = false
t2.Visible = false
task.spawn(function()
	local RS = game:GetService("ReplicatedStorage")
	local imgs = RS:WaitForChild("Images", 15)
	if not imgs then
		return
	end
	local function use()
		local url = imgs:GetAttribute("icon_logo")
		if url then
			logoImg.Image = url
			logoImg.Visible = true
			t1.Visible = false
			t2.Visible = false
		end
	end
	use()
	imgs:GetAttributeChangedSignal("icon_logo"):Connect(use)
end)
local status = text({ Text = "격납고에 연결하는 중", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.7), Size = UDim2.fromScale(0.5, 0.04),
	TextColor3 = Color3.fromRGB(200, 210, 240) })
local tips = {
	"바닥을 더 많이 칠한 팀이 승리해요",
	"같은 ZONE 발판에 선 친구끼리 한 팀",
	"Shift 달리기 · C 앉기 · V 1·3인칭",
	"일일·주간 미션을 깨고 코인으로 스킨을 사세요",
}
local tip = text({ Text = tips[math.random(1, #tips)], AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.9), Size = UDim2.fromScale(0.6, 0.032),
	TextColor3 = Color3.fromRGB(150, 160, 200), FontFace = Font.new("rbxasset://fonts/families/GothamSSm.json", Enum.FontWeight.Bold) })

-- 진행 막대 (끝없이 흐르는 네온)
local barBg = Instance.new("Frame")
barBg.AnchorPoint = Vector2.new(0.5, 0.5)
barBg.Position = UDim2.fromScale(0.5, 0.76)
barBg.Size = UDim2.new(0.32, 0, 0, 6)
barBg.BackgroundColor3 = Color3.fromRGB(30, 38, 70)
barBg.BorderSizePixel = 0
barBg.ClipsDescendants = true
barBg.Parent = bg
local bar = Instance.new("Frame")
bar.Size = UDim2.fromScale(0.3, 1)
bar.BackgroundColor3 = Color3.fromRGB(240, 255, 40)
bar.BorderSizePixel = 0
bar.Parent = barBg

local done = false
task.spawn(function()
	local dots = 0
	while not done do
		local tw = TweenService:Create(bar, TweenInfo.new(0.9, Enum.EasingStyle.Sine), { Position = UDim2.fromScale(1, 0) })
		bar.Position = UDim2.fromScale(-0.3, 0)
		tw:Play()
		dots = dots % 3 + 1
		if status.Text:find("연결") or status.Text:find("불러") then
			status.Text = status.Text:gsub("%.+$", "") .. string.rep(".", dots)
		end
		task.wait(0.9)
	end
end)

-- 1) 게임 데이터 로드
if not game:IsLoaded() then
	game.Loaded:Wait()
end
status.Text = "프로필 불러오는 중"

-- 2) 로비에 캐릭터가 생길 때까지
local function lobbyCharacter()
	local c = player.Character
	local root = c and c:FindFirstChild("HumanoidRootPart")
	-- 캐릭터가 로비에 있고, 프로필(코인)과 로비 UI까지 준비됐을 때 화면을 엶
	local pg = player:FindFirstChild("PlayerGui")
	-- LobbyReady: 서버가 로비 캐릭터를 만든 뒤 켬 (그 전의 임시 캐릭터로 연출을 시작하지 않게)
	if root and root.Position.Y > 300 and player:GetAttribute("Coins") ~= nil and player:GetAttribute("LobbyReady") and pg and pg:FindFirstChild("SplashLobby") then
		return c, root
	end
	return nil
end
local char, root = lobbyCharacter()
local t0 = os.clock()
while not char and os.clock() - t0 < 60 do
	task.wait(0.1)
	char, root = lobbyCharacter()
end
task.wait(0.4) -- 로비 조명·UI가 자리 잡을 시간
status.Text = "출격!"

-- 3) 낙하 연출: 유리 천장 위 → 캐릭터 뒤 (1.9초), 화면은 밝게 열림
local cam = workspace.CurrentCamera
if char and root and cam then
	local target = root.CFrame
	-- 도착 지점: 캐릭터 바로 뒤 위 (발판 쪽을 바라봄)
	local endCf = CFrame.lookAt(target.Position - target.LookVector * 12 + Vector3.new(0, 5, 0), target.Position + target.LookVector * 6 + Vector3.new(0, 1.5, 0))
	local startPos = target.Position + Vector3.new(0, 95, 18)
	local startCf = CFrame.lookAt(startPos, target.Position)
	cam:SetAttribute("SF_Intro", true) -- 연출 중에는 카메라 감시(Client)가 건드리지 않음
	cam.CameraType = Enum.CameraType.Scriptable
	cam.CFrame = startCf
	local fov0 = cam.FieldOfView
	cam.FieldOfView = 95
	local fade = TweenService:Create(bg, TweenInfo.new(0.5), { BackgroundTransparency = 1 })
	fade:Play()
	for _, d in ipairs(bg:GetDescendants()) do
		if d:IsA("TextLabel") then
			TweenService:Create(d, TweenInfo.new(0.35), { TextTransparency = 1 }):Play()
			local st = d:FindFirstChildOfClass("UIStroke")
			if st then
				TweenService:Create(st, TweenInfo.new(0.35), { Transparency = 1 }):Play()
			end
		elseif d:IsA("ImageLabel") then
			TweenService:Create(d, TweenInfo.new(0.35), { ImageTransparency = 1 }):Play()
		elseif d:IsA("Frame") then
			TweenService:Create(d, TweenInfo.new(0.35), { BackgroundTransparency = 1 }):Play()
		end
	end
	local dur = 1.9
	local start = os.clock()
	while true do
		local a = math.clamp((os.clock() - start) / dur, 0, 1)
		local e = 1 - (1 - a) ^ 3 -- 처음 빠르게 떨어지고 끝에서 부드럽게 멈춤
		cam.CFrame = startCf:Lerp(endCf, e)
		cam.FieldOfView = fov0 + (95 - fov0) * (1 - e)
		-- 연출 도중 캐릭터가 다시 생성되면(재스폰) 바로 끝내고 새 캐릭터를 따라가게
		if a >= 1 or player.Character ~= char or not char.Parent then
			break
		end
		RunService.RenderStepped:Wait()
	end
	cam.FieldOfView = fov0
	-- 연출 시작 때의 캐릭터가 아니라 '지금' 캐릭터를 따라가게 (원인: 연출 중 재스폰되면 사라진 캐릭터를 붙잡고 멈춰 있었음)
	local nowChar = player.Character
	local hum = nowChar and nowChar:FindFirstChildOfClass("Humanoid")
	if hum then
		cam.CameraSubject = hum
	end
	cam.CameraType = Enum.CameraType.Custom
	cam:SetAttribute("SF_Intro", nil)
	if nowChar ~= char then
		-- 연출 중 캐릭터가 바뀌었으면 새 캐릭터 뒤쪽에서 이어받음 (위에서 내려다보는 각도로 남지 않게)
		local nr = nowChar and nowChar:FindFirstChild("HumanoidRootPart")
		if nr then
			endCf = CFrame.lookAt(nr.Position - nr.CFrame.LookVector * 12 + Vector3.new(0, 5, 0), nr.Position + nr.CFrame.LookVector * 6 + Vector3.new(0, 1.5, 0))
		else
			endCf = cam.CFrame
		end
	end
	-- 기본 카메라가 이 방향을 이어받도록 잠깐 같은 자리에 붙잡아 둠 (기본 카메라는 현재 카메라 방향을 기준으로 회전함)
	local hold = os.clock()
	RunService:BindToRenderStep("SF_IntroHold", Enum.RenderPriority.Camera.Value + 1, function()
		cam.CFrame = endCf
		if os.clock() - hold > 0.25 then
			RunService:UnbindFromRenderStep("SF_IntroHold")
		end
	end)
else
	TweenService:Create(bg, TweenInfo.new(0.4), { BackgroundTransparency = 1 }):Play()
end
done = true
task.wait(0.5)
gui:Destroy()
